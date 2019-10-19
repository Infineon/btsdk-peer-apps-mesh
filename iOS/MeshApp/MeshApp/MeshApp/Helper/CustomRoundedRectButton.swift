/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Customer rounded rect button implementation with additional features.
 */

import UIKit

@IBDesignable
class CustomRoundedRectButton: UIButton {
    @IBInspectable var isRoundedRectButton: Bool = false

    @IBInspectable var borderWidth: CGFloat = 0.0 {
        didSet {
            self.layer.borderWidth = borderWidth
            self.layer.borderColor = UIColor.orangeBgColor.cgColor
        }
    }

    @IBInspectable var cornerRadius: CGFloat = 0.0 {
        didSet {
            setupView()
        }
    }

    @IBInspectable var shadowOffsetWidth: Int = 2
    @IBInspectable var shadowOffsetHeight: Int = 3
    @IBInspectable var shadowColor: UIColor? = UIColor.black
    @IBInspectable var shadowOpacity: Float = 0.5

    @IBInspectable var normalBackgroundColor: UIColor? = UIColor.orangeBgColor {
        didSet {
            self.backgroundColor = normalBackgroundColor
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setupView()
    }

    func setupView() {
        let shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.cornerRadius)
        self.layer.masksToBounds = false
        self.layer.shadowColor = shadowColor?.cgColor
        self.layer.shadowOffset = CGSize(width: shadowOffsetWidth, height: shadowOffsetHeight);
        self.layer.shadowOpacity = shadowOpacity
        self.layer.shadowPath = shadowPath.cgPath

        if isRoundedRectButton {
            self.layer.cornerRadius = self.bounds.height/2;
            self.clipsToBounds = true
        }
        else{
            self.layer.cornerRadius = self.cornerRadius;
            self.clipsToBounds = true
        }
    }
}
