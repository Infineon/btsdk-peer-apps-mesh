/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Customer Popover choise table view cell implementation.
 */

import UIKit

class PopoverTableViewCell: UITableViewCell {
    @IBOutlet weak var radioButtonBackgroundView: UIView!
    @IBOutlet weak var radioButton: CustomRadioButton!

    static let lock = NSLock()
    static var selectedRadioButton: CustomRadioButton?
    static var selectedItem: String?

    private var mItem: String = ""
    var item: String {
        get { return mItem }
        set(value) {
            mItem = value
            radioButton.setTitle(mItem, for: .normal)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        radioButton.setTitle(item, for: .normal)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onRadioButtonClick(_ sender: CustomRadioButton) {
        PopoverTableViewCell.lock.lock()
        if let selectedRadioButton = PopoverTableViewCell.selectedRadioButton {
            if sender == selectedRadioButton {
                PopoverTableViewCell.selectedRadioButton = nil
                sender.isSelected = !sender.isSelected
            } else {
                selectedRadioButton.isSelected = !selectedRadioButton.isSelected
                sender.isSelected = !sender.isSelected
                PopoverTableViewCell.selectedRadioButton = sender
            }
        } else {
            sender.isSelected = !sender.isSelected
            PopoverTableViewCell.selectedRadioButton = sender
        }
        PopoverTableViewCell.selectedItem = item
        PopoverTableViewCell.lock.unlock()
    }
}
