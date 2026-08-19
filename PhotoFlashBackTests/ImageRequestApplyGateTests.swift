import XCTest
import Photos
@testable import PhotoFlashBack

final class ImageRequestApplyGateTests: XCTestCase {
    func testRejectsWhenCellWasReusedForADifferentAsset() {
        XCTAssertFalse(
            ImageLoadingManager.shouldApplyResult(
                to: "cell-now-showing-B",
                requestedIdentifier: "asset-A",
                info: nil
            )
        )
    }

    func testAcceptsWhenCellStillRepresentsRequestedAsset() {
        XCTAssertTrue(
            ImageLoadingManager.shouldApplyResult(
                to: "asset-A",
                requestedIdentifier: "asset-A",
                info: nil
            )
        )
    }

    func testRejectsCancelledRequests() {
        XCTAssertFalse(
            ImageLoadingManager.shouldApplyResult(
                to: "asset-A",
                requestedIdentifier: "asset-A",
                info: [PHImageCancelledKey: true]
            )
        )
    }

    func testRejectsWhenCellIdentifierIsMissing() {
        XCTAssertFalse(
            ImageLoadingManager.shouldApplyResult(
                to: nil,
                requestedIdentifier: "asset-A",
                info: nil
            )
        )
    }
}
