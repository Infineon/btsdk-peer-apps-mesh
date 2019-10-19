/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Custom show select network popover table view cell implementation.
 */

import UIKit

class SelectNetworkPopoverTableViewCell: UITableViewCell {
    static let lock = NSLock()
    static var selectedCell: CustomRadioButton?

    @IBOutlet weak var radioButton: CustomRadioButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onRadioButtonClick(_ sender: CustomRadioButton) {
        SelectNetworkPopoverTableViewCell.lock.lock()
        if let selectedCell = SelectNetworkPopoverTableViewCell.selectedCell {
            if sender == selectedCell {
                SelectNetworkPopoverTableViewCell.selectedCell = nil
                sender.isSelected = !sender.isSelected
            } else {
                SelectNetworkPopoverTableViewCell.selectedCell = sender
                selectedCell.isSelected = !selectedCell.isSelected
                sender.isSelected = !sender.isSelected
            }
        } else {
            SelectNetworkPopoverTableViewCell.selectedCell = sender
            sender.isSelected = !sender.isSelected
        }
        SelectNetworkPopoverTableViewCell.lock.unlock()
    }
}
