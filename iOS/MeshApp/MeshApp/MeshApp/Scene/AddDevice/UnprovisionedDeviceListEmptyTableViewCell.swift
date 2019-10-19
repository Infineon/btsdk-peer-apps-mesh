/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Unprovisioned device Empty table view cell implementation.
 */

import UIKit

class UnprovisionedDeviceListEmptyTableViewCell: UITableViewCell {
    @IBOutlet weak var emptyImageView: UIImageView!
    @IBOutlet weak var emptyCellMessageLable: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
