/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Firmware Upgrade Table View Cell implementation.
 */

import UIKit
import MeshFramework

class FirmwareUpgradeTableViewCell: UITableViewCell {
    @IBOutlet weak var deviceTypeLabel: UILabel!
    @IBOutlet weak var deviceNameLabel: UILabel!

    var otaDevice: OtaDeviceProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
