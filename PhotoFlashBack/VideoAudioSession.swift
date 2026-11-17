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
/// The `.playback` category is set at launch so viewer video plays sound even with the
/// silent switch on, but the session is only activated while a video is actually playing.
/// That way, launching or browsing the app never touches audio playing in another app,
/// and other apps are notified to resume when our playback stops.
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

    /// Sets the category without activating the session. Safe to call at launch.
    func configureCategory() {
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            log("Failed to set audio session category: \(error)")
        }
    }

    func playbackStarted() {
        guard !isActive else { return }
        do {
            try session.setActive(true, options: [])
            isActive = true
        } catch {
            log("Failed to activate audio session: \(error)")
        }
    }

    func playbackStopped() {
        guard isActive else { return }
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            isActive = false
        } catch {
            log("Failed to deactivate audio session: \(error)")
        }
    }
}
