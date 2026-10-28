# Daily memory reminder (local notifications)

Date: 2026-10-26  
Status: Draft, awaiting owner review  
App: PhotoFlashBack (iOS)

**Testing:** unit tests + simulator + device test (iPhone 18 Pro Max)

## Goal

Send the user one notification per day, at a time they choose, when they have memories from that date, e.g. "📸 24 memories from Oct 27". Tapping a notification opens the grid on **that notification's date**, even when the user taps an older one from a pile of unread notifications.

Today the app has no notifications. The only background work is the `BGAppRefreshTask` (`com.YangSong.PhotoFlashBack.fetch`) that warms the widget.

## Out of scope

- Remote push / APNs / any server (photos never leave the device)
- Mentioning a year in the notification text
- Fallback content for days without memories (e.g. "nearby dates")
- Changing the widget's asset selection rules
- Notification actions (buttons) or a Notification Content Extension

## Product rules

| Situation | Behavior |
| --- | --- |
| Fresh install / update | Reminder **off**. No permission prompt at launch. |
| User turns switch on | Notification permission requested (iOS prompts only once). Granted → reminders scheduled immediately. Denied → switch snaps back off, alert with "Open Settings" / "Cancel". |
| Default time | 9:00 AM local, changeable in Settings. |
| Date with 0 memories | No notification that day. |
| Date with ≥ 1 memory | One notification at the chosen time: `📸 N memories from Mon D` (`📸 1 memory from Mon D` when N = 1). Month abbreviation from the grid's `monthArray`. |
| Thumbnail | Attached for the next 3 scheduled days only; later days are text-only until a later reschedule moves them into the 3-day window. Thumbnail failure never blocks the notification. |
| Tap (any age) | Opens the grid on the notification's month/day, dismissing anything presented over the grid. |
| Notification arrives while app is in foreground | Shown as a banner. |
| Permission revoked in iOS Settings | Stored `enabled` stays true; nothing is scheduled while unauthorized; the in-app switch shows on only when enabled **and** authorized. |
| Limited / no Photos access | Counts reflect only visible assets; 0 → no notification. |

### What counts as a memory

Same rule as the grid (`PhotosViewModel.fetchPhoto`): images and videos whose creation date has that month and day, in any year, with the current `MediaFilter` applied. The notification number therefore matches what the user sees after tapping (as of scheduling time). The date predicate is extracted into a shared helper used by both the grid and the reminder counter so they cannot drift.

## Scheduling approach

Rolling window of one-shot notifications (chosen over a single repeating trigger, which can't skip empty days or carry a correct count, and over "schedule only tomorrow", which stops as soon as the user skips a day).

- Window: next **30** days (iOS allows 64 pending requests per app).
- Start today if the chosen time is still in the future, otherwise tomorrow.
- One `UNCalendarNotificationTrigger` (year/month/day/hour/minute, `repeats: false`) per non-empty date.
- Identifier: `memory-YYYY-MM-DD`. Each refresh removes all pending `memory-*` requests, then adds the new set.
- Feb 29 is scheduled only in leap years.
- `userInfo` carries `month` and `day`.

Counts are a snapshot at scheduling time. Deleting or importing old photos for a future date is corrected at the next refresh.

### Refresh triggers

`MemoryReminderScheduler.refresh()` is called from:

- `SceneDelegate.sceneDidEnterBackground` (next to `scheduleBackgroundFetch()`)
- `AppDelegate.handleBackgroundFetch` (after the widget fetch)
- `SettingsViewController` when the switch or time changes (time changes debounced)
- `PhotosViewController+Toolbar` after `MediaFilterStore.save`

## Components

### `MemoryReminderSettings.swift`

- `struct MemoryReminderSettings { enabled: Bool; hour: Int; minute: Int }`, defaults `false`, 9, 0.
- `MemoryReminderSettingsStore.load(from:)` / `save(_:to:)` over `UserDefaults` (default `.standard`), mirroring `MediaFilterStore`.

### `MemoryReminderPlanner.swift` (pure, no UIKit / PhotoKit)

- Input: `now: Date`, `calendar: Calendar`, settings, `count: (month, day) -> Int`, `windowDays = 30`, `thumbnailDays = 3`.
- Output: `[PlannedReminder]` with `identifier`, `month`, `day`, `fireDateComponents`, `count`, `wantsThumbnail`.
- `wantsThumbnail` is true for the first 3 **planned** reminders (not the first 3 calendar days).
- Also owns `body(count:month:day:) -> String`.
- Disabled settings → empty plan.

### `MemoryReminderScheduler.swift` (actor, system glue)

`refresh() async`:

1. Load settings; read `authorizationStatus`. If disabled or not `.authorized`/`.provisional`: remove pending `memory-*` requests, delete cached thumbnails, return.
2. Build the plan with a PhotoKit counter (shared date predicate + `MediaFilterStore.load()`).
3. For each `wantsThumbnail` reminder: pick a random matching asset, request a ~300 px JPEG via `PHImageManager`, write to `Caches/MemoryReminders/<identifier>.jpg`, attach with `UNNotificationAttachment`. On any failure, skip the attachment.
4. Remove old `memory-*` requests and stale thumbnail files; add the new requests.

Being an actor serializes overlapping refreshes so they can't interleave remove/add and leave duplicates.

## Tap handling

- `AppDelegate` adopts `UNUserNotificationCenterDelegate`, set in `didFinishLaunchingWithOptions` (required for cold-start taps).
- `didReceive response`: for `memory-*` requests, store `["month": m, "day": d]` under `PendingMemoryDate` in `UserDefaults.standard`. Clear the widget's `ShouldRefresh` so the notification wins if both are pending. If the scene is foreground-active, route immediately.
- `willPresent`: return `[.banner, .list, .sound]`.
- `SceneDelegate.routePendingMemoryDate()` (called from `sceneDidBecomeActive` before widget routing, and from the delegate when already active): find the grid via `photosViewController()`, `dismissPresentedIfNeeded`, call `photosVC.show(month:day:)`, clear `PendingMemoryDate`. No grid yet → keep the pending value.
- Cold start: `PhotosViewController.viewDidLoad` consumes `PendingMemoryDate` (if present) as its initial month/day before its first fetch, avoiding a today-then-date double fetch.
- `PhotosViewController.show(month:day:)`: no-op if already on that date; otherwise set `viewModel.month/day`, select picker rows, `fetchPhotos()`. `refreshIfNotToday()` is rewritten in terms of `show(month:day:)`; its widget behavior is unchanged.

## Settings UI

- New section 0 "Daily Reminder" above the existing rows:
  - "Memory of the Day" with a `UISwitch`.
  - "Time" with a compact `UIDatePicker` (`.time`), visible only while the switch is on.
  - Footer: "Get a notification each day when you have memories from that date."
- Existing four rows move to section 1. `didSelectRowAt` must branch on `indexPath.section` before `indexPath.row`.
- Switch state shown = `enabled && authorized` (re-checked in `viewWillAppear`).
- Denied alert: "Notifications are turned off for Rewind" with "Open Settings" (`UIApplication.openNotificationSettingsURLString`) and "Cancel".

## Capabilities

No new entitlements, no `aps-environment`, no Info.plist changes. Local notifications only need runtime authorization.

## Testing

### Unit tests

`PhotoFlashBackTests/MemoryReminderPlannerTests.swift` (fixed `now`, fixed time zone calendar, fake counter):

- Zero-count dates skipped; each non-empty date gets one reminder at the chosen hour/minute.
- Start today when the time is still ahead, tomorrow when it has passed.
- At most 30 reminders; only the first 3 planned have `wantsThumbnail`.
- Feb 29 only in leap years; Dec 31 → Jan 1 wraparound.
- Body text: "📸 24 memories from Oct 27", "📸 1 memory from Oct 27".
- Identifiers unique and formatted `memory-YYYY-MM-DD`.
- Disabled → empty plan.

`PhotoFlashBackTests/MemoryReminderSettingsTests.swift`: defaults (off, 9:00); save/load round-trip on an isolated `UserDefaults` suite.

### Simulator

- Enable, grant permission, set time ~2 min ahead, lock: text and thumbnail correct.
- Tap from a killed app: grid opens directly on that date.
- Tap from background with a viewer or Settings presented: presented UI dismissed, grid switches date.
- Deny permission: switch reverts, "Open Settings" alert shown.
- Disable: pending `memory-*` requests removed.
- Widget deep-link tap still works (regression for the `refreshIfNotToday()` refactor).

### Device (iPhone 18 Pro Max)

- Repeat the simulator pass.
- Leave enabled for 2 days without opening the app; confirm the next day's reminder arrives.
- Revoke notification permission in iOS Settings, reopen app Settings: switch shows off; re-grant: switch shows on and reminders are rescheduled.
