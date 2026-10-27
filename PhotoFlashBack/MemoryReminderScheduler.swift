import Foundation
import Photos
import UIKit
import UserNotifications

/// The slice of `UNUserNotificationCenter` the scheduler needs, so tests can substitute a fake.
protocol NotificationScheduling: Sendable {
    func isAuthorized() async -> Bool
    func pendingIdentifiers() async -> [String]
    func remove(identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationScheduling {
    func isAuthorized() async -> Bool {
        let status = await notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    func pendingIdentifiers() async -> [String] {
        await pendingNotificationRequests().map(\.identifier)
    }

    func remove(identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Keeps the pending "memory of the day" local notifications in sync with the photo library
/// and the user's reminder settings. Only requests whose identifier starts with
/// `MemoryReminderPlanner.identifierPrefix` are ever removed.
actor MemoryReminderScheduler {
    static let monthKey = "memoryReminderMonth"
    static let dayKey = "memoryReminderDay"

    static let shared = MemoryReminderScheduler(
        center: UNUserNotificationCenter.current(),
        settings: { MemoryReminderSettingsStore.load() },
        count: { month, day in
            MemoryQuery.count(month: month, day: day, filter: MediaFilterStore.load())
        },
        thumbnail: { reminder in
            await MemoryReminderScheduler.makeThumbnailAttachment(for: reminder)
        }
    )

    private let center: NotificationScheduling
    private let settings: @Sendable () -> MemoryReminderSettings
    private let count: @Sendable (Int, Int) -> Int
    private let thumbnail: @Sendable (PlannedReminder) async -> UNNotificationAttachment?
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    /// The most recently queued refresh. Actors are reentrant across `await`, so overlapping
    /// `refresh()` calls are chained through this task to run strictly one after another.
    private var latestRefresh: Task<Void, Never>?

    init(
        center: NotificationScheduling,
        settings: @escaping @Sendable () -> MemoryReminderSettings,
        count: @escaping @Sendable (Int, Int) -> Int,
        thumbnail: @escaping @Sendable (PlannedReminder) async -> UNNotificationAttachment?,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.center = center
        self.settings = settings
        self.count = count
        self.thumbnail = thumbnail
        self.now = now
        self.calendar = calendar
    }

    func refresh() async {
        let previous = latestRefresh
        let task = Task { [self] in
            await previous?.value
            await performRefresh()
        }
        latestRefresh = task
        await task.value
    }

    private func performRefresh() async {
        let currentSettings = settings()
        guard currentSettings.enabled, await center.isAuthorized() else {
            await removeMemoryRequests()
            Self.removeThumbnails(keeping: [])
            return
        }

        let reminders = MemoryReminderPlanner.plan(
            now: now(),
            calendar: calendar,
            settings: currentSettings,
            count: count
        )

        var requests: [UNNotificationRequest] = []
        var keptThumbnailNames: Set<String> = []
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = ""
            content.body = MemoryReminderPlanner.body(count: reminder.count, month: reminder.month, day: reminder.day)
            content.sound = .default
            content.userInfo = [Self.monthKey: reminder.month, Self.dayKey: reminder.day]
            if reminder.wantsThumbnail, let attachment = await thumbnail(reminder) {
                content.attachments = [attachment]
                keptThumbnailNames.insert(Self.thumbnailFileName(for: reminder.identifier))
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.fireDateComponents, repeats: false)
            requests.append(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
        }

        await removeMemoryRequests()
        Self.removeThumbnails(keeping: keptThumbnailNames)
        for request in requests {
            try? await center.add(request)
        }
    }

    private func removeMemoryRequests() async {
        let stale = await center.pendingIdentifiers().filter { $0.hasPrefix(MemoryReminderPlanner.identifierPrefix) }
        guard !stale.isEmpty else { return }
        center.remove(identifiers: stale)
    }

    // MARK: Thumbnails

    private static var thumbnailDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MemoryReminders", isDirectory: true)
    }

    private static func thumbnailFileName(for identifier: String) -> String {
        "\(identifier).jpg"
    }

    private static func removeThumbnails(keeping keptNames: Set<String>) {
        guard let directory = thumbnailDirectory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for file in files where file.hasSuffix(".jpg") && !keptNames.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    private static func makeThumbnailAttachment(for reminder: PlannedReminder) async -> UNNotificationAttachment? {
        let assets = MemoryQuery.assets(month: reminder.month, day: reminder.day, filter: MediaFilterStore.load())
        guard let asset = assets.randomElement(),
              let image = await requestImage(for: asset),
              let data = image.jpegData(compressionQuality: 0.8),
              let directory = thumbnailDirectory else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(thumbnailFileName(for: reminder.identifier))
            try data.write(to: url, options: .atomic)
            return try UNNotificationAttachment(identifier: reminder.identifier, url: url)
        } catch {
            return nil
        }
    }

    private static func requestImage(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        // The handler can fire more than once, or with only an error/cancellation, so resume
        // exactly once: a leaked continuation would hang every refresh chained behind this one.
        let lock = NSLock()
        var didResume = false
        return await withCheckedContinuation { continuation in
            let resume: (UIImage?) -> Void = { image in
                lock.lock()
                let alreadyResumed = didResume
                didResume = true
                lock.unlock()
                guard !alreadyResumed else { return }
                continuation.resume(returning: image)
            }
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true || info?[PHImageErrorKey] != nil {
                    resume(nil)
                    return
                }
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                resume(image)
            }
        }
    }
}
