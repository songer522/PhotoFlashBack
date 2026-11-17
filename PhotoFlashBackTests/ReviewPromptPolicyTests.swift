import XCTest
@testable import PhotoFlashBack

final class ReviewPromptPolicyTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private lazy var policy = ReviewPromptPolicy(requiredViewerOpens: 10, requiredEngagedDays: 2, calendar: calendar)
    private let idle = ReviewPromptContext(appVersion: "3.2")

    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func opening(_ count: Int, on day: Int, from state: ReviewPromptState = ReviewPromptState()) -> ReviewPromptState {
        (0..<count).reduce(state) { state, index in
            policy.recordingViewerOpen(state, at: date(day: day, hour: 8 + index % 12))
        }
    }

    /// Ten opens spread over two days: the minimum engagement that should allow the prompt.
    private func engagedState() -> ReviewPromptState {
        opening(5, on: 2, from: opening(5, on: 1))
    }

    // MARK: - Recording opens

    func testFirstOpenStartsCountsAtOne() {
        let state = policy.recordingViewerOpen(ReviewPromptState(), at: date(day: 1))
        XCTAssertEqual(state.viewerOpenCount, 1)
        XCTAssertEqual(state.engagedDayCount, 1)
        XCTAssertEqual(state.lastEngagedDay, calendar.startOfDay(for: date(day: 1)))
    }

    func testOpensOnTheSameDayCountAsOneEngagedDay() {
        let state = opening(4, on: 1)
        XCTAssertEqual(state.viewerOpenCount, 4)
        XCTAssertEqual(state.engagedDayCount, 1)
    }

    func testOpensOnDifferentDaysCountEachDay() {
        let state = opening(1, on: 3, from: opening(1, on: 2, from: opening(1, on: 1)))
        XCTAssertEqual(state.viewerOpenCount, 3)
        XCTAssertEqual(state.engagedDayCount, 3)
    }

    // MARK: - Thresholds

    func testPromptsAfterTenOpensAcrossTwoDays() {
        XCTAssertTrue(policy.shouldRequestReview(engagedState(), context: idle))
    }

    func testDoesNotPromptBeforeTenOpens() {
        let state = opening(4, on: 2, from: opening(5, on: 1))
        XCTAssertEqual(state.viewerOpenCount, 9)
        XCTAssertFalse(policy.shouldRequestReview(state, context: idle))
    }

    func testDoesNotPromptWhenAllOpensWereOnOneDay() {
        let state = opening(25, on: 1)
        XCTAssertFalse(policy.shouldRequestReview(state, context: idle))
    }

    func testDoesNotPromptWithoutAnAppVersion() {
        XCTAssertFalse(policy.shouldRequestReview(engagedState(), context: ReviewPromptContext(appVersion: "")))
    }

    // MARK: - Once per version

    func testDoesNotPromptAgainForTheSameVersion() {
        let prompted = policy.recordingPrompt(engagedState(), appVersion: "3.2")
        XCTAssertEqual(prompted.lastPromptedVersion, "3.2")

        let moreUse = opening(10, on: 5, from: opening(10, on: 4, from: prompted))
        XCTAssertFalse(policy.shouldRequestReview(moreUse, context: idle))
    }

    func testPromptResetsEngagementSoTheNextVersionNeedsFreshUse() {
        let prompted = policy.recordingPrompt(engagedState(), appVersion: "3.2")
        XCTAssertEqual(prompted.viewerOpenCount, 0)
        XCTAssertEqual(prompted.engagedDayCount, 0)
        XCTAssertNil(prompted.lastEngagedDay)

        let nextVersion = ReviewPromptContext(appVersion: "3.3")
        XCTAssertFalse(policy.shouldRequestReview(prompted, context: nextVersion))
        XCTAssertFalse(policy.shouldRequestReview(opening(10, on: 4, from: prompted), context: nextVersion))

        let reEngaged = opening(5, on: 5, from: opening(5, on: 4, from: prompted))
        XCTAssertTrue(policy.shouldRequestReview(reEngaged, context: nextVersion))
    }

    // MARK: - Never at a bad moment

    func testDoesNotPromptWhileVideoIsPlaying() {
        let context = ReviewPromptContext(appVersion: "3.2", isPlayingVideo: true)
        XCTAssertFalse(policy.shouldRequestReview(engagedState(), context: context))
    }

    func testDoesNotPromptDuringADelete() {
        let context = ReviewPromptContext(appVersion: "3.2", isDeleting: true)
        XCTAssertFalse(policy.shouldRequestReview(engagedState(), context: context))
    }

    func testDoesNotPromptWhileAnotherAlertIsUp() {
        let context = ReviewPromptContext(appVersion: "3.2", isPresentingOtherUI: true)
        XCTAssertFalse(policy.shouldRequestReview(engagedState(), context: context))
    }

    func testDefaultPolicyRequiresTenOpensAcrossTwoDays() {
        let defaultPolicy = ReviewPromptPolicy()
        XCTAssertEqual(defaultPolicy.requiredViewerOpens, 10)
        XCTAssertEqual(defaultPolicy.requiredEngagedDays, 2)
    }
}

final class ReviewPromptStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ReviewPromptStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMissingKeysLoadEmptyState() {
        XCTAssertEqual(ReviewPromptStore(defaults: defaults).load(), ReviewPromptState())
    }

    func testSaveThenLoadRoundTrips() {
        let store = ReviewPromptStore(defaults: defaults)
        let state = ReviewPromptState(viewerOpenCount: 7,
                                      engagedDayCount: 2,
                                      lastEngagedDay: Date(timeIntervalSince1970: 1_800_000_000),
                                      lastPromptedVersion: "3.1")
        store.save(state)
        XCTAssertEqual(ReviewPromptStore(defaults: defaults).load(), state)
    }

    func testSavingClearedFieldsRemovesThem() {
        let store = ReviewPromptStore(defaults: defaults)
        store.save(ReviewPromptState(viewerOpenCount: 3, engagedDayCount: 1,
                                     lastEngagedDay: Date(timeIntervalSince1970: 1_800_000_000),
                                     lastPromptedVersion: "3.1"))
        store.save(ReviewPromptState(lastPromptedVersion: "3.1"))
        XCTAssertEqual(store.load(), ReviewPromptState(lastPromptedVersion: "3.1"))
    }
}
