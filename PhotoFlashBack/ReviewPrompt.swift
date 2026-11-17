//
//  ReviewPrompt.swift
//  PhotoFlashBack
//
//  Decides when to show the system App Store review prompt. It is shown after real use
//  (enough full-screen viewer opens across enough days), at most once per app version, and
//  never while a video plays, a delete is in progress, or another alert/modal is up.
//

import StoreKit
import UIKit

/// Persisted engagement counters for the review prompt.
struct ReviewPromptState: Equatable {
    var viewerOpenCount = 0
    /// Number of distinct calendar days with at least one viewer open.
    var engagedDayCount = 0
    /// Start of the most recent day counted in `engagedDayCount`.
    var lastEngagedDay: Date?
    /// App version (CFBundleShortVersionString) the review prompt was last requested for.
    var lastPromptedVersion: String?
}

/// What is on screen at the moment the prompt would be shown.
struct ReviewPromptContext: Equatable {
    var appVersion: String
    var isPlayingVideo = false
    var isDeleting = false
    /// An alert, sheet, or any other modal is already presented.
    var isPresentingOtherUI = false
}

/// Pure threshold logic: all inputs (state, dates, version, on-screen context) are injected.
struct ReviewPromptPolicy {
    var requiredViewerOpens = 10
    var requiredEngagedDays = 2
    var calendar: Calendar = .current

    func recordingViewerOpen(_ state: ReviewPromptState, at date: Date) -> ReviewPromptState {
        var state = state
        state.viewerOpenCount += 1
        let day = calendar.startOfDay(for: date)
        if state.lastEngagedDay != day {
            state.engagedDayCount += 1
            state.lastEngagedDay = day
        }
        return state
    }

    func shouldRequestReview(_ state: ReviewPromptState, context: ReviewPromptContext) -> Bool {
        guard !context.appVersion.isEmpty,
              state.lastPromptedVersion != context.appVersion,
              !context.isPlayingVideo,
              !context.isDeleting,
              !context.isPresentingOtherUI else {
            return false
        }
        return state.viewerOpenCount >= requiredViewerOpens
            && state.engagedDayCount >= requiredEngagedDays
    }

    /// Marks the prompt as shown for `appVersion` and starts engagement over, so the next
    /// version also has to earn the prompt through fresh use.
    func recordingPrompt(_ state: ReviewPromptState, appVersion: String) -> ReviewPromptState {
        ReviewPromptState(lastPromptedVersion: appVersion)
    }
}

/// UserDefaults persistence for `ReviewPromptState`.
struct ReviewPromptStore {
    static let viewerOpenCountKey = "reviewPrompt.viewerOpenCount"
    static let engagedDayCountKey = "reviewPrompt.engagedDayCount"
    static let lastEngagedDayKey = "reviewPrompt.lastEngagedDay"
    static let lastPromptedVersionKey = "reviewPrompt.lastPromptedVersion"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ReviewPromptState {
        ReviewPromptState(
            viewerOpenCount: defaults.integer(forKey: Self.viewerOpenCountKey),
            engagedDayCount: defaults.integer(forKey: Self.engagedDayCountKey),
            lastEngagedDay: defaults.object(forKey: Self.lastEngagedDayKey) as? Date,
            lastPromptedVersion: defaults.string(forKey: Self.lastPromptedVersionKey)
        )
    }

    func save(_ state: ReviewPromptState) {
        defaults.set(state.viewerOpenCount, forKey: Self.viewerOpenCountKey)
        defaults.set(state.engagedDayCount, forKey: Self.engagedDayCountKey)
        defaults.set(state.lastEngagedDay, forKey: Self.lastEngagedDayKey)
        defaults.set(state.lastPromptedVersion, forKey: Self.lastPromptedVersionKey)
    }
}

/// Thin StoreKit glue around `ReviewPromptPolicy`; only needs a simulator smoke check.
@MainActor
final class ReviewPrompter {
    static let shared = ReviewPrompter()

    private let policy: ReviewPromptPolicy
    private let store: ReviewPromptStore
    private let appVersion: String

    init(policy: ReviewPromptPolicy = ReviewPromptPolicy(),
         store: ReviewPromptStore = ReviewPromptStore(),
         appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") {
        self.policy = policy
        self.store = store
        self.appVersion = appVersion
    }

    func recordViewerOpen(at date: Date = Date()) {
        store.save(policy.recordingViewerOpen(store.load(), at: date))
    }

    /// Call once the full-screen viewer has closed. Waits for the dismissal to settle, then
    /// re-checks what is on screen before asking StoreKit for the review prompt.
    func viewerDidClose(presenter: UIViewController?, wasPlayingVideo: Bool, wasDeleting: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self, weak presenter] in
            guard let self = self,
                  let presenter = presenter,
                  let scene = presenter.view.window?.windowScene,
                  scene.activationState == .foregroundActive else { return }
            let context = ReviewPromptContext(appVersion: self.appVersion,
                                              isPlayingVideo: wasPlayingVideo,
                                              isDeleting: wasDeleting,
                                              isPresentingOtherUI: presenter.presentedViewController != nil)
            let state = self.store.load()
            guard self.policy.shouldRequestReview(state, context: context) else { return }
            self.store.save(self.policy.recordingPrompt(state, appVersion: self.appVersion))
            AppStore.requestReview(in: scene)
        }
    }
}
