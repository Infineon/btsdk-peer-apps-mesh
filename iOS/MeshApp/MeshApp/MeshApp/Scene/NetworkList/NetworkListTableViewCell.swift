/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Network List table view cell implementation.
 */

import UIKit
import MeshFramework

class NetworkListTableViewCell: UITableViewCell {
    @IBOutlet weak var meshNetworkNameLabel: UILabel!
    @IBOutlet weak var networkIconImage: UIImageView!
    @IBOutlet weak var networkMessageLabel: UILabel!
    @IBOutlet weak var networkOpenStatusSwitch: UISwitch!

    private let indicatorView = CustomIndicatorView()

    var networkName: String? {
        didSet {
            meshNetworkNameLabel.text = networkName
            updateNetworkName()
        }
    }

    func updateNetworkName() {
        if let cellNetworkName = networkName {
            if let networkName = MeshFrameworkManager.shared.getOpenedMeshNetworkName(), networkName == cellNetworkName {
                networkOpenStatusSwitch.setOn(true, animated: true)
            } else {
                networkOpenStatusSwitch.setOn(false, animated: true)
            }
            print("NetworkListTableViewCell, mesh network: \(cellNetworkName) is  \(networkOpenStatusSwitch.isOn ? "opened" : "closed")")
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        networkOpenStatusSwitch.setOn(false, animated: false)
        updateNetworkName()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    @IBAction func onNetworkOpenStatusSwitchClick(_ sender: UISwitch) {
        print("NetworkListTableViewCell, onNetworkOpenStatusSwitchClick, switch button is \(networkOpenStatusSwitch.isOn ? "ON" : "OFF")")
        // Note, this switch is not interactive UI controller, it's just to display the status of mesh network is opened or not.
    }
}
