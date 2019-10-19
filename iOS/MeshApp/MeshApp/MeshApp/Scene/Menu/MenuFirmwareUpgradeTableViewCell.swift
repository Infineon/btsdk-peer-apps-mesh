/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Firmware Upgrade table cell for Menu Scene implementation.
 */

import UIKit

class MenuFirmwareUpgradeTableViewCell: UITableViewCell {
    @IBOutlet weak var firmwareUpgradeIconImageView: UIImageView!
    @IBOutlet weak var firmwareUpgradeMessageLabel: UILabel!

    var parentVC: UIViewController?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
