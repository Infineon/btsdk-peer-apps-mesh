/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Customer radio button implementation.
 */

import Foundation
import UIKit

@IBDesignable
class CustomRadioButton: UIButton {
    var outerCircleLineLayer = CAShapeLayer()
    var innerCircleFillLayer = CAShapeLayer()

    // Indicates the circles on left or right side. Default is on left size of the button.
    @IBInspectable public var isRightRadioButton: Bool = false {
        didSet {
            udpateTitleEdgeInsets()
            updateCircleLayouts()
        }
    }

    @IBInspectable public var outerCircleLineColor: UIColor = UIColor.darkGray {
        didSet {
            outerCircleLineLayer.strokeColor = outerCircleLineColor.cgColor
        }
    }

    @IBInspectable public var innerCircleFillColor: UIColor = UIColor.darkGray {
        didSet {
            updateButtonState()
        }
    }

    @IBInspectable public var outerCircleLineWidth: CGFloat = 2.0 {
        didSet {
            updateCircleLayouts()
        }
    }

    @IBInspectable public var innerOuterCircleGap: CGFloat = 2.0 {   // Gap between inner and outer circles.
        didSet {
            updateCircleLayouts()
        }
    }


    @IBInspectable var circleLineRadius: CGFloat {
        let width = bounds.width
        let height = bounds.height

        let maxDiamater = width > height ? height : width
        return (maxDiamater / 2 - outerCircleLineWidth)
    }

    @IBInspectable var circleLineFrame: CGRect {
        let width = bounds.width
        let height = bounds.height

        let radius = circleLineRadius
        let x: CGFloat
        let y: CGFloat

        if width > height {
            y = outerCircleLineWidth
            if isRightRadioButton {
                x = width - (radius + outerCircleLineWidth) * 2
            } else {
                x = outerCircleLineWidth
            }
        } else {
            x = outerCircleLineWidth
            y = height / 2 + radius + outerCircleLineWidth
        }

        let diameter = 2 * radius
        return CGRect(x: x, y: y, width: diameter, height: diameter)
    }

    private var outCircleLinePath: UIBezierPath {
        return UIBezierPath(roundedRect: circleLineFrame, cornerRadius: circleLineRadius)
    }

    private var innerCircleFillPath: UIBezierPath {
        let trueGap = innerOuterCircleGap + outerCircleLineWidth
        return UIBezierPath(roundedRect: circleLineFrame.insetBy(dx: trueGap, dy: trueGap), cornerRadius: circleLineRadius)

    }

    private func initialize() {
        outerCircleLineLayer.frame = bounds
        outerCircleLineLayer.lineWidth = outerCircleLineWidth
        outerCircleLineLayer.fillColor = UIColor.clear.cgColor
        outerCircleLineLayer.strokeColor = outerCircleLineColor.cgColor
        layer.addSublayer(outerCircleLineLayer)

        innerCircleFillLayer.frame = bounds
        innerCircleFillLayer.lineWidth = outerCircleLineWidth
        innerCircleFillLayer.fillColor = UIColor.clear.cgColor
        innerCircleFillLayer.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(innerCircleFillLayer)

        udpateTitleEdgeInsets()
        updateButtonState()
    }

    private func udpateTitleEdgeInsets() {
        // Adjust button title left/right edge insets to avoid the circle to be overwritten by the text.
        if isRightRadioButton {
            self.titleEdgeInsets.left = 0
            self.titleEdgeInsets.right = (outerCircleLineWidth + circleLineRadius + 20)
        } else {
            self.titleEdgeInsets.left = (outerCircleLineWidth + circleLineRadius + 20)
            self.titleEdgeInsets.right = 0
        }
    }

    private func updateCircleLayouts() {
        outerCircleLineLayer.frame = bounds
        outerCircleLineLayer.lineWidth = outerCircleLineWidth
        outerCircleLineLayer.path = outCircleLinePath.cgPath

        innerCircleFillLayer.frame = bounds
        innerCircleFillLayer.lineWidth = outerCircleLineWidth
        innerCircleFillLayer.path = innerCircleFillPath.cgPath
    }

    private func updateButtonState() {
        if self.isSelected {
            innerCircleFillLayer.fillColor = outerCircleLineColor.cgColor
        } else {
            innerCircleFillLayer.fillColor = UIColor.clear.cgColor
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        updateCircleLayouts()
    }

    override public var isSelected: Bool {
        didSet {
            updateButtonState()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    override func prepareForInterfaceBuilder() {
        initialize()
    }
}
