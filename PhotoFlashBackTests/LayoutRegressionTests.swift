import XCTest
import UIKit
@testable import PhotoFlashBack

/// Guards the grid layouts and the empty-state button against visual changes while
/// replacing deprecated UIKit APIs (issue #12). Expected frame signatures were captured from
/// the pre-change implementation (`subitem:count:` / `contentEdgeInsets`).
final class LayoutRegressionTests: XCTestCase {

    // MARK: - Collection view layouts

    private static let iPhonePortrait = CGSize(width: 440, height: 956)
    private static let iPhoneLandscape = CGSize(width: 956, height: 440)
    private static let iPadPortrait = CGSize(width: 1032, height: 1376)
    private static let iPadLandscape = CGSize(width: 1376, height: 1032)

    private final class CountDataSource: NSObject, UICollectionViewDataSource {
        let count: Int
        init(count: Int) { self.count = count }
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { count }
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        }
        func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                            at indexPath: IndexPath) -> UICollectionReusableView {
            collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
        }
    }

    /// Lays out `itemCount` items with `section` in a collection view of `size` and returns the
    /// item frames as a compact "x,y,w,h;..." string (values rounded to 0.1 pt).
    private func frameSignature(size: CGSize, itemCount: Int,
                                section: @escaping () -> NSCollectionLayoutSection) -> String {
        let layout = UICollectionViewCompositionalLayout { _, _ in section() }
        let collectionView = UICollectionView(frame: CGRect(origin: .zero, size: size), collectionViewLayout: layout)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.register(UICollectionReusableView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "header")
        let dataSource = CountDataSource(count: itemCount)
        collectionView.dataSource = dataSource
        collectionView.layoutIfNeeded()

        func fmt(_ value: CGFloat) -> String { String(format: "%.1f", Double(value)) }
        return (0..<itemCount).map { item -> String in
            guard let frame = layout.layoutAttributesForItem(at: IndexPath(item: item, section: 0))?.frame else {
                return "nil"
            }
            return [frame.minX, frame.minY, frame.width, frame.height].map(fmt).joined(separator: ",")
        }.joined(separator: ";")
    }

    func testMosaicPortraitFramesUnchanged() {
        for (size, expected) in [(Self.iPhonePortrait, Self.mosaicPortraitIPhone),
                                 (Self.iPadPortrait, Self.mosaicPortraitIPad)] {
            let actual = frameSignature(size: size, itemCount: 14) { CustomLayouts.layoutAPotrait(size: size) }
            XCTAssertEqual(actual, expected, "mosaic portrait \(size)")
        }
    }

    func testMosaicLandscapeFramesUnchanged() {
        for (size, expected) in [(Self.iPhoneLandscape, Self.mosaicLandscapeIPhone),
                                 (Self.iPadLandscape, Self.mosaicLandscapeIPad)] {
            let actual = frameSignature(size: size, itemCount: 24) { CustomLayouts.layoutALandscape(size: size) }
            XCTAssertEqual(actual, expected, "mosaic landscape \(size)")
        }
    }

    func testClassicFramesUnchanged() {
        // Mirrors PhotosViewController.createLayout: 0.25 in portrait, 0.20 in landscape.
        let cases: [(CGSize, CGFloat, String)] = [
            (Self.iPhonePortrait, 0.25, Self.classicPortraitIPhone),
            (Self.iPhoneLandscape, 0.20, Self.classicLandscapeIPhone),
            (Self.iPadPortrait, 0.25, Self.classicPortraitIPad),
            (Self.iPadLandscape, 0.20, Self.classicLandscapeIPad),
        ]
        for (size, fraction, expected) in cases {
            let actual = frameSignature(size: size, itemCount: 10) { CustomLayouts.layoutB(itemSizeFraction: fraction) }
            XCTAssertEqual(actual, expected, "classic \(size) fraction \(fraction)")
        }
    }

    func testOldLayoutFramesUnchanged() {
        for (size, isLandscape, expected) in [(Self.iPhonePortrait, false, Self.oldLayoutPortraitIPhone),
                                              (Self.iPhoneLandscape, true, Self.oldLayoutLandscapeIPhone)] {
            let actual = frameSignature(size: size, itemCount: 10) {
                CustomLayouts.oldLayout(isLandscape: isLandscape, size: size)
            }
            XCTAssertEqual(actual, expected, "oldLayout \(size)")
        }
    }

    // MARK: - Empty state action button

    private func actionButton(in view: UIView) -> UIButton? {
        for subview in view.subviews {
            if let button = subview as? UIButton { return button }
            if let found = actionButton(in: subview) { return found }
        }
        return nil
    }

    func testEmptyStateButtonUsesConfigurationInsets() throws {
        let view = EmptyStateView(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        view.configure(for: .noPermission)
        let button = try XCTUnwrap(actionButton(in: view))

        let configuration = try XCTUnwrap(button.configuration, "action button should use UIButton.Configuration")
        XCTAssertEqual(configuration.contentInsets,
                       NSDirectionalEdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 28))
    }

    func testEmptyStateButtonSizeUnchanged() throws {
        let view = EmptyStateView(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        for (type, expected) in [(EmptyStateView.EmptyStateType.noPermission, Self.buttonSizeGoToSettings),
                                 (.error("x"), Self.buttonSizeRetry)] {
            view.configure(for: type)
            view.layoutIfNeeded()
            let button = try XCTUnwrap(actionButton(in: view))
            let size = button.intrinsicContentSize
            // 1 pt tolerance: the legacy title label rounded its text width up to whole points,
            // UIButton.Configuration keeps the pixel-aligned width (e.g. 156.33 vs 157).
            XCTAssertEqual(size.width, expected.width, accuracy: 1.0, "\(type) width")
            XCTAssertEqual(size.height, expected.height, accuracy: 0.5, "\(type) height")
        }
    }

    // MARK: - Expected values (captured from origin/main before the API migration)

    private static let mosaicPortraitIPhone = [
        "1.0,51.0,438.0,438.0;1.0,491.0,291.3,291.3;294.3,491.0,144.7,144.7;294.3,637.7,144.7,144.7;",
        "1.0,784.3,144.7,144.7;147.7,784.3,144.7,144.7;294.3,784.3,144.7,144.7;1.0,931.0,438.0,438.0;",
        "1.0,1371.0,144.7,144.7;1.0,1517.7,144.7,144.7;147.7,1371.0,291.3,291.3;1.0,1664.3,144.7,144.7;",
        "147.7,1664.3,144.7,144.7;294.3,1664.3,144.7,144.7",
    ].joined()
    private static let mosaicPortraitIPad = [
        "1.0,51.0,1030.0,1030.0;1.0,1083.0,686.0,686.0;689.0,1083.0,342.0,342.0;689.0,1427.0,342.0,342.0;",
        "1.0,1771.0,342.0,342.0;345.0,1771.0,342.0,342.0;689.0,1771.0,342.0,342.0;1.0,2115.0,1030.0,1030.0;",
        "1.0,3147.0,342.0,342.0;1.0,3491.0,342.0,342.0;345.0,3147.0,686.0,686.0;1.0,3835.0,342.0,342.0;",
        "345.0,3835.0,342.0,342.0;689.0,3835.0,342.0,342.0",
    ].joined()
    private static let mosaicLandscapeIPhone = [
        "1.0,51.0,635.0,438.0;638.0,51.0,316.3,218.0;638.0,271.0,316.3,218.0;1.0,491.0,316.3,438.0;",
        "319.3,491.0,316.3,438.0;637.7,491.0,316.3,438.0;1.0,931.0,157.0,144.7;160.0,931.0,157.0,144.7;",
        "319.0,931.0,157.0,144.7;478.0,931.0,157.0,144.7;637.0,931.0,157.0,144.7;796.0,931.0,157.0,144.7;",
        "1.0,1077.7,316.3,218.0;1.0,1297.7,316.3,218.0;319.3,1077.7,635.0,438.0;1.0,1517.7,316.3,438.0;",
        "319.3,1517.7,316.3,438.0;637.7,1517.7,316.3,438.0;1.0,1957.7,157.0,144.7;160.0,1957.7,157.0,144.7;",
        "319.0,1957.7,157.0,144.7;478.0,1957.7,157.0,144.7;637.0,1957.7,157.0,144.7;796.0,1957.7,157.0,144.7",
    ].joined()
    private static let mosaicLandscapeIPad = [
        "1.0,51.0,915.3,1030.0;918.3,51.0,456.7,514.0;918.3,567.0,456.7,514.0;1.0,1083.0,456.7,1030.0;",
        "459.7,1083.0,456.7,1030.0;918.3,1083.0,456.7,1030.0;1.0,2115.0,227.3,342.0;230.3,2115.0,227.3,342.0;",
        "459.7,2115.0,227.3,342.0;689.0,2115.0,227.3,342.0;918.3,2115.0,227.3,342.0;1147.7,2115.0,227.3,342.0;",
        "1.0,2459.0,456.7,514.0;1.0,2975.0,456.7,514.0;459.7,2459.0,915.3,1030.0;1.0,3491.0,456.7,1030.0;",
        "459.7,3491.0,456.7,1030.0;918.3,3491.0,456.7,1030.0;1.0,4523.0,227.3,342.0;230.3,4523.0,227.3,342.0;",
        "459.7,4523.0,227.3,342.0;689.0,4523.0,227.3,342.0;918.3,4523.0,227.3,342.0;1147.7,4523.0,227.3,342.0",
    ].joined()
    private static let classicPortraitIPhone = [
        "1.0,51.0,108.7,108.7;110.7,51.0,108.7,108.7;220.3,51.0,108.7,108.7;330.0,51.0,108.7,108.7;",
        "1.0,161.3,108.7,108.7;110.7,161.3,108.7,108.7;220.3,161.3,108.7,108.7;330.0,161.3,108.7,108.7;",
        "1.0,271.7,108.7,108.7;110.7,271.7,108.7,108.7",
    ].joined()
    private static let classicLandscapeIPhone = [
        "1.0,51.0,190.0,190.0;192.0,51.0,190.0,190.0;383.0,51.0,190.0,190.0;574.0,51.0,190.0,190.0;",
        "765.0,51.0,190.0,190.0;1.0,242.7,190.0,190.0;192.0,242.7,190.0,190.0;383.0,242.7,190.0,190.0;",
        "574.0,242.7,190.0,190.0;765.0,242.7,190.0,190.0",
    ].joined()
    private static let classicPortraitIPad = [
        "1.0,51.0,256.7,256.7;258.7,51.0,256.7,256.7;516.3,51.0,256.7,256.7;774.0,51.0,256.7,256.7;",
        "1.0,309.3,256.7,256.7;258.7,309.3,256.7,256.7;516.3,309.3,256.7,256.7;774.0,309.3,256.7,256.7;",
        "1.0,567.7,256.7,256.7;258.7,567.7,256.7,256.7",
    ].joined()
    private static let classicLandscapeIPad = [
        "1.0,51.0,274.0,274.0;276.0,51.0,274.0,274.0;551.0,51.0,274.0,274.0;826.0,51.0,274.0,274.0;",
        "1101.0,51.0,274.0,274.0;1.0,326.7,274.0,274.0;276.0,326.7,274.0,274.0;551.0,326.7,274.0,274.0;",
        "826.0,326.7,274.0,274.0;1101.0,326.7,274.0,274.0",
    ].joined()
    private static let oldLayoutPortraitIPhone = [
        "1.0,51.0,218.0,303.7;221.0,51.0,108.0,150.7;221.0,203.7,108.0,150.7;331.0,51.0,108.0,150.7;",
        "331.0,203.7,108.0,150.7;1.0,356.7,108.0,150.7;1.0,509.3,108.0,150.7;111.0,356.7,108.0,150.7;",
        "111.0,509.3,108.0,150.7;221.0,356.7,218.0,303.7",
    ].joined()
    private static let oldLayoutLandscapeIPhone = [
        "1.0,51.0,476.0,389.0;479.0,51.0,237.0,193.3;479.0,246.3,237.0,193.3;718.0,51.0,237.0,193.3;",
        "718.0,246.3,237.0,193.3;1.0,442.0,237.0,193.3;1.0,637.3,237.0,193.3;240.0,442.0,237.0,193.3;",
        "240.0,637.3,237.0,193.3;479.0,442.0,476.0,389.0",
    ].joined()
    private static let buttonSizeGoToSettings = CGSize(width: 157, height: 42)
    private static let buttonSizeRetry = CGSize(width: 94, height: 42)
}
