# Media Type Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent Photos / Videos / Screenshots toggles to the on-this-day grid, with overflow+filter dropdowns, and exclude screenshots from the widget.

**Architecture:** `MediaFilter` owns flags, UserDefaults, and asset classification. `PhotosViewModel` drops non-matching assets after the existing date fetch. Toolbar chrome lives in small UIKit views; `PhotoManager` skips screenshots for widget picks.

**Tech Stack:** UIKit, Photos, UserDefaults, XCTest, existing PhotoFlashBack Xcode project (objectVersion 56, explicit file refs).

**Spec:** `docs/superpowers/specs/2026-08-19-media-filter-design.md`

---

## File structure

- Create: `PhotoFlashBack/MediaFilter.swift` — flags, load/save, `includes`
- Create: `PhotoFlashBack/ToolbarDropdownViews.swift` — overlay, overflow panel, filter panel
- Create: `PhotoFlashBack/PhotosViewController+Toolbar.swift` — overflow/filter buttons and apply-on-dismiss
- Create: `PhotoFlashBackTests/MediaFilterTests.swift` — unit tests
- Modify: `PhotoFlashBack/PhotosViewModel.swift` — filter while grouping
- Modify: `PhotoFlashBack/PhotoManager.swift` — skip screenshots
- Modify: `PhotoFlashBack/SkeletonView.swift` — filtered empty state
- Modify: `PhotoFlashBack/PhotosViewController.swift` — chrome wiring, empty state choice
- Modify: `PhotoFlashBack.xcodeproj/project.pbxproj` — add files + unit test target

---

### Task 1: MediaFilter model (TDD)

**Files:**
- Create: `PhotoFlashBack/MediaFilter.swift`
- Create: `PhotoFlashBackTests/MediaFilterTests.swift`
- Modify: `PhotoFlashBack.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add a unit-test target and a failing test file**

`MediaFilter` API:

```swift
struct MediaFilter: Equatable {
    var photos: Bool
    var videos: Bool
    var screenshots: Bool
    var isEffectivelyUnfiltered: Bool { get }
    enum Kind { case photo, video, screenshot }
    static func kind(mediaType: PHAssetMediaType, mediaSubtypes: PHAssetMediaSubtype) -> Kind
    func includes(kind: Kind) -> Bool
}

enum MediaFilterStore {
    static let photosKey = "mediaFilter.photos"
    static let videosKey = "mediaFilter.videos"
    static let screenshotsKey = "mediaFilter.screenshots"
    static func load(from defaults: UserDefaults) -> MediaFilter
    static func save(_ filter: MediaFilter, to defaults: UserDefaults)
}
```

Tests (suite `UserDefaults(suiteName:)` so they never touch `.standard`):

1. Missing keys load as all `true`
2. Saved `photos=false` round-trips; missing others stay `true`
3. All-off is `isEffectivelyUnfiltered == true` and `includes` every kind
4. All-on includes every kind
5. Photos-only includes `.photo`, excludes video and screenshot
6. `kind`: video → `.video`; image+`.photoScreenshot` → `.screenshot`; image otherwise → `.photo`

- [ ] **Step 2: Run tests — they fail because `MediaFilter` is missing**

```bash
xcodebuild test -scheme PhotoFlashBack -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PhotoFlashBackTests
```

Expected: compile or link failure for `MediaFilter`.

- [ ] **Step 3: Implement `MediaFilter.swift` (minimal)**

- [ ] **Step 4: Re-run tests — pass**

- [ ] **Step 5: Commit** `feat: add MediaFilter persistence and classification`

---

### Task 2: Apply filter in fetch + widget

**Files:**
- Modify: `PhotoFlashBack/PhotosViewModel.swift` (`fetchPhoto` and `fetchPhotoWithProgress` enumerate loops)
- Modify: `PhotoFlashBack/PhotoManager.swift` (`fetchMultipleRandomAssetsFromSameDayInPast`)

- [ ] Capture `let filter = MediaFilterStore.load()` on the main actor before `Task.detached`.
- [ ] Inside enumerate, after date match, `guard filter.includes(asset) else { return }`.
- [ ] Widget loop: `guard !asset.mediaSubtypes.contains(.photoScreenshot) else { return }` after date match (still image-only fetch).
- [ ] Commit `feat: apply media filter to grid fetch and widget picks`

---

### Task 3: Empty state copy

**Files:**
- Modify: `PhotoFlashBack/SkeletonView.swift` `EmptyStateType`
- Modify: `PhotoFlashBack/PhotosViewController.swift` completed/failed empty branches (fetch + date picker)

- [ ] Add `case noItemsForFilters(String)` with title `Nothing Matches Your Filters` and message that current filters have no items for that date; hide the date button or keep Select Date (keep Select Date).
- [ ] If sequence empty and `MediaFilterStore.load().isEffectivelyUnfiltered` → existing `.noPhotosForDate`; else `.noItemsForFilters`.
- [ ] Commit `feat: distinguish filtered-empty memories state`

---

### Task 4: Toolbar dropdowns

**Files:**
- Create: `PhotoFlashBack/ToolbarDropdownViews.swift`
- Create: `PhotoFlashBack/PhotosViewController+Toolbar.swift`
- Modify: `PhotoFlashBack/PhotosViewController.swift`

Chrome order (trailing → leading): Settings, Overflow (`ellipsis`), Filter (`line.3.horizontal.decrease`). Date button unchanged at bottom.

Behavior:

- Overlay `UIControl` covering the view (clear or 10% black), z-order below panels, above collection.
- Overflow panel: existing layout + sorting buttons moved into a rounded card; tap either dismisses overlay then runs current handlers.
- Filter panel: three rows Photos / Videos / Screenshots with checkmarks; tap toggles and `MediaFilterStore.save`; does not dismiss.
- Opening one panel dismisses the other.
- Tap overlay: dismiss. If filter panel was showing, compare `MediaFilterStore.load().appliedSignature` to `viewModel.lastAppliedFilterSignature`; refetch via `fetchPhotos()` only if different.
- Store `lastAppliedFilterSignature` on the view model after each successful fetch (the effective triple: unfiltered → `(true,true,true)`).

- [ ] Commit `feat: add overflow and media filter dropdowns`

---

### Task 5: Verify

- [ ] `xcodebuild test` for PhotoFlashBackTests
- [ ] `xcodebuild build` for PhotoFlashBack
- [ ] Manual checklist from spec (simulator when available)

---

## Spec coverage

| Spec item | Task |
| --- | --- |
| Default all-on / missing keys | 1 |
| All-off still shows all | 1, 2 |
| Persist flags | 1, 4 |
| Classification | 1, 2 |
| In-memory filter after date fetch | 2 |
| Widget photos no screenshots | 2 |
| Filtered empty copy | 3 |
| Overflow + filter UX | 4 |
| Apply on filter dismiss if changed | 4 |
