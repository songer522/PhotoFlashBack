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
        self.sourceViewFrame = sourceView.superview!.convert(sourceView.frame, to: nil)
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.2
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        
        if isPresenting {
            guard let toView = transitionContext.view(forKey: .to) else { return }
            
            let initialFrame = sourceViewFrame
            let finalFrame = containerView.bounds
            
            let snapshot = toView.snapshotView(afterScreenUpdates: true)
            snapshot?.frame = initialFrame
            snapshot?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(snapshot!)
            
            toView.alpha = 0.0
            containerView.addSubview(toView)
            
            let duration = transitionDuration(using: transitionContext)
            UIView.animate(withDuration: duration, animations: {
                snapshot?.frame = finalFrame
            }, completion: { _ in
                toView.alpha = 1.0
                snapshot?.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        } else {
            guard let fromView = transitionContext.view(forKey: .from) else { return }
            
            let initialFrame = containerView.bounds
            let finalFrame = sourceViewFrame
            
            let snapshot = fromView.snapshotView(afterScreenUpdates: false)
            snapshot?.frame = initialFrame
            snapshot?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(snapshot!)
            
            fromView.alpha = 0.0
            
            let duration = transitionDuration(using: transitionContext)
            UIView.animate(withDuration: duration, animations: {
                snapshot?.frame = finalFrame
            }, completion: { _ in
                snapshot?.removeFromSuperview()
                fromView.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        }
    }
}






