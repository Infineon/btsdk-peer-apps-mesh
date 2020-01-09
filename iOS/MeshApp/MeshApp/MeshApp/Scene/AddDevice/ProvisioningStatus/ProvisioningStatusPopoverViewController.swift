/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Device provisionig view controller implementation.
 */

import UIKit
import MeshFramework

class ProvisioningStatusPopoverViewController: UIViewController {
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var renameButton: UIButton!
    @IBOutlet weak var testButton: UIButton!

    var parentVc: UnprovisionedDevicesViewController?
    var deviceName: String?                 // original device name before mesh provisioned.
    var provisionedDeviceName: String?      // mesh managed device name after mesh provisioned successfully.
    var deviceUuid: UUID?
    var groupName: String?
    var deviceType: Int = MeshConstants.MESH_COMPONENT_UNKNOWN

    var testButtonClickCount: Int = 0;

    var isScanProvisionTestEnabled: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        notificationInit()
        viewInit()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(150)) {
            // Note, before start provisiong, be sure the scan has been stopped and has waitted for more than 100ms.
            self.provisioningStart()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewDidDisappear(animated)
    }

    func notificationInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_PROVISION_COMPLETE_STATUS), object: nil)
    }

    @objc func notificationHandler(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        switch notification.name {
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED):
            if let nodeConnectionStatus = MeshNotificationConstants.getNodeConnectionStatus(userInfo: userInfo) {
                self.showToast(message: "Device \"\(nodeConnectionStatus.componentName)\" \((nodeConnectionStatus.status == MeshConstants.MESH_CLIENT_NODE_CONNECTED) ? "has connected." : "is unreachable").")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED):
            if let linkStatus = MeshNotificationConstants.getLinkStatus(userInfo: userInfo) {
                self.showToast(message: "Mesh network has \((linkStatus.isConnected) ? "connected" : "disconnected").")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED):
            if let networkName = MeshNotificationConstants.getNetworkName(userInfo: userInfo) {
                self.showToast(message: "Database of mesh network \(networkName) has changed.")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_PROVISION_COMPLETE_STATUS):
            guard let provisionCompleteStatus = MeshNotificationConstants.getProvisionStatus(userInfo: userInfo) else {
                meshLog("error: ProvisioningStatusPopoverViewController, notificationHandler, invalid provision status data: \(String(describing: userInfo as? [String: Any]))")
                return
            }
            self.onProvisioinStatusUpdated(status: provisionCompleteStatus.status, uuid: provisionCompleteStatus.uuid)
        default:
            break
        }
    }

    func viewInit() {
        if let name = self.deviceName {
            self.deviceNameLabel.text = name
        } else {
            self.deviceNameLabel.text = MeshConstantText.UNKNOWN_DEVICE_NAME
        }
        self.viewDidUpdateProvisionStatus(message: "Provision Preparing", progressPercentage: 0.0)
        self.activityIndicator.startAnimating()

        self.okButton.setTitleColor(UIColor.lightGray, for: .disabled)
        self.renameButton.setTitleColor(UIColor.lightGray, for: .disabled)
        self.testButton.setTitleColor(UIColor.lightGray, for: .disabled)
        self.okButton.isEnabled = false
        self.renameButton.isEnabled = false
        self.testButton.isEnabled = false
    }

    // the received provision status update value should be 2,3,6,4,5 if done successfully.
    func onProvisioinStatusUpdated(status: Int, uuid: UUID) {
        guard uuid.uuidString == deviceUuid?.uuidString ?? "" else {
            meshLog("warning: ProvisioningStatusPopoverViewController, onProvisioinStatusUpdated, device uuid mismatched, received uuid:\(uuid), expected uuid:\(String(describing: deviceUuid))")
            return
        }

        meshLog("ProvisioningStatusPopoverViewController, onProvisioinStatusUpdated, status=\(status), uuid=\(uuid.uuidString)")
        switch status {
        case MeshConstants.MESH_CLIENT_PROVISION_STATUS_FAILED:
            self.viewDidUpdateProvisionStatus(message: "Provision Failed", progressPercentage: 1)
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            self.okButton.isEnabled = true
            self.renameButton.isEnabled = false
            self.testButton.isEnabled = false

            if isScanProvisionTestEnabled {  // exist the popup dialogue
                DispatchQueue.main.async {
                    self.dismiss(animated: true) {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STATUS),
                        object: nil,
                        userInfo: [
                            MeshNotificationConstants.USER_INFO_KEY_STAGE: MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STAGE_PROVISIONING,
                            MeshNotificationConstants.USER_INFO_KEY_STAGE_STATUS: MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STAGE_STATUS_FAILED,
                            MeshNotificationConstants.USER_INFO_KEY_UNPROVISIONED_DEVICE_NAME: (self.deviceName ?? "") as Any,
                            MeshNotificationConstants.USER_INFO_KEY_TARGET_DEVICE_UUID: (self.deviceUuid?.uuidString ?? "") as Any,
                            MeshNotificationConstants.USER_INFO_KEY_PROVISIONED_DEVICE_NAME: (self.provisionedDeviceName ?? "") as Any])
                    }
                }
            }
        case MeshConstants.MESH_CLIENT_PROVISION_STATUS_CONNECTING:
            self.viewDidUpdateProvisionStatus(message: "Provision Scanning", progressPercentage: 0.2)
        case MeshConstants.MESH_CLIENT_PROVISION_STATUS_PROVISIONING:
            self.viewDidUpdateProvisionStatus(message: "Provision Connecting", progressPercentage: 0.4)
        case MeshConstants.MESH_CLIENT_PROVISION_STATUS_END:
            self.viewDidUpdateProvisionStatus(message: "Provision Data Exchanging", progressPercentage: 0.6)
        case MeshConstants.MESH_CLIENT_PROVISION_STATUS_CONFIGURING:
            self.viewDidUpdateProvisionStatus(message: "Provision Configuring", progressPercentage: 0.8)
        case MeshConstants.MESH_CLIENT_PROVISION_STATUS_SUCCESS:
            self.viewDidUpdateProvisionStatus(message: "Provision Success", progressPercentage: 1)
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            self.okButton.isEnabled = true
            self.renameButton.isEnabled = true
            self.testButton.isEnabled = true

            MeshDeviceManager.shared.addMeshDevice(by: uuid)
            UserSettings.shared.lastProvisionedDeviceUuid = uuid    // Store last provisoned device for later reterieve it back if required.
            provisionedDeviceName = MeshFrameworkManager.shared.getMeshComponentsByDevice(uuid: uuid)?.first
            if let provisionedDeviceName = provisionedDeviceName {
                self.deviceName = provisionedDeviceName
                self.deviceNameLabel.text = provisionedDeviceName
                self.deviceType = MeshFrameworkManager.shared.getMeshComponentType(componentName: provisionedDeviceName)
                meshLog("ProvisioningStatusPopoverViewController, onProvisioinStatusUpdated, provisionedDeviceName=\(provisionedDeviceName))")
            }

            if isScanProvisionTestEnabled {  // exist the popup dialogue
                DispatchQueue.main.async {
                    self.dismiss(animated: true) {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STATUS),
                        object: nil,
                        userInfo: [
                            MeshNotificationConstants.USER_INFO_KEY_STAGE: MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STAGE_PROVISIONING,
                            MeshNotificationConstants.USER_INFO_KEY_STAGE_STATUS: MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STAGE_STATUS_SUCCESS,
                            MeshNotificationConstants.USER_INFO_KEY_UNPROVISIONED_DEVICE_NAME: (self.deviceName ?? "") as Any,
                            MeshNotificationConstants.USER_INFO_KEY_TARGET_DEVICE_UUID: (self.deviceUuid?.uuidString ?? "") as Any,
                            MeshNotificationConstants.USER_INFO_KEY_PROVISIONED_DEVICE_NAME: (self.provisionedDeviceName ?? "") as Any])
                    }
                }
            }
        default:
            break
        }
    }

    func viewDidUpdateProvisionStatus(message: String, progressPercentage: Float) {
        self.messageLabel.text = message
        self.progressView.progress = progressPercentage > 1.0 ? 1.0 : (progressPercentage < 0.0 ? 0.0 : progressPercentage)
    }

    func provisioningStart() {
        meshLog("ProvisioningStatusPopoverViewController, provisioningStart, deviceName:\(String(describing: self.deviceName)), uuid:\(String(describing: self.deviceUuid)), groupName:\(String(describing: self.groupName))")

        var error = MeshErrorCode.MESH_ERROR_INVALID_ARGS
        if let name = self.deviceName, let uuid = self.deviceUuid, let group = self.groupName {
            self.viewDidUpdateProvisionStatus(message: "Start Provisioning", progressPercentage: 0.1)
            error = MeshFrameworkManager.shared.meshClientProvision(deviceName: name, uuid: uuid, groupName: group)
        }

        if error != MeshErrorCode.MESH_SUCCESS {
            meshLog("error: ProvisioningStatusPopoverViewController, provisioningStart, failed to call meshClientProvision API, error=\(error)")
            var message = "Failed to start provisioning with selected device. Error Code: \(error)."
            var stage_status: Int = MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STAGE_STATUS_FAILED
            if error ==  MeshErrorCode.MESH_ERROR_INVALID_STATE {
                stage_status = MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STAGE_STATUS_NETWORK_BUSY
                message = "Failed to start provisioning with selected device. Curretly, the mesh network is not idle, may busying on syncing with some unreachable devices. Please wait for a little later and try again."
            }

            if isScanProvisionTestEnabled {  // exist the popup dialogue
                self.dismiss(animated: true) {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STATUS),
                    object: nil,
                    userInfo: [
                        MeshNotificationConstants.USER_INFO_KEY_STAGE: MeshNotificationConstants.MESH_SCAN_PROVISION_TEST_STAGE_PROVISIONING,
                        MeshNotificationConstants.USER_INFO_KEY_STAGE_STATUS: stage_status,
                        MeshNotificationConstants.USER_INFO_KEY_UNPROVISIONED_DEVICE_NAME: (self.deviceName ?? "") as Any,
                        MeshNotificationConstants.USER_INFO_KEY_TARGET_DEVICE_UUID: (self.deviceUuid?.uuidString ?? "") as Any,
                        MeshNotificationConstants.USER_INFO_KEY_PROVISIONED_DEVICE_NAME: (self.provisionedDeviceName ?? "") as Any])
                }
                return
            }
            UtilityManager.showAlertDialogue(parentVC: self,
                                             message: message,
                                             title: "Error",
                                             completion: nil,
                                             action: UIAlertAction(title: "OK",
                                                                   style: .default,
                                                                   handler: { (action) in
                                                                    UtilityManager.navigateToViewController(targetClass: UnprovisionedDevicesViewController.self)
                                             })
            )
        }
    }

    @IBAction func onOkButtonClick(_ sender: UIButton) {
        meshLog("ProvisioningStatusPopoverViewController, onOkButtonClick")
        self.dismiss(animated: true) {
            NotificationCenter.default.removeObserver(self)
            self.parentVc?.pullToRefresh()
        }
    }

    @IBAction func onRenameButtonClick(_ sender: UIButton) {
        meshLog("ProvisioningStatusPopoverViewController, onRenameButtonClick")

        let alertController = UIAlertController(title: "Rename Device", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField: UITextField) in
            textField.placeholder = "Enter New Device Name"
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (action: UIAlertAction) -> Void in
            if let textField = alertController.textFields?.first, let newDeviceName = textField.text, newDeviceName.count > 0, let oldDeviceName = self.provisionedDeviceName {
                MeshFrameworkManager.shared.meshClientRename(oldName: oldDeviceName, newName: newDeviceName) { (networkName: String?, error: Int) in
                    guard error == MeshErrorCode.MESH_SUCCESS else {
                        meshLog("error: ProvisioningStatusPopoverViewController, failed to call rename Device Name from \(oldDeviceName) to \(newDeviceName), error=\(error)")
                        UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to rename device \"\(oldDeviceName)\" to \"\(newDeviceName)\". Error Code: \(error)")
                        return
                    }

                    meshLog("ProvisioningStatusPopoverViewController, rename \"\(oldDeviceName)\" device to new name=\"\(newDeviceName)\" success")
                    // rename done success, update the new device name.
                    if let meshDeviceUuid = self.deviceUuid, let meshName = MeshFrameworkManager.shared.getMeshComponentsByDevice(uuid: meshDeviceUuid)?.first {
                        self.provisionedDeviceName = meshName
                        self.deviceName = meshName
                        self.deviceNameLabel.text = meshName
                        UtilityManager.showAlertDialogue(parentVC: self, message: "Rename device from \"\(oldDeviceName)\" to \"\(meshName)\" sucess", title: "Success")
                    }
                }
            } else {
                UtilityManager.showAlertDialogue(parentVC: self, message: "Provinsion failed, or Invalid new device name!", title: "Error")
            }
        }))
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func onTestButtonClick(_ sender: UIButton) {
        guard let deviceName = self.provisionedDeviceName else {
            meshLog("ProvisioningStatusPopoverViewController, onTestButtonClick, invalid provisionedDeviceName nil")
            return
        }

        let doOnOffTest = false
        if doOnOffTest {
            testButtonClickCount += 1
            let isOn: Bool = ((testButtonClickCount % 2) == 0) ? false : true
            turnDeviceOnOffTest(deviceName: deviceName, isOn: isOn)
        } else {
            deviceIdentify(deviceName: deviceName)
        }
    }

    func turnDeviceOnOffTest(deviceName: String, isOn: Bool) {
        let lightness: Int = isOn ? 10 : 0
        let reliable: Bool = false
        var error = MeshErrorCode.MESH_SUCCESS

        meshLog("ProvisioningStatusPopoverViewController, turnDeviceOnOffTest, turn device:\(deviceName) \(isOn ? "ON" : "OFF"), reliable:\(reliable), type:\(deviceType)")
        switch self.deviceType {
        case MeshConstants.MESH_COMPONENT_GENERIC_LEVEL_SERVER:
            error = MeshFrameworkManager.shared.meshClientLevelSet(deviceName: deviceName, level: lightness, reliable: reliable, transitionTime: 0, delay: 0)
        case MeshConstants.MESH_COMPONENT_LIGHT_DIMMABLE:
            error = MeshFrameworkManager.shared.meshClientLightnessSet(deviceName: deviceName, lightness: lightness, reliable: reliable, transitionTime: 0, delay: 0)
        case MeshConstants.MESH_COMPONENT_LIGHT_HSL:
            error = MeshFrameworkManager.shared.meshClientHslSet(deviceName: deviceName, lightness: lightness, hue: 0, saturation: 0, reliable: reliable, transitionTime: 0, delay: 0)
        case MeshConstants.MESH_COMPONENT_LIGHT_CTL:
            error = MeshFrameworkManager.shared.meshClientCtlSet(deviceName: deviceName, lightness: lightness, temperature: 20, deltaUv: 0, reliable: reliable, transitionTime: 0, delay: 0)
        default:
            error = MeshFrameworkManager.shared.meshClientOnOffSet(deviceName: deviceName, isOn: isOn, reliable: reliable)
        }
        guard error == MeshErrorCode.MESH_SUCCESS else {
            meshLog("ProvisioningStatusPopoverViewController, turnDeviceOnOffTest, failed to turn device:\"\(deviceName)\" \(isOn ? "ON" : "OFF")")
            return
        }
        meshLog("ProvisioningStatusPopoverViewController, turnDeviceOnOffTest, turn device:\(deviceName) \(isOn ? "ON" : "OFF") success")
    }

    func deviceIdentify(deviceName: String) {
        self.testButton.isEnabled = false
        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                self.testButton.isEnabled = true
                meshLog("ProvisioningStatusPopoverViewController, deviceIdentify, device:\(deviceName), failed to connect to mesh network")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientIdentify(name: deviceName, duration: 10)
            meshLog("ProvisioningStatusPopoverViewController, deviceIdentify, device:\(deviceName), error:\(error)")
            self.testButton.isEnabled = true
        }
    }
}
