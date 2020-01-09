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
    @IBOutlet weak var scanProvisionTestBtn: UIButton!

    var parentVC: UnprovisionedDevicesViewController?
    var unprovisionedDeviceName: String?
    var unprovisionedDeviceUuid: UUID?
    var groupName: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onScanProvisionTestBtnClick(_ sender: UIButton) {
        if let pVc = parentVC, let targetName = unprovisionedDeviceName, let targetUuid = unprovisionedDeviceUuid, let targetGroupName = groupName {
            DispatchQueue.main.async {
                ScanProvisionTestViewController.unprovisionedDeviceName = targetName
                ScanProvisionTestViewController.deviceUuid = targetUuid
                ScanProvisionTestViewController.provisionGroupName = targetGroupName
                UtilityManager.navigateToViewController(sender: pVc, targetVCClass: ScanProvisionTestViewController.self)
            }
        } else {
            if let vc = parentVC {
                UtilityManager.showAlertDialogue(parentVC: vc, message: "Invalid test device info, name: \(unprovisionedDeviceName ?? "nil"), uuid: \(unprovisionedDeviceUuid?.uuidString ?? "nil"), groupName: \(groupName ?? "nil")")
            }
        }
    }
}
