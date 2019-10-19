/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Unprovisioned device list cell implementation.
 */

import UIKit

class UnprovisionedDeviceListTableViewCell: UITableViewCell {
    @IBOutlet weak var deviceIconImage: UIImageView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var addSymbolLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
