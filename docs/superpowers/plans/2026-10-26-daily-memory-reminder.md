# Daily Memory Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send one local notification per day ("📸 24 memories from Oct 27") at a user-chosen time on dates that have memories; tapping opens the grid on that notification's date.

**Architecture:** A pure `MemoryReminderPlanner` computes a 30-day rolling window of one-shot reminders from a count function; an actor `MemoryReminderScheduler` feeds it PhotoKit counts, attaches thumbnails to the first 3, and replaces pending `memory-*` requests. Taps are stashed as `PendingMemoryDate` and routed through `SceneDelegate` to a new `PhotosViewController.show(month:day:)`, mirroring the existing widget deep-link flow.

**Tech Stack:** Swift 5, UIKit, UserNotifications, Photos, XCTest. iOS deployment target 16.0 (app).

**Spec:** `docs/superpowers/specs/2026-10-26-daily-memory-reminder-design.md`

**Testing:** unit tests + simulator + device test (iPhone 18 Pro Max)

## Global Constraints

- Local notifications only. No APNs, no `aps-environment`, no new entitlements, no Info.plist changes.
- Reminder default: **off**, **9:00**. No permission prompt at launch; prompt only when the user turns the switch on.
- Window **30** days; thumbnails on the first **3** planned reminders only.
- Identifier format `memory-YYYY-MM-DD`; only identifiers with prefix `memory-` are ever removed by this feature.
- Body copy exactly `📸 N memories from Mon D`, and `📸 1 memory from Mon D` when N = 1. "Mon" is the 3-letter month abbreviation (`Oct`), from `Calendar.shortMonthSymbols` with an `en_US_POSIX` locale. (The spec says "from `monthArray`", but `PhotosViewModel.monthArray` holds full names, so it can't produce "Oct".) No year in the text.
- Memory count rule = grid rule: image or video, creation date matches month/day in any year, current `MediaFilter` applied.
- The Xcode project does **not** use synchronized folders (`objectVersion = 56`). Every new `.swift` file must be added to `PhotoFlashBack.xcodeproj` in the right target (app files → `PhotoFlashBack`; test files → `PhotoFlashBackTests`). Add via Xcode or by editing `project.pbxproj` (PBXFileReference + PBXBuildFile + group + Sources phase).
- Test command (used in every task):
  `xcodebuild test -project PhotoFlashBack.xcodeproj -scheme PhotoFlashBack -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -only-testing:PhotoFlashBackTests`
  Must end in `** TEST SUCCEEDED **` with no new compiler warnings.

## Review Focus

1. **Chosen time equal to "now" to the minute** → today is skipped (the rule is strictly-after). Test in Task 2.
2. **DST transition inside the window** (US 2026-03-08) → every reminder still fires at the wall-clock hour/minute. Test in Task 2.
3. **Notification `userInfo` missing or malformed** (another notification, an older build, out-of-range day) → ignored, no crash, no navigation. Test in Task 4.
4. **Switch toggled on then quickly off** → once both refreshes finish, no `memory-*` requests are pending; non-`memory-*` requests are never touched. Test in Task 3.
5. **Media filter excludes everything for a date** (e.g. Videos only, date has only photos) → counts 0 and is skipped. Test in Task 1.

---

### Task 1: Shared memory query + settings store

Extracts the grid's date/media matching into one place, so the grid and the reminder counter can't drift, and adds the persisted reminder settings.

**Files:**
- Create: `PhotoFlashBack/MemoryQuery.swift`
- Create: `PhotoFlashBack/MemoryReminderSettings.swift`
- Modify: `PhotoFlashBack/PhotosViewModel.swift:111-160` (`fetchPhoto()` uses `MemoryQuery`)
- Test: `PhotoFlashBackTests/MemoryQueryTests.swift`, `PhotoFlashBackTests/MemoryReminderSettingsTests.swift`

**Interfaces:**
- Produces:
  - `enum MemoryQuery { static func fetchOptions(month: Int, day: Int) -> PHFetchOptions; static func isMemory(creationDate: Date?, kind: MediaFilter.Kind, month: Int, day: Int, filter: MediaFilter, calendar: Calendar = .current) -> Bool; static func count(month: Int, day: Int, filter: MediaFilter) -> Int; static func assets(month: Int, day: Int, filter: MediaFilter) -> [PHAsset] }`
  - `struct MemoryReminderSettings: Equatable { var enabled: Bool; var hour: Int; var minute: Int; static let `default` = MemoryReminderSettings(enabled: false, hour: 9, minute: 0) }`
  - `enum MemoryReminderSettingsStore { static let enabledKey = "memoryReminder.enabled"; static let hourKey = "memoryReminder.hour"; static let minuteKey = "memoryReminder.minute"; static func load(from: UserDefaults = .standard) -> MemoryReminderSettings; static func save(_: MemoryReminderSettings, to: UserDefaults = .standard) }`

- [ ] **Step 1: Write failing tests**

`MemoryQueryTests`:
- `testMatchesSameMonthDayAnyYear`: creationDate 2019-10-27 10:00, kind `.photo`, month 10, day 27, unfiltered → `true`.
- `testRejectsOtherDay`: 2019-10-28 → `false`; `nil` creationDate → `false`.
- `testFilterExcludingKindRejects` (Review Focus 5): filter `MediaFilter(photos: false, videos: true, screenshots: false)`, kind `.photo` → `false`; kind `.video` → `true`.
- `testAllOffFilterIsUnfiltered`: all-false filter, kind `.screenshot` → `true`.

`MemoryReminderSettingsTests` (isolated suite `MemoryReminderSettingsTests.<UUID>`, like `MediaFilterTests`):
- `testMissingKeysLoadDefaults`: `load` == `.default` (enabled false, 9, 0).
- `testRoundTrip`: save `(true, 21, 45)` → load returns the same value.

- [ ] **Step 2: Run tests, expect compile failure** (`MemoryQuery` / `MemoryReminderSettingsStore` undefined).

- [ ] **Step 3: Implement**
- `fetchOptions` builds exactly the predicate `PhotosViewModel.fetchPhoto()` builds today (`Helper.compoundPredicateFrom` OR'd, AND image-or-video). Sort by `creationDate` descending.
- `isMemory` compares month/day components from `calendar`, then `filter.includes(kind:)`.
- `count`/`assets` fetch with `fetchOptions` and keep assets where `isMemory(..., kind: MediaFilter.kind(mediaType:mediaSubtypes:))`.
- Replace the inline predicate and the `assetDay == day && assetMonth == month` + `filter.includes` checks in `PhotosViewModel.fetchPhoto()` with `MemoryQuery.fetchOptions` / `MemoryQuery.isMemory`. Grouping by year stays in the view model. Apply the same change to `fetchPhotoWithProgress()` if it duplicates the predicate.
- Settings store mirrors `MediaFilterStore`: missing keys fall back to `.default` values.

- [ ] **Step 4: Run the test command.** Expect `** TEST SUCCEEDED **` (existing `MediaFilterTests` and `ImageRequestApplyGateTests` included).

- [ ] **Step 5: Commit** `git commit -m "Extract MemoryQuery and add reminder settings store"`

---

### Task 2: MemoryReminderPlanner

**Files:**
- Create: `PhotoFlashBack/MemoryReminderPlanner.swift`
- Test: `PhotoFlashBackTests/MemoryReminderPlannerTests.swift`

**Interfaces:**
- Consumes: `MemoryReminderSettings` (Task 1).
- Produces:
  - `struct PlannedReminder: Equatable { let identifier: String; let month: Int; let day: Int; let fireDateComponents: DateComponents /* year, month, day, hour, minute */; let count: Int; let wantsThumbnail: Bool }`
  - `enum MemoryReminderPlanner { static let identifierPrefix = "memory-"; static func plan(now: Date, calendar: Calendar, settings: MemoryReminderSettings, windowDays: Int = 30, thumbnailDays: Int = 3, count: (_ month: Int, _ day: Int) -> Int) -> [PlannedReminder]; static func body(count: Int, month: Int, day: Int) -> String }`

- [ ] **Step 1: Write failing tests.** Use a Gregorian calendar with `TimeZone(identifier: "America/Los_Angeles")` and settings `(true, 9, 0)` unless stated.
- `testDisabledReturnsEmpty`: enabled false → `[]`.
- `testSkipsZeroCountDays`: now 2026-10-26 08:00, count returns 0 for Oct 28 and 5 otherwise → no reminder with day 28; Oct 26 and Oct 27 present.
- `testStartsTodayWhenTimeAhead`: now 2026-10-26 08:59 → first identifier `memory-2026-10-26`.
- `testStartsTomorrowWhenTimePassed`: now 2026-10-26 09:01 → first `memory-2026-10-27`.
- `testTimeEqualToNowStartsTomorrow` (Review Focus 1): now 2026-10-26 09:00:00 → first `memory-2026-10-27`.
- `testWindowCappedAt30AndThumbnailsOnFirst3Planned`: now 2026-10-26 08:00 and also 10:00, all counts 1 → 30 reminders each time; `wantsThumbnail` true for indices 0–2 only. Variant: count 0 for the first 2 days → thumbnails go to the first 3 *planned* reminders.
- `testFeb29OnlyInLeapYears`: now 2027-02-20 → no `memory-2027-02-29`; now 2028-02-20 → `memory-2028-02-29` present with month 2, day 29.
- `testYearWraparound`: now 2026-12-30 10:00 → contains `memory-2026-12-31` and `memory-2027-01-01`, with `fireDateComponents.year` 2026 and 2027.
- `testDSTKeepsWallClockTime` (Review Focus 2): now 2026-03-05 10:00 → every reminder's `fireDateComponents.hour == 9`, `minute == 0`, including 2026-03-08 and 03-09.
- `testFireComponentsUseChosenTime`: settings `(true, 21, 45)` → hour 21, minute 45.
- `testIdentifiersUniqueAndFormatted`: all identifiers unique and match `^memory-\d{4}-\d{2}-\d{2}$`.
- `testBodyCopy`: `body(count: 24, month: 10, day: 27) == "📸 24 memories from Oct 27"`; `body(count: 1, month: 10, day: 27) == "📸 1 memory from Oct 27"`; `body(count: 3, month: 9, day: 5) == "📸 3 memories from Sep 5"`.

- [ ] **Step 2: Run tests, expect compile failure.**

- [ ] **Step 3: Implement** in `MemoryReminderPlanner.swift`. First day = today if today's fire date (`calendar.date(bySettingHour:minute:second:of:)`) is strictly `> now`, else tomorrow. Walk exactly `windowDays` calendar days from the first day (the window is 30 calendar days, not 30 reminders), emitting one reminder for each day with count > 0. Invalid dates like Feb 29 can't occur because days are generated by `calendar.date(byAdding: .day, ...)`. Body uses an `en_US_POSIX` calendar's `shortMonthSymbols[month - 1]`.

- [ ] **Step 4: Run the test command.** Expect `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit** `git commit -m "Add MemoryReminderPlanner"`

---

### Task 3: MemoryReminderScheduler + refresh hooks

**Files:**
- Create: `PhotoFlashBack/MemoryReminderScheduler.swift`
- Modify: `PhotoFlashBack/SceneDelegate.swift:69-81` (`sceneDidEnterBackground`)
- Modify: `PhotoFlashBack/AppDelegate.swift:52-80` (`handleBackgroundFetch`)
- Modify: `PhotoFlashBack/PhotosViewController+Toolbar.swift:21-23` (`filterDropdown.onChange`)
- Test: `PhotoFlashBackTests/MemoryReminderSchedulerTests.swift`

**Interfaces:**
- Consumes: `MemoryReminderPlanner.plan`, `.body`, `.identifierPrefix` (Task 2); `MemoryReminderSettingsStore.load`, `MemoryQuery.count`/`assets`, `MediaFilterStore.load` (Task 1).
- Produces:
  - `protocol NotificationScheduling: Sendable { func isAuthorized() async -> Bool; func pendingIdentifiers() async -> [String]; func remove(identifiers: [String]); func add(_ request: UNNotificationRequest) async throws }`, plus a `UNUserNotificationCenter` conformance (authorized = `.authorized` or `.provisional`).
  - `actor MemoryReminderScheduler { static let shared: MemoryReminderScheduler; init(center: NotificationScheduling, settings: @escaping @Sendable () -> MemoryReminderSettings, count: @escaping @Sendable (Int, Int) -> Int, thumbnail: @escaping @Sendable (PlannedReminder) async -> UNNotificationAttachment?, now: @escaping @Sendable () -> Date = Date.init, calendar: Calendar = .current); func refresh() async }`
  - `userInfo` keys: `MemoryReminderScheduler.monthKey = "memoryReminderMonth"`, `dayKey = "memoryReminderDay"`.

- [ ] **Step 1: Write failing tests** with a `FakeCenter` (records removes/adds; preloaded pending IDs `["memory-2026-10-20", "other-123"]`), a constant count of 2, and a thumbnail closure returning `nil`.
- `testDisabledRemovesOnlyMemoryRequests`: settings disabled → removed IDs == `["memory-2026-10-20"]`, nothing added, `other-123` untouched.
- `testUnauthorizedRemovesAndAddsNothing`: enabled but `isAuthorized` false → same as above.
- `testEnabledReplacesWithPlan`: enabled, authorized, now 2026-10-26 08:00 → old `memory-*` removed; 30 requests added; first has identifier `memory-2026-10-26`, body `📸 2 memories from Oct 26`, `UNCalendarNotificationTrigger` with `repeats == false` and hour 9, and `userInfo` month 10, day 26.
- `testToggleOnThenOffLeavesNothingPending` (Review Focus 4): a mutable settings box, enabled → start `refresh()`, set disabled → `refresh()`, await both → the fake center's live pending set has no `memory-*` IDs and still contains `other-123`.

- [ ] **Step 2: Run tests, expect compile failure.**

- [ ] **Step 3: Implement `refresh()`**: load settings → if `!enabled || !(await center.isAuthorized())`, remove the pending IDs with `identifierPrefix`, delete `Caches/MemoryReminders/`, return. Otherwise plan → build `UNMutableNotificationContent` (title empty, body from `body`, sound `.default`, `userInfo` keys above). Attach a thumbnail when `wantsThumbnail` and the closure returns one. Remove old `memory-*` IDs and any `Caches/MemoryReminders/*.jpg` not used by the new plan, then add each request. `shared` wires real dependencies: `UNUserNotificationCenter.current()`, `MemoryReminderSettingsStore.load()`, `MemoryQuery.count(month:day:filter: MediaFilterStore.load())`. The thumbnail closure picks `MemoryQuery.assets(...).randomElement()`, requests a 300×300 `.aspectFill` image (`isNetworkAccessAllowed = true`, `deliveryMode = .highQualityFormat`), writes JPEG (0.8) to `Caches/MemoryReminders/<identifier>.jpg`, and returns `try? UNNotificationAttachment(identifier:url:)`. Any failure returns `nil`.

- [ ] **Step 4: Add refresh hooks** (fire-and-forget `Task { await MemoryReminderScheduler.shared.refresh() }`):
  - `SceneDelegate.sceneDidEnterBackground`, after `scheduleBackgroundFetch()`.
  - `AppDelegate.handleBackgroundFetch`: `await` it inside the existing `Task`, before `setTaskCompleted`, so iOS doesn't suspend mid-refresh.
  - `PhotosViewController+Toolbar` `filterDropdown.onChange`, after `MediaFilterStore.save(filter)`.

- [ ] **Step 5: Run the test command.** Expect `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit** `git commit -m "Add MemoryReminderScheduler and refresh hooks"`

---

### Task 4: Notification tap routing

**Files:**
- Create: `PhotoFlashBack/PendingMemoryDate.swift`
- Modify: `PhotoFlashBack/AppDelegate.swift` (adopt `UNUserNotificationCenterDelegate`, set in `didFinishLaunchingWithOptions`)
- Modify: `PhotoFlashBack/SceneDelegate.swift` (`routePendingMemoryDate()`, called from `sceneDidBecomeActive` before `routePendingWidgetPhoto()`)
- Modify: `PhotoFlashBack/PhotosViewController.swift:130-175` (`viewDidLoad` consumes pending date; new `show(month:day:)`; `refreshIfNotToday()` rewritten on top of it)
- Test: `PhotoFlashBackTests/PendingMemoryDateTests.swift`

**Interfaces:**
- Consumes: `MemoryReminderScheduler.monthKey` / `dayKey` (Task 3).
- Produces:
  - `enum PendingMemoryDate { static let key = "PendingMemoryDate"; static func parse(userInfo: [AnyHashable: Any]) -> (month: Int, day: Int)?; static func store(month: Int, day: Int, in: UserDefaults = .standard); static func take(from: UserDefaults = .standard) -> (month: Int, day: Int)? /* reads and clears */ }`
  - `PhotosViewController.show(month: Int, day: Int)`
  - `SceneDelegate.routePendingMemoryDate()` (internal, so `AppDelegate` can call it through the active scene's delegate)

- [ ] **Step 1: Write failing tests** (`PendingMemoryDateTests`, isolated suite):
- `testParsesValidUserInfo`: `[monthKey: 10, dayKey: 27]` → `(10, 27)`.
- `testRejectsMissingOrMalformed` (Review Focus 3): `[:]`, `[monthKey: "10", dayKey: 27]`, `[monthKey: 13, dayKey: 1]`, `[monthKey: 2, dayKey: 30]`, `[monthKey: 4, dayKey: 31]` → `nil`. `[monthKey: 2, dayKey: 29]` → `(2, 29)`.
- `testTakeClears`: `store(10, 27)` → `take` returns `(10, 27)`, then a second `take` returns `nil`.

- [ ] **Step 2: Run tests, expect compile failure.**

- [ ] **Step 3: Implement `PendingMemoryDate`.** Validity: month 1–12; day 1 through the max for that month in a leap year (Feb → 29), matching the grid picker's clamping.

- [ ] **Step 4: Wire tap handling**
  - `AppDelegate`: `UNUserNotificationCenter.current().delegate = self` in `didFinishLaunchingWithOptions`.
  - `didReceive`: only for identifiers with `MemoryReminderPlanner.identifierPrefix`. `parse`, then `store`, then `UserDefaults.standard.set(false, forKey: "ShouldRefresh")`. If the scene is `.foregroundActive`, call its `SceneDelegate.routePendingMemoryDate()`. Call the completion handler.
  - `willPresent`: `[.banner, .list, .sound]`.
  - `SceneDelegate.routePendingMemoryDate()`: no grid → return and keep the value. Otherwise `dismissPresentedIfNeeded` → `PendingMemoryDate.take()` → `photosVC.show(month:day:)`. In `sceneDidBecomeActive`, call it before `routePendingWidgetPhoto()`.
  - `PhotosViewController.viewDidLoad`: at the very top, before `setupViews()`, `if let p = PendingMemoryDate.take() { viewModel.month = p.month; viewModel.day = p.day }`. Confirm `setupViews()` selects picker rows from `viewModel`; if it hardcodes today, make it read from `viewModel` instead.
  - `show(month:day:)`: if already on that date, call `openPendingWidgetPhoto()` and return (keeps the widget path's existing behavior). Otherwise set the view model, select both picker rows (not animated), and `fetchPhotos()`. Rewrite `refreshIfNotToday()` as `show(month: today.month, day: today.day)`.

- [ ] **Step 5: Run the test command.** Expect `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit** `git commit -m "Route memory reminder taps to the notification's date"`

---

### Task 5: Settings UI + permission flow

**Files:**
- Modify: `PhotoFlashBack/SettingsViewController.swift` (whole table data source/delegate)

**Interfaces:**
- Consumes: `MemoryReminderSettingsStore` (Task 1), `MemoryReminderScheduler.shared.refresh()` (Task 3).

- [ ] **Step 1: Restructure sections.** `numberOfSections` → 2. Section 0 is "Daily Reminder": row 0 "Memory of the Day" with a `UISwitch` accessory; row 1 "Time" with a compact `UIDatePicker` (`.time`, `.compact`) accessory, present only while the switch shows on. Footer: `Get a notification each day when you have memories from that date.` Section 1 is the existing `options`. `didSelectRowAt` returns early for section 0, and the existing `indexPath.row` branches run only for section 1.

- [ ] **Step 2: Switch state.** In `viewWillAppear`, read `getNotificationSettings`. Shown state = `settings.enabled && (authorized || provisional)`. Reload section 0 on the main thread.

- [ ] **Step 3: Toggle on.** Call `requestAuthorization(options: [.alert, .sound])`. If granted, save `enabled = true`, `refresh()`, and insert the Time row. If denied, set the switch back to off without saving, then show an alert: title `Notifications are turned off for Rewind`, actions `Open Settings` (opens `UIApplication.openNotificationSettingsURLString`) and `Cancel`. Toggle off → save `enabled = false`, `refresh()`, delete the Time row.

- [ ] **Step 4: Time change.** On `.valueChanged`, save hour/minute immediately. Debounce `refresh()` by 0.5 s (cancel the prior pending `Task`/work item).

- [ ] **Step 5: Build and run the test command.** Expect `** TEST SUCCEEDED **`, with no new warnings.

- [ ] **Step 6: Simulator check (iPhone 18 Pro Max simulator):** "Rate the App", "Provide Feedback", "Send Tips" and "Share with Friends" each still trigger their own action. Toggling on shows the system prompt; Allow shows the Time row; Deny reverts the switch and shows the alert.

- [ ] **Step 7: Commit** `git commit -m "Add daily memory reminder settings"`

---

### Task 6: End-to-end verification + README

**Files:**
- Modify: `README.md` (Features: one bullet for the daily memory reminder; Tests: destination → `iPhone 18 Pro Max`)

- [ ] **Step 1: Simulator pass** (iPhone 18 Pro Max simulator, a library with photos on upcoming dates):
  - Enable, set the time 2 minutes ahead, lock: banner reads `📸 N memories from Mon D`, thumbnail shown, N equals the grid count for that date.
  - Kill the app, tap the notification: the grid opens directly on that date (no flash of today).
  - Background the app with a photo viewer open, tap the notification: the viewer is dismissed and the grid switches date.
  - With Settings open, tap: Settings is dismissed and the grid switches date.
  - Disable: pending `memory-*` requests are gone (log `pendingNotificationRequests` count in a debug build, or confirm no banner at the set time).
  - Widget tap regression: tapping a widget photo still opens that photo.
- [ ] **Step 2: Device pass (iPhone 18 Pro Max):** repeat Step 1. Leave the reminder on for 2 days without opening the app; the next day's reminder arrives. Revoke permission in iOS Settings, then reopen app Settings: the switch shows off. Re-grant: the switch shows on.
- [ ] **Step 3: Final checks:** run the test command → `** TEST SUCCEEDED **`; `git diff --check origin/main...HEAD` → no output.
- [ ] **Step 4: Commit** `git commit -m "Document daily memory reminder"`
