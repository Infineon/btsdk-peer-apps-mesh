/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Deleting devices table view cell implementation.
 */

import UIKit
import MeshFramework

class DeletingDevicesTableViewCell: UITableViewCell {
    @IBOutlet weak var deviceTypeIconImage: UIImageView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var operationStatusView: UIView!
    @IBOutlet weak var deviceStatusMessageLabel: UILabel!
    @IBOutlet weak var deviceSyncingIconButton: UIButton!
    @IBOutlet weak var deviceConnectButton: UIButton!
    @IBOutlet weak var deviceDeleteButton: UIButton!

    var parentVC: UIViewController?

    let messageDeviceIsReachable = "Device is reachable"
    let messageDeviceNotResponsable = "Device not responsable"
    let messageDeviceIsInSyncing = "Device is in syncing"

    var deviceName: String? {
        didSet {
            guard let deviceName = self.deviceName, !deviceName.isEmpty else {
                return
            }
            deviceNameLabel.text = deviceName
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        meshDeviceStatusInit()

        self.deviceConnectButton.isEnabled = false
        self.deviceConnectButton.isHidden = true
        self.operationStatusView.layer.cornerRadius = self.operationStatusView.frame.size.width/2
        self.operationStatusView.clipsToBounds = true
    }

    func meshDeviceStatusInit() {
        guard let deviceName = self.deviceName else {
            return
        }
        let deviceType = MeshFrameworkManager.shared.getMeshComponentType(componentName: deviceName)
        // TODO(optional): udpate deviceTypeIconImage.image based the device type.
        switch deviceType {
        case MeshConstants.MESH_COMPONENT_LIGHT_HSL:
            break
        case MeshConstants.MESH_COMPONENT_LIGHT_CTL:
            break
        case MeshConstants.MESH_COMPONENT_LIGHT_DIMMABLE:
            break
        case MeshConstants.MESH_COMPONENT_VENDOR_SPECIFIC:
            break
        default:
            break
        }

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onDeviceSyncingIconButtonClick(_ sender: UIButton) {
        meshLog("DeletingDevicesTableViewCell, onDeviceSyncingIconButtonClick")
        deviceConnectSync()
    }

    @IBAction func onDeviceConnectButtonClick(_ sender: UIButton) {
        meshLog("DeletingDevicesTableViewCell, onDeviceConnectButtonClick")
        deviceConnectSync()
    }

    @IBAction func onDeviceDeleteButtonClick(_ sender: UIButton) {
        meshLog("DeletingDevicesTableViewCell, onDeviceDeleteButtonClick")
        guard let deviceName = self.deviceName else {
            return
        }
        MeshFrameworkManager.shared.meshClientDeleteDevice(deviceName: deviceName) { (networkName: String?, error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                meshLog("DeletingDevicesTableViewCell, onDeviceDeleteButtonClick, failed to delete the device, error=\(error)")
                return
            }

            meshLog("DeletingDevicesTableViewCell, onDeviceDeleteButtonClick, delete the device success")
        }
    }

    func deviceConnectSync() {
        guard let deviceName = self.deviceName else {
            return
        }

        self.deviceSyncingIconButton.imageView?.startRotate()
        self.operationStatusView.backgroundColor = UIColor.yellow
        self.deviceStatusMessageLabel.text = messageDeviceIsInSyncing
        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                meshLog("error: DeletingDevicesTableViewCell, deviceConnectSync, failed to connect to mesh network, error=\(error)")
                self.deviceSyncingIconButton.imageView?.stopRotate()
                self.operationStatusView.backgroundColor = UIColor.red
                self.deviceStatusMessageLabel.text = self.messageDeviceNotResponsable

                if let vc = self.parentVC {
                    UtilityManager.showAlertDialogue(parentVC: vc, message: "Unable to connect to the mesh network or device is not responsable. Error Code: \(error)")
                }
                return
            }

            MeshFrameworkManager.shared.meshClientOnOffGet(deviceName: deviceName) { (deviceName: String,  isOn: Bool, isPresent: Bool, remainingTime: UInt32, error: Int) in
                self.deviceSyncingIconButton.imageView?.stopRotate()

                guard error == MeshErrorCode.MESH_SUCCESS else {
                    meshLog("error: DeletingDevicesTableViewCell, deviceConnectSync, meshClientOnOffGet failed, error=\(error)")
                    self.operationStatusView.backgroundColor = UIColor.red
                    self.deviceStatusMessageLabel.text = self.messageDeviceNotResponsable

                    if let vc = self.parentVC {
                        UtilityManager.showAlertDialogue(parentVC: vc, message: "Device is not found ro responsable or encounter error. Error Code: \(error).")
                    }
                    return
                }

                self.operationStatusView.backgroundColor = UIColor.green
                self.deviceStatusMessageLabel.text = self.messageDeviceIsReachable
                meshLog("error: DeletingDevicesTableViewCell, deviceConnectSync, meshClientOnOffGet success")
            }
        }
    }
}
