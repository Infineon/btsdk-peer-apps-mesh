/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Customer Drop Down button implementation.
 */

import UIKit

/*
 * When use this CustomDropDownButton in the storyboard, should
 *   1) set the button type to Custom.
 *   2) set the text color to what required.
 */
class CustomDropDownButton: UIButton {
    @IBInspectable public var isRightTriangle: Bool = true {
        didSet {
            udpateTitleEdgeInsets()
        }
    }

    public var dropDownItems: [String] = [] {
        didSet {
            initializeDefaultSelection()
            initializePopoverController()
        }
    }

    private var mSelectIndex: Int = 0
    private var mSelectedString: String = ""
    public var selectedString: String {
        return mSelectedString
    }
    public var selectedIndex: Int {
        return mSelectIndex
    }
    public func setSelection(select: Int) {
        guard select < dropDownItems.count else { return }
        updateSelection(at: select, with: dropDownItems[select])
    }
    public func setSelection(select: String) {
        for (index, value) in dropDownItems.enumerated() {
            if value == select {
                updateSelection(at: index, with: value)
                return
            }
        }
    }

    private func updateSelection(at index: Int, with value: String) {
        self.mSelectedString = value
        self.mSelectIndex = index
        self.setTitle(value, for: .normal)
        self.setTitle(value, for: .selected)
    }

    private func initializeDefaultSelection() {
        if dropDownItems.isEmpty || dropDownItems[0].isEmpty {
            updateSelection(at: 0, with: "")
        } else {
            updateSelection(at: 0, with: dropDownItems[0])
        }
    }

    private func updateTitleColor() {
        self.setTitleColor(self.titleColor(for: .normal), for: .selected)
        self.titleLabel?.backgroundColor = nil
    }

    private func udpateTitleEdgeInsets() {
        guard let imageView = self.imageView else { return }
        let pedding: CGFloat = 2
        if isRightTriangle {
            self.titleEdgeInsets.left = 0 - imageView.bounds.width + pedding
            self.titleEdgeInsets.right = 0 - imageView.bounds.width - pedding
        } else {
            self.titleEdgeInsets.right = pedding
        }
    }

    private var popoverViewController: PopoverChoiceTableViewController<String>?
    private func initialize() {
        if isRightTriangle {
            self.setImage(UIImage(named: MeshAppImageNames.leftTriangleImage), for: .normal)
        } else {
            self.setImage(UIImage(named: MeshAppImageNames.rightTriangleImage), for: .normal)
        }
        self.setImage(UIImage(named: MeshAppImageNames.downTriangleImage), for: .selected)
        self.isSelected = false
        udpateTitleEdgeInsets()
        updateTitleColor()
        initializeDefaultSelection()

        self.addTarget(self, action: #selector(onTouchUpInside), for: .touchUpInside)

        initializePopoverController()
    }

    private func initializePopoverController() {
        popoverViewController = PopoverChoiceTableViewController(choices: dropDownItems) { (index: Int, selection: String) in
            self.updateSelection(at: index, with: selection)
            self.isSelected = false
        }
    }

    public func showDropList(width: Int, parent: UIViewController, sourceView: UIView? = nil, selectCompletion: (() -> Void)? = nil) {
        guard let controller = popoverViewController else { return }
        controller.preferredContentSize = CGSize(width: width, height: controller.getPreferredPopoverViewSize())
        controller.showPopoverPresentation(parent: parent, sourceView: self) { () -> Void in
            self.isSelected = false
            selectCompletion?()
        }
    }

    @objc func onTouchUpInside() {
        self.isSelected = !self.isSelected
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

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let imageView = self.imageView, let titleLabel = self.titleLabel else {
            return
        }

        self.contentHorizontalAlignment = .left
        self.contentVerticalAlignment = .center

        if isRightTriangle {
            imageView.center.x = self.bounds.width - imageView.bounds.width / 2
            let newTitleLabelBounds = CGRect(x: 0,
                                             y: titleLabel.frame.origin.y,
                                             width: self.bounds.width - imageView.bounds.width - 2,
                                             height: titleLabel.frame.height)
            self.titleLabel?.frame = newTitleLabelBounds
            self.titleLabel?.textRect(forBounds: newTitleLabelBounds, limitedToNumberOfLines: 1)
        }
    }
}
