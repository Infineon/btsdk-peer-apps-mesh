/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Firmware Upgrade Empty Table View Cell implementation.
 */

import UIKit

class FirmwareUpgradeEmptyTableViewCell: UITableViewCell {
    @IBOutlet weak var emptyImageView: UIImageView!
    @IBOutlet weak var emptyMessageLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
