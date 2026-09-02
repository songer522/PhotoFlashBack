# PhotoFlashBack

An iOS app that resurfaces the photos and videos you took on this day in previous years, grouped by year, straight from your on-device photo library.

Shipping on the App Store as **[Rewind: Memories on This Day](https://itunes.apple.com/us/app/rewind-all-your-photos-taken/id1137168287)**.

<p align="left">
  <img src="screenshots/Rediscover%20this%20day.png" width="240" alt="Memories grouped by year">
  <img src="screenshots/Rediscover%20this%20day-2.png" width="240" alt="Pick any day with the date picker">
  <img src="screenshots/Rediscover%20this%20day-3.png" width="240" alt="Full-screen viewer with share and delete">
</p>

## Features

- **On this day, every year** — fetches assets matching today's day and month across your whole library and groups them by year.
- **Any date** — a date picker lets you jump to any other day of the year.
- **Media filters** — show or hide Photos, Videos, and Screenshots independently; the choice persists between launches.
- **Two layouts** — a classic uniform grid and a mosaic compositional layout, toggled from the overflow menu.
- **Sort order** — newest-first or oldest-first.
- **Full-screen viewer** — paged browsing with a custom zoom transition, video playback, capture time, reverse-geocoded location names (cached to avoid repeat lookups), and share or delete straight from the viewer.
- **Home screen widget** — a WidgetKit extension that shows today's memories and refreshes at midnight, sharing data with the app through an App Group.
- **Background refresh** — a `BGTaskScheduler` job warms the day's memories so the app and widget open with content ready.
- **Tip jar** — an optional in-app tip via StoreKit, plus rate/feedback/share actions in Settings.

Everything runs locally against `PHPhotoLibrary`. The app has no backend and uploads nothing.

## Requirements

- Xcode 16 or newer
- iOS 17.6+ (the widget extension targets iOS 16.0+)
- Swift 5, UIKit for the app, SwiftUI for the widget
- iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`)

## Getting started

```sh
git clone https://github.com/songer522/PhotoFlashBack.git
cd PhotoFlashBack
open PhotoFlashBack.xcodeproj
```

Select the **PhotoFlashBack** scheme and run. Swift Package Manager resolves the dependencies on first build:

- [SwiftTipJar](https://github.com/dkasaj/SwiftTipJar) — in-app tip purchases
- [Player](https://github.com/piemonte/Player) — video playback in the viewer

To run on a device you'll need to set your own `DEVELOPMENT_TEAM` and bundle identifiers, and create the App Group used to share memories with the widget (`group.com.YangSong.PhotoFlashBack.Today`). In-app purchases can be exercised in the simulator with the bundled `Rewind: Memories on This Day.storekit` configuration.

The app asks for photo library access on first launch; without it there is nothing to show.

## Project layout

```
PhotoFlashBack/            App target (UIKit)
  PhotosViewController*    Grid screen, split across extensions for
                           collection view, toolbar, date picker, text field
  PhotoViewController*     Full-screen pager and video playback
  PhotosViewModel.swift    Fetching, year grouping, progress reporting
  PhotoManager.swift       PHAsset fetching and library access
  ImageLoadingManager      Thumbnail/full-size image requests
  LocationCache.swift      Reverse geocoding with caching
  MediaFilter.swift        Photo/video/screenshot filter + persistence
  CustomLayouts.swift      Classic and mosaic collection view layouts
  SkeletonView.swift       Loading placeholders
  IAPHelper.swift          Tip jar
TodayWidget/               WidgetKit extension
PhotoFlashBackTests/       Unit tests
screenshots/               App Store screenshots
```

## Tests

```sh
xcodebuild test \
  -project PhotoFlashBack.xcodeproj \
  -scheme PhotoFlashBack \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or press ⌘U in Xcode. Coverage currently focuses on the media filter logic and image-request gating.

## License

No license file is present; all rights reserved by the author.
