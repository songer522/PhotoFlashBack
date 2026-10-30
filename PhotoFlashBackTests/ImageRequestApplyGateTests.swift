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

final class CustomTransitionAnimatorTests: XCTestCase {
    @MainActor
    func testPresentingSizesStoryboardViewToFullContainerBounds() {
        let duoBounds = CGRect(x: 0, y: 0, width: 703, height: 1000)
        let containerView = UIView(frame: duoBounds)
        let sourceSuperview = UIView(frame: duoBounds)
        let sourceView = UIView(frame: CGRect(x: 16, y: 120, width: 160, height: 160))
        sourceSuperview.addSubview(sourceView)

        let toVC = UIViewController()
        // Simulate Main.storyboard's retina6_12 canvas size (393x852)
        toVC.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)

        let context = StubTransitionContext(
            containerView: containerView,
            toViewController: toVC,
            finalFrame: duoBounds
        )

        let animator = CustomTransitionAnimator(sourceView: sourceView, isPresenting: true)
        animator.animateTransition(using: context)

        XCTAssertEqual(toVC.view.frame, duoBounds)
        XCTAssertTrue(toVC.view.superview === containerView)
        XCTAssertTrue(toVC.view.autoresizingMask.contains([.flexibleWidth, .flexibleHeight]))
    }
}

private final class StubTransitionContext: NSObject, UIViewControllerContextTransitioning {
    let containerView: UIView
    private let toVC: UIViewController
    private let targetFinalFrame: CGRect

    init(containerView: UIView, toViewController: UIViewController, finalFrame: CGRect) {
        self.containerView = containerView
        self.toVC = toViewController
        self.targetFinalFrame = finalFrame
    }

    var isAnimated: Bool { true }
    var isInteractive: Bool { false }
    var transitionWasCancelled: Bool { false }
    var presentationStyle: UIModalPresentationStyle { .fullScreen }
    var targetTransform: CGAffineTransform { .identity }

    func updateInteractiveTransition(_ percentComplete: CGFloat) {}
    func finishInteractiveTransition() {}
    func cancelInteractiveTransition() {}
    func pauseInteractiveTransition() {}
    func completeTransition(_ didComplete: Bool) {}

    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? {
        key == .to ? toVC : nil
    }

    func view(forKey key: UITransitionContextViewKey) -> UIView? {
        key == .to ? toVC.view : nil
    }

    func initialFrame(for vc: UIViewController) -> CGRect { .zero }

    func finalFrame(for vc: UIViewController) -> CGRect {
        vc === toVC ? targetFinalFrame : .zero
    }
}
