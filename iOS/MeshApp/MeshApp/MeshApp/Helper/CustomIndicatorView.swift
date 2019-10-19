/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Customer indicator view implementation.
 */

import UIKit

class CustomIndicatorView: UIView {
    let indicator = UIActivityIndicatorView()

    func showAnimating(parentVC: UIViewController, isTransparent: Bool = true) {
        showAnimating(parentView: parentVC.view, isTransparent: isTransparent)
    }

    func showAnimating(parentView: UIView, isTransparent: Bool = true) {
        guard indicator.isAnimating == false else {
            return
        }

        indicator.frame.size = CGSize(width: 40, height: 40)
        indicator.center = parentView.center
        indicator.hidesWhenStopped = true
        indicator.style = .whiteLarge
        indicator.color = UIColor.orangeBgColor
        if !isTransparent {
            self.backgroundColor = UIColor.black
            self.alpha = 0.6
        }
        self.frame = parentView.frame
        self.addSubview(indicator)
        parentView.addSubview(self)
        indicator.startAnimating()
    }

    func stopAnimating() {
        if indicator.isAnimating {
            indicator.stopAnimating()
            self.removeFromSuperview()
        }
    }
}
