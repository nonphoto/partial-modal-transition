//
//  PartialModalTransition.swift
//  Mindburner
//
//  Created by Jonas Luebbers on 6/30/16.
//  Copyright © 2016 Mindburner. All rights reserved.
//

import UIKit

/**
 The `PartialModalTransition` class manages a custom view controller transition by modally presenting a view controller (known as the "presented" view controller) such that the top of the view controller that initiated the presentation (the "presenting" view controller) is still visible. The dismissal of the presented view controller is interactive. This presentation is visually similar to the presentation of a new message in Apple's default Mail application.
 
 You need not instantiate any other `PartialModal` classes to create such a transition, this class will manage them for you. Example code for initiating such a transition is as follows:

 ```
 let presentedViewController = SomeViewController()
 self.transition = PartialModalTransition()
 presentedViewController.transitioningDelegate = self.transition
 presentedViewController.modalPresentationStyle = UIModalPresentationStyle.Custom
 presentViewController(presentedController, animated: true, completion: nil)
 ```
 
 Be sure to keep a reference to the transitioning delegate in the presenting view controller so that it is not inadvertently garbage-collected.
 */
class PartialModalTransition: NSObject, UIViewControllerTransitioningDelegate, PartialModalPresentationControllerDelegate {

    private var interactionController: PartialModalInteractionController?

    func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PartialModalPresentationAnimationController()
    }

    func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PartialModalDismissalAnimationController()
    }

    func interactionControllerForPresentation(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return nil
    }

    func interactionControllerForDismissal(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionController
    }

    func presentationControllerForPresentedViewController(presented: UIViewController, presentingViewController presenting: UIViewController, sourceViewController source: UIViewController) -> UIPresentationController? {
        let presentationController = PartialModalPresentationController(presentedViewController: presented, presentingViewController: presenting)
        presentationController.transitioningDelegate = self
        return presentationController
    }

    func enableInteraction(enabled: Bool) -> PartialModalInteractionController? {
        if enabled {
            interactionController = PartialModalInteractionController()
            return interactionController
        }
        else {
            interactionController = nil
            return nil
        }
    }
}



/**
 The `PartialModalPresentationAnimationController` controls the animation of a custom transition when presenting a view controller.
 
 You do not need to instantiate this class to initiate such a transition. See `PartialModalTransition` instead.
 */
class PartialModalPresentationAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        let presentingViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!
        let presentedViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!

        let containerView = transitionContext.containerView()!

        let offScreenFrame = CGRectMake(0, containerView.bounds.height, containerView.bounds.width, containerView.bounds.height)

        containerView.addSubview(presentedViewController.view)
        presentedViewController.view.frame = offScreenFrame

        UIView.animateWithDuration(
            transitionDuration(transitionContext),
            delay: 0,
            usingSpringWithDamping: Constants.TransitionConstants.SPRING_DAMPING,
            initialSpringVelocity: Constants.TransitionConstants.SPRING_VELOCITY,
            options:UIViewAnimationOptions.CurveEaseOut,
            animations: {
                let scale = Constants.TransitionConstants.PRESENTING_VIEW_SCALE
                presentingViewController.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale)
                presentingViewController.view.alpha = Constants.TransitionConstants.PRESENTING_VIEW_ALPHA

                presentedViewController.view.frame = transitionContext.finalFrameForViewController(presentedViewController)
            },
            completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
            }
        )
    }

    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return Constants.TransitionConstants.PRESENTATION_DURATION
    }
}



/**
 The `PartialModalDismissalAnimationController` controls the animation of a custom transition when dismissing a view controller.

 You do not need to instantiate this class to initiate such a transition. See `PartialModalTransition` instead.
 */
class PartialModalDismissalAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        let presentingViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        let presentedViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!

        let containerView = transitionContext.containerView()!

        let offScreenFrame = CGRectMake(0, containerView.bounds.height, containerView.bounds.width, containerView.bounds.height)

        UIView.animateWithDuration(
            transitionDuration(transitionContext),
            delay: 0,
            options: .CurveEaseOut,
            animations: {
                presentingViewController.view.alpha = 1
                presentingViewController.view.transform = CGAffineTransformIdentity

                presentedViewController.view.frame = offScreenFrame
            },
            completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
            }
        )
    }

    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return Constants.TransitionConstants.DISMISSAL_DURATION
    }
}



/**
 The delegate of a `PartialModalPresentationController` must adopt this protocol. The transitioning delegate for the partial modal transition uses this protocol to enable and disable interactive dismissal.
 */
protocol PartialModalPresentationControllerDelegate {

    /**
     Enable or disable interaction for the partial modal transition.
     
     The `PartialModalPresentationController` calls this method before initiating an interactive transition, and after cancelling one.
     
     - parameter enabled: Whether the delegate should enable interaction.
     
     - returns: A `PartialModalInteractionController` if the delegate successfully enables interaction. Otherwise, the delegate should return `nil`.
     */
    func enableInteraction(enabled: Bool) -> PartialModalInteractionController?

}

/**
 The `PartialModalPresentationController` class provides view and transition management during partial modal presentation and dismissal.
 
 You do not need to instantiate this class to initiate such a transition. See `PartialModalTransition` instead. This class determines the size of the presented view controller in the transition's container view, as well as the frames of the presenting and presented views when the trait collection of the container view changes (such as when the device changes orientation). It also handles gesture recognition for the presented view controller, starting an interactive dismissal transition when the user swipes downward on the presented view controller.
 */
class PartialModalPresentationController: UIPresentationController, UIAdaptivePresentationControllerDelegate {

    var transitioningDelegate: PartialModalPresentationControllerDelegate?
    var interactionController: PartialModalInteractionController?

    override func frameOfPresentedViewInContainerView() -> CGRect {
        if let view = containerView {
            if view.traitCollection.verticalSizeClass == .Compact {
                let offset = Constants.TransitionConstants.PRESENTED_VIEW_COMPACT_OFFSET
                return CGRectMake(0, offset, view.bounds.width, view.bounds.height - offset)
            }
            else {
                let offset = Constants.TransitionConstants.PRESENTED_VIEW_OFFSET
                return CGRectMake(0, offset, view.bounds.width, view.bounds.height - offset)
            }
        }
        else {
            return CGRectZero
        }
    }

    override func presentationTransitionDidEnd(completed: Bool) {
        if completed {
            let scale = Constants.TransitionConstants.PRESENTING_VIEW_SCALE
            presentingViewController.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale)
            presentingViewController.view.alpha = Constants.TransitionConstants.PRESENTING_VIEW_ALPHA

            presentedViewController.view.frame = frameOfPresentedViewInContainerView()
            let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_: )))
            gestureRecognizer.maximumNumberOfTouches = 1
            presentedViewController.view.addGestureRecognizer(gestureRecognizer)
        }
    }

    override func dismissalTransitionDidEnd(completed: Bool) {
        if completed {
            presentingViewController.view.alpha = 1
            presentingViewController.view.transform = CGAffineTransformIdentity
        }
    }

    override func willTransitionToTraitCollection(newCollection: UITraitCollection, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransitionToTraitCollection(newCollection, withTransitionCoordinator: coordinator)

        self.presentingViewController.view.transform = CGAffineTransformIdentity
        coordinator.animateAlongsideTransition(
            { context in
                self.presentedViewController.view.frame = self.frameOfPresentedViewInContainerView()

                let scale = Constants.TransitionConstants.PRESENTING_VIEW_SCALE
                self.presentingViewController.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale)
            },
            completion: nil
        )
    }

    func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .Began:
            gestureRecognizer.setTranslation(CGPointMake(0, 0), inView: containerView)
            interactionController = transitioningDelegate?.enableInteraction(true)
            presentedViewController.dismissViewControllerAnimated(true, completion: nil)
        case .Changed:
            if let view = presentedView() {
                let translation = gestureRecognizer.translationInView(view)
                let percentage = translation.y / CGRectGetHeight(view.bounds);
                interactionController?.updateInteractiveTransition(percentage)
            }
        case .Ended:
            if interactionController?.percentComplete < Constants.TransitionConstants.DISMISSAL_THRESHOLD {
                interactionController?.cancelInteractiveTransition()
            }
            else {
                interactionController?.finishInteractiveTransition()
            }
            transitioningDelegate?.enableInteraction(false)
        default:
            interactionController?.cancelInteractiveTransition()
            transitioningDelegate?.enableInteraction(false)
        }
    }
}



/**
 The `PartialModalInteractionController` manages the transitioning view controllers during an interactive dismissal transition.
 
 You do not need to instantiate this class to initiate such a transition. See `PartialModalTransition` instead. This class manipulates frames and transforms of the transitioning view controllers according to a `CGFloat` percent value representing the progress toward animation completion. Unlike `PercentDrivenInteractiveTransition` the completion percentage can be negative. This class also animates the view controllers back to their presented state when the transition is cancelled, and to their dismissed state when the transition finishes.
 */
class PartialModalInteractionController: UIPercentDrivenInteractiveTransition {

    var transitionContext: UIViewControllerContextTransitioning!

    override func startInteractiveTransition(transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext
    }

    override func updateInteractiveTransition(percentComplete: CGFloat) {
        super.updateInteractiveTransition(percentComplete)

        let presentingViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        let presentedViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!

        let targetScale = Constants.TransitionConstants.PRESENTING_VIEW_SCALE
        let scale = targetScale + (1 - targetScale) * percentComplete
        presentingViewController.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale)

        let targetAlpha = Constants.TransitionConstants.PRESENTING_VIEW_ALPHA
        let alpha = targetAlpha + (1 - targetAlpha) * percentComplete
        presentingViewController.view.alpha = alpha

        let offset = presentedViewController.view.bounds.height * percentComplete
        presentedViewController.view.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, offset)
    }

    override func finishInteractiveTransition() {
        super.finishInteractiveTransition()

        let presentingViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        let presentedViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!

        let containerView = transitionContext.containerView()!
        let offScreenFrame = CGRectMake(0, containerView.bounds.height, containerView.bounds.width, containerView.bounds.height)

        UIView.animateWithDuration(
            Constants.TransitionConstants.DISMISSAL_DURATION,
            delay: 0,
            options: .CurveEaseOut,
            animations: {
                presentingViewController.view.transform = CGAffineTransformIdentity
                presentingViewController.view.alpha = 1

                presentedViewController.view.frame = offScreenFrame
            },
            completion: { _ in
                self.transitionContext.completeTransition(!self.transitionContext.transitionWasCancelled())
            }
        )
    }

    override func cancelInteractiveTransition() {
        super.cancelInteractiveTransition()

        let presentingViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        let presentedViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!

        UIView.animateWithDuration(
            Constants.TransitionConstants.DISMISSAL_DURATION,
            delay: 0,
            options: .CurveEaseOut,
            animations: {
                let scale = Constants.TransitionConstants.PRESENTING_VIEW_SCALE
                presentingViewController.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale)
                presentingViewController.view.alpha = Constants.TransitionConstants.PRESENTING_VIEW_ALPHA

                presentedViewController.view.transform = CGAffineTransformIdentity
            },
            completion: { _ in
                self.transitionContext.completeTransition(false)
            }
        )
    }
}