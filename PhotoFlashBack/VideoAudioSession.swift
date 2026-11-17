//
//  VideoAudioSession.swift
//  PhotoFlashBack
//

import AVFAudio
import os

protocol AudioSessionControlling: AnyObject {
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: AudioSessionControlling {}

/// Owns the app's audio session for full-screen video playback.
///
/// While browsing, the category is `.ambient`: it mixes with other apps, so launching the app
/// or the muted looping grid thumbnails never interrupt Music or a podcast. When a viewer video
/// starts playing, the session switches to non-mixable `.playback` and activates, which pauses
/// other audio and plays sound even with the silent switch on. When it stops, the session is
/// deactivated with `.notifyOthersOnDeactivation` (so the other app can resume) and returns to
/// `.ambient`.
final class VideoAudioSession {
    static let shared = VideoAudioSession()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PhotoFlashBack", category: "AudioSession")

    private let session: AudioSessionControlling
    private let log: (String) -> Void
    private(set) var isActive = false

    init(session: AudioSessionControlling = AVAudioSession.sharedInstance(),
         log: @escaping (String) -> Void = { VideoAudioSession.logger.error("\($0, privacy: .public)") }) {
        self.session = session
        self.log = log
    }

    /// Sets the browsing (ambient) category without activating the session. Safe to call at launch.
    func configureCategory() {
        setBrowsingCategory()
    }

    func playbackStarted() {
        guard !isActive else { return }
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
        } catch {
            log("Failed to set playback audio category: \(error)")
        }
        do {
            try session.setActive(true, options: [])
            isActive = true
        } catch {
            log("Failed to activate audio session: \(error)")
            setBrowsingCategory()
        }
    }

    func playbackStopped() {
        guard isActive else { return }
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            isActive = false
        } catch let error as NSError where error.code == AVAudioSession.ErrorCode.isBusy.rawValue {
            // Apple: with audio objects still running (e.g. muted grid loops behind the viewer),
            // deactivation stops them and deactivates the session before reporting isBusy.
            // The session is inactive, so track it that way or the next video would never activate.
            log("Audio session deactivated while busy; running audio objects were stopped: \(error)")
            isActive = false
        } catch {
            // Stay in playback so a later stop can retry the deactivation and notify others.
            log("Failed to deactivate audio session: \(error)")
            return
        }
        setBrowsingCategory()
    }

    private func setBrowsingCategory() {
        do {
            try session.setCategory(.ambient, mode: .default, options: [])
        } catch {
            log("Failed to set ambient audio category: \(error)")
        }
    }
}
