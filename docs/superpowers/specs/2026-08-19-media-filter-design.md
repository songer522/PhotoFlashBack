# Media type filter (Photos / Videos / Screenshots)

Date: 2026-08-19  
Status: Approved for implementation planning  
App: PhotoFlashBack (iOS)

## Goal

Let users choose which media types appear in the “on this day” grid, driven by feedback that screenshots clutter memories. Default remains “show everything.” The Today widget always shows ordinary photos only (no videos, no screenshots).

## Out of scope

- People, places, search, or timeline redesign
- Per-widget filter settings
- Detecting screenshots by image analysis (use Photos `mediaSubtypes` only)
- Screen Recording as its own type (treat as Video)
- Reloading widget timelines when in-app filters change

## Product rules

| Situation | Panel checkboxes | Grid content |
| --- | --- | --- |
| No keys in `UserDefaults` (fresh install / never changed) | All three on | All types |
| Any mix with at least one type on | Matches saved flags | Matching assets only |
| All three off | All three off | All types (same as unfiltered) |

“All three off” is **not** written back as all-on. The panel keeps showing all off until the user changes it. Application logic treats all-off as unfiltered.

Filters persist across launches. Changing the selected calendar day, pull-to-refresh, and returning from deletion all honor the current effective filter.

## Classification

Use `PHAsset` fields only:

- **Screenshot:** `mediaType == .image` and `mediaSubtypes` contains `.photoScreenshot`
- **Video:** `mediaType == .video`
- **Photo:** any other image, including Live Photos

An asset matches the filter if its class’s flag is on, **unless** the filter is effectively unfiltered (all on **or** all off), in which case every image and video from the existing date fetch is shown.

## Architecture

### `MediaFilter`

Small, UI-free model:

- `photos`, `videos`, `screenshots: Bool`
- Load/save via `UserDefaults` keys such as `mediaFilter.photos`, `mediaFilter.videos`, `mediaFilter.screenshots`
- Missing key → `true` for that flag
- `isEffectivelyUnfiltered`: all true or all false
- `includes(_ asset: PHAsset) -> Bool`

This is the single source of truth for “should this asset appear in the app grid.”

### Toolbar chrome (`PhotosViewController`)

Replace the current top-trailing cluster (settings, layout, sorting, date) with:

**Settings | Overflow | Filter | Date**

Keep existing button size (31×31), white tint, and spacing. Suggested SF Symbols: Overflow `ellipsis`, Filter `line.3.horizontal.decrease`. Settings and date buttons stay as they are.

Two dropdowns are mutually exclusive: opening one dismisses the other.

### Overflow dropdown

Hosts the **existing** layout and sorting `UIButton`s (same icons and `changLayoutButtonTapped` / `changSortingOrderTapped`).

- Tap layout or sorting: dismiss dropdown, then run today’s behavior immediately
- Tap outside: dismiss only; do not change layout or sort

### Filter dropdown

Three independent rows: Photos, Videos, Screenshots, bound to `MediaFilter`.

- Tap a row: toggle checkmark only; do **not** dismiss
- Tap outside: dismiss, then apply
- Apply: if the effective filter (after all-off → unfiltered) differs from what the current grid was built with, call existing `fetchPhotos()` (progress UI and empty states included). If unchanged, dismiss only.

Initial panel state: loaded flags, with missing keys shown as checked.

### `PhotosViewModel`

Keep the current date-based `PHAsset` fetch (images **or** videos for the selected month/day). After fetch, drop assets that `MediaFilter.includes` rejects **before** building `assetDict` / `assetArray` / `assetSequence`. Year grouping, sort order, location headers, and deletion bookkeeping stay unchanged. Do not encode the three-way filter in the Photos `NSPredicate`; classification stays in `MediaFilter.includes`.

### `PhotoManager` (widget)

Widget does **not** read `MediaFilter`. Continue fetching `mediaType == .image` for the same day in past years, and **exclude** `.photoScreenshot`. Empty widget presentation stays as today. Widget refresh policy stays midnight (no reload when the user changes in-app filters).

### Full-screen viewer and deletion

`assetSequence` (and any index mapping into the viewer) only contains filtered assets. After delete, rebuild using the same filter.

## Empty and error states

- Filtered-to-empty day: existing empty-state UI, copy that the current filters have no items (distinct from no-permission and “no memories at all”)
- Photo library denied/restricted: unchanged
- `UserDefaults` unreadable or corrupt flags: treat as all three on
- Pull-to-refresh uses the same filter as a normal fetch

## Testing / acceptance

1. Fresh install: three checks on; grid shows photos, videos, and screenshots; widget shows only non-screenshot photos.
2. Turn Screenshots off, tap outside: screenshots leave the grid; relaunch preserves that.
3. Only Videos on: grid is videos only; empty state if that day has none.
4. All three off: panel shows all off; grid shows all types.
5. Overflow: layout/sort apply immediately and close the panel; outside tap closes without changing them.
6. Opening Filter closes Overflow and vice versa.
7. Date change, pull-to-refresh, and delete-then-return still apply the saved filter.
8. Limited Photos access still fetches; filter still applies to whatever the user granted.

## File sketch

| Unit | Responsibility |
| --- | --- |
| New `MediaFilter.swift` | Flags, persistence, `includes` |
| `PhotosViewController.swift` (+ small dropdown views if needed) | Overflow / Filter chrome, outside-tap, apply-on-dismiss |
| `PhotosViewModel.swift` | Apply filter when assembling asset collections |
| `PhotoManager.swift` | Widget: exclude screenshots |
| Tests for `MediaFilter` | Missing keys, all-off, classification |

Avoid stuffing dropdown layout into `PhotosViewModel`. Prefer a tiny dropdown view over growing `PhotosViewController` further if the chrome file is already large.
