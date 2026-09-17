//
//  CustomTransitionAnimator.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 3/24/23.
//

import UIKit

class CustomTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    private let sourceView: UIView
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomTransitionAnimator(sourceView: sourceView, isPresenting: true)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomTransitionAnimator(sourceView: sourceView, isPresenting: false)
    }
}

class CustomTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    private let sourceView: UIView
    private let sourceViewFrame: CGRect
    private let isPresenting: Bool
    
    init(sourceView: UIView, isPresenting: Bool) {
        self.sourceView = sourceView
        self.isPresenting = isPresenting
        if let superview = sourceView.superview {
            self.sourceViewFrame = superview.convert(sourceView.frame, to: nil)
        } else {
            // No superview to convert through (e.g. the source view was removed from the
            // hierarchy) — fall back to the view's own frame rather than crashing.
            self.sourceViewFrame = sourceView.frame
        }
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.2
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        
        if isPresenting {
            guard let toView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }

            let initialFrame = sourceViewFrame
            let finalFrame = containerView.bounds

            guard let snapshot = toView.snapshotView(afterScreenUpdates: true) else {
                // toView hasn't rendered yet — fall back to a non-animated presentation
                // rather than crashing on a nil snapshot.
                toView.alpha = 1.0
                containerView.addSubview(toView)
                transitionContext.completeTransition(true)
                return
            }
            snapshot.frame = initialFrame
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(snapshot)

            toView.alpha = 0.0
            containerView.addSubview(toView)

            let duration = transitionDuration(using: transitionContext)
            UIView.animate(withDuration: duration, animations: {
                snapshot.frame = finalFrame
            }, completion: { _ in
                toView.alpha = 1.0
                snapshot.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        } else {
            guard let fromView = transitionContext.view(forKey: .from) else {
                transitionContext.completeTransition(false)
                return
            }

            let initialFrame = containerView.bounds
            let finalFrame = sourceViewFrame

            guard let snapshot = fromView.snapshotView(afterScreenUpdates: false) else {
                // fromView hasn't rendered — fall back to a non-animated dismissal rather
                // than crashing on a nil snapshot.
                fromView.removeFromSuperview()
                transitionContext.completeTransition(true)
                return
            }
            snapshot.frame = initialFrame
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(snapshot)

            fromView.alpha = 0.0

            let duration = transitionDuration(using: transitionContext)
            UIView.animate(withDuration: duration, animations: {
                snapshot.frame = finalFrame
            }, completion: { _ in
                snapshot.removeFromSuperview()
                fromView.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        }
    }
}






