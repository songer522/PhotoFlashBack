import XCTest
import AVFAudio
@testable import PhotoFlashBack

private struct FakeAudioSessionError: Error {}

private final class FakeAudioSession: AudioSessionControlling {
    enum Call: Equatable {
        case setCategory(AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)
        case setActive(Bool, AVAudioSession.SetActiveOptions)
    }

    var calls: [Call] = []
    var failCategory = false
    var failActivate = false
    var failDeactivate = false

    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        calls.append(.setCategory(category, mode, options))
        if failCategory { throw FakeAudioSessionError() }
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        calls.append(.setActive(active, options))
        if active && failActivate { throw FakeAudioSessionError() }
        if !active && failDeactivate { throw FakeAudioSessionError() }
    }
}

final class VideoAudioSessionTests: XCTestCase {
    private var session: FakeAudioSession!
    private var logged: [String]!
    private var sut: VideoAudioSession!

    override func setUp() {
        super.setUp()
        session = FakeAudioSession()
        logged = []
        sut = VideoAudioSession(session: session, log: { [unowned self] in self.logged.append($0) })
    }

    override func tearDown() {
        sut = nil
        session = nil
        logged = nil
        super.tearDown()
    }

    func testConfigureSetsPlaybackCategoryWithoutActivating() {
        sut.configureCategory()

        XCTAssertEqual(session.calls, [.setCategory(.playback, .default, [.mixWithOthers])])
        XCTAssertFalse(sut.isActive)
    }

    func testPlaybackStartedActivatesSessionOnce() {
        sut.playbackStarted()
        sut.playbackStarted()

        XCTAssertEqual(session.calls, [.setActive(true, [])])
        XCTAssertTrue(sut.isActive)
    }

    func testPlaybackStoppedDeactivatesAndNotifiesOthers() {
        sut.playbackStarted()
        sut.playbackStopped()

        XCTAssertEqual(session.calls, [.setActive(true, []), .setActive(false, [.notifyOthersOnDeactivation])])
        XCTAssertFalse(sut.isActive)
    }

    func testPlaybackStoppedWithoutStartDoesNotTouchSession() {
        sut.playbackStopped()

        XCTAssertTrue(session.calls.isEmpty)
    }

    func testCategoryFailureIsLogged() {
        session.failCategory = true

        sut.configureCategory()

        XCTAssertEqual(logged.count, 1)
    }

    func testActivationFailureIsLoggedAndLeavesSessionInactive() {
        session.failActivate = true

        sut.playbackStarted()

        XCTAssertEqual(logged.count, 1)
        XCTAssertFalse(sut.isActive)
    }

    func testDeactivationFailureIsLoggedAndCanBeRetried() {
        sut.playbackStarted()
        session.failDeactivate = true

        sut.playbackStopped()

        XCTAssertEqual(logged.count, 1)
        XCTAssertTrue(sut.isActive)

        session.failDeactivate = false
        sut.playbackStopped()

        XCTAssertFalse(sut.isActive)
        XCTAssertEqual(logged.count, 1)
    }
}
