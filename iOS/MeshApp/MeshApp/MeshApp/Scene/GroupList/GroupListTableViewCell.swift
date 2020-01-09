/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Group List table view cell implementation.
 */

import UIKit
import MeshFramework

class GroupListTableViewCell: UITableViewCell {
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var groupIconImage: UIImageView!
    @IBOutlet weak var groupTurnOnButton: UIButton!
    @IBOutlet weak var groupTurnOffButton: UIButton!
    @IBOutlet weak var showGroupAllDevicesButton: UIButton!
    @IBOutlet weak var showGroupControlsButton: UIButton!

    var groupName: String? {
        didSet {
            if groupNameLabel != nil {
                groupNameLabel.text = groupName ?? "Unknown"
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onGroupTurnOnButtonClick(_ sender: UIButton) {
        meshLog("GroupListTableViewCell, onGroupTurnOnButtonClick, TURN ON all devices within mesh group: \(String(describing: groupName))")
        turnGroupDevicesOnOff(groupName: groupName, isOn: true)
    }

    @IBAction func onGroupTurnOffButtonClick(_ sender: UIButton) {
        meshLog("GroupListTableViewCell, onGroupTurnOnButtonClick, TURN OFF all devices within mesh group: \(String(describing: groupName))")
        turnGroupDevicesOnOff(groupName: groupName, isOn: false)
    }

    @IBAction func onShowGroupAllDevicesButtonClick(_ sender: UIButton) {
        meshLog("GroupListTableViewCell, onShowGroupAllDevicesButtonClick, group name: \(String(describing: groupName))")
        if let groupName = groupName {
            UserSettings.shared.currentActiveGroupName = groupName
            // do nothing, done through segue, navigate to the group detail scene and set defalut with all group devices item enabled.
        }
    }

    @IBAction func onShowGroupControlsButtonClick(_ sender: UIButton) {
        meshLog("GroupListTableViewCell, onShowGroupControlsButtonClick, group name: \(String(describing: groupName))")
        if let groupName = groupName {
            UserSettings.shared.currentActiveGroupName = groupName
            // do nothing, done through segue, navigate to the group detail scene and set defalut with group controls item enabled.
        }
    }

    /**
     Turn the remote devices ON or OFF which subscribed by the specific group.

     @param deviceName      Name of the mesh group where all the devices should be turned ON or OFF.
     @param isON            Indicate the operation of turn ON (turn) or turn OFF (false).
     @param reliable        Indicates to send using the Acknowledged (true) or the Unacknowledged (false) message.
                            For mesh group, it's set to false by default.

     @return                None.

     Note, when the reliable set to true, all the compenents which have its On/Off callback routine invoked with its status update value.
     */
    func turnGroupDevicesOnOff(groupName: String?, isOn: Bool, reliable: Bool = false) {
        if let groupName = groupName {
            MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
                guard error == MeshErrorCode.MESH_SUCCESS else {
                    meshLog("error: GroupListTableViewCell, turnGroupDevicesOnOff(groupName:\(groupName), isOn:\(isOn)), failed to connect to the mesh network")
                    return
                }

                let error = MeshFrameworkManager.shared.meshClientOnOffSet(deviceName: groupName, isOn: isOn, reliable: reliable)
                guard error == MeshErrorCode.MESH_SUCCESS else {
                    meshLog("error: GroupListTableViewCell, meshClientOnOffSet(groupName:\(groupName), isOn:\(isOn), reliable=\(reliable)) failed, error=\(error)")
                    return
                }
                meshLog("GroupListTableViewCell, meshClientOnOffSet(groupName:\(groupName), isOn:\(isOn), reliable=\(reliable)) message sent out success")
            }
        }
    }
}
