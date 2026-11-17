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
    var deactivateError: Error = FakeAudioSessionError()

    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        calls.append(.setCategory(category, mode, options))
        if failCategory { throw FakeAudioSessionError() }
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        calls.append(.setActive(active, options))
        if active && failActivate { throw FakeAudioSessionError() }
        if !active && failDeactivate { throw deactivateError }
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

    // Browsing: ambient mixes with other apps, so muted grid thumbnails never interrupt Music.
    private let browsing = FakeAudioSession.Call.setCategory(.ambient, .default, [])
    // Viewer video: non-mixable playback pauses other audio and plays with the silent switch on.
    private let viewerVideo = FakeAudioSession.Call.setCategory(.playback, .moviePlayback, [])

    func testConfigureSetsAmbientCategoryWithoutActivating() {
        sut.configureCategory()

        XCTAssertEqual(session.calls, [browsing])
        XCTAssertFalse(sut.isActive)
    }

    func testPlaybackStartedSwitchesToNonMixingPlaybackAndActivatesOnce() {
        sut.playbackStarted()
        sut.playbackStarted()

        XCTAssertEqual(session.calls, [viewerVideo, .setActive(true, [])])
        XCTAssertTrue(sut.isActive)
    }

    func testPlaybackStoppedDeactivatesNotifiesOthersAndReturnsToAmbient() {
        sut.playbackStarted()
        sut.playbackStopped()

        XCTAssertEqual(session.calls, [viewerVideo, .setActive(true, []), .setActive(false, [.notifyOthersOnDeactivation]), browsing])
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

    func testActivationFailureIsLoggedLeavesSessionInactiveAndReturnsToAmbient() {
        session.failActivate = true

        sut.playbackStarted()

        XCTAssertEqual(logged.count, 1)
        XCTAssertFalse(sut.isActive)
        XCTAssertEqual(session.calls.last, browsing)
    }

    func testDeactivationFailureIsLoggedAndCanBeRetried() {
        sut.playbackStarted()
        session.failDeactivate = true

        sut.playbackStopped()

        XCTAssertEqual(logged.count, 1)
        XCTAssertTrue(sut.isActive)
        XCTAssertNotEqual(session.calls.last, browsing, "stay in playback until deactivation succeeds")

        session.failDeactivate = false
        sut.playbackStopped()

        XCTAssertFalse(sut.isActive)
        XCTAssertEqual(logged.count, 1)
        XCTAssertEqual(session.calls.last, browsing)
    }

    func testBusyDeactivationCountsAsInactiveSoTheNextVideoActivatesAgain() {
        // Apple: deactivating with running audio objects stops them, deactivates the session, and
        // then reports isBusy (e.g. muted grid loops still playing behind the viewer). Codex review on PR #26.
        sut.playbackStarted()
        session.failDeactivate = true
        session.deactivateError = NSError(domain: NSOSStatusErrorDomain, code: AVAudioSession.ErrorCode.isBusy.rawValue)

        sut.playbackStopped()

        XCTAssertFalse(sut.isActive)
        XCTAssertEqual(logged.count, 1)
        XCTAssertEqual(session.calls.last, browsing)

        session.failDeactivate = false
        session.calls = []
        sut.playbackStarted()

        XCTAssertEqual(session.calls, [viewerVideo, .setActive(true, [])])
        XCTAssertTrue(sut.isActive)
    }
}
