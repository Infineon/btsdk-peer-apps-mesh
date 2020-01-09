/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Device OTA Upgrade View implementation.
 */

import UIKit
import MeshFramework

class DeviceOtaUpgradeViewController: UIViewController {
    @IBOutlet weak var topNavigationItem: UINavigationItem!
    @IBOutlet weak var backBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var settingsBarButtomItem: UIBarButtonItem!
    @IBOutlet weak var otaUpgradeTitleLabel: UILabel!
    @IBOutlet weak var otaDeviceNameLabel: UILabel!
    @IBOutlet weak var otaDeviceFwVersionLabel: UILabel!
    @IBOutlet weak var otaDropDownView: CustomDropDownView!
    @IBOutlet weak var otaBackgroundView: UIView!
    @IBOutlet weak var otaDeviceFiwImageHintLabel: UILabel!
    @IBOutlet weak var otaFirmwareUpgradeButton: UIButton!
    @IBOutlet weak var otaProgressBar: UIProgressView!
    @IBOutlet weak var otaProgressPercentage: UILabel!
    @IBOutlet weak var otaUpgradeLogTextView: UITextView!
    @IBOutlet weak var otaUpgradingActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var otaDeviceTypeLable: UILabel!

    private var otaBasciDate = Date(timeIntervalSinceNow: 0)

    var deviceName: String?
    var groupName: String?  // When groupName is not nil, it comes from CmponentViewControl; if groupName is nil, it comes from FirmwareUpgradeViewController.

    var tmpCBDeviceObject: AnyObject?     // only valid when the view controller active.
    var otaDevice: OtaDeviceProtocol?
    var otaFwImageNames: [String] = []
    var selectedFwImageName: String?

    var isPreparingForOta: Bool = false
    var otaUpdatedStarted: Bool = false
    var lastTransferredPercentage: Int = -1  // indicates invalid value, will be udpated.

    override func viewDidLoad() {
        super.viewDidLoad()
        meshLog("DeviceOtaUpgradeViewController, viewDidLoad")

        // Do any additional setup after loading the view.
        otaDevice = OtaManager.shared.activeOtaDevice
        tmpCBDeviceObject = otaDevice?.otaDevice

        notificationInit()
        viewInit()
    }

    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        OtaManager.shared.resetOtaUpgradeStatus()
        tmpCBDeviceObject = nil
        super.viewDidDisappear(animated)
    }

    func viewInit() {
        otaUpgradeLogTextView.text = ""
        log("OTA Upgrade view loaded")
        log("OTA device type: \(otaDevice?.getDeviceType() ?? OtaDeviceType.ble)")
        log("OTA device name: \"\(otaDevice?.getDeviceName() ?? "Unknown Name")\"")

        topNavigationItem.rightBarButtonItem = nil  // not used currently.
        otaUpgradeLogTextView.layer.borderWidth = 1
        otaUpgradeLogTextView.layer.borderColor = UIColor.gray.cgColor
        otaUpgradeLogTextView.isEditable = false
        otaUpgradeLogTextView.isSelectable = false
        otaUpgradeLogTextView.layoutManager.allowsNonContiguousLayout = false

        otaDropDownView.dropDownDelegate = self

        otaUpdatedStarted = false
        lastTransferredPercentage = -1  // indicates invalid value, will be udpated.
        otaProgressUpdated(percentage: 0.0)

        guard let otaDevice = self.otaDevice else {
            meshLog("error: DeviceOtaUpgradeViewController, viewInit, invalid otaDevice instance nil")
            log("error: invalid nil OTA device object")
            DispatchQueue.main.async {
                UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil OTA device object.", title: "Error")
            }
            return
        }
        otaDeviceNameLabel.text = otaDevice.getDeviceName()
        otaDeviceFwVersionLabel.text = "Not Avaiable"
        otaDeviceTypeLable.text = OtaManager.getOtaDeviceTypeString(by: otaDevice.getDeviceType())
        topNavigationItem.title = "OTA Upgrade"

        otaFirmwareUpgradeButton.setTitleColor(UIColor.gray, for: .disabled)
        stopOtaUpgradingAnimating()

        DispatchQueue.main.async {
            // read and update firmware image list.
            self.firmwareImagesInit()
            self.otaDropDownView.dropListItems = self.otaFwImageNames

            // [Dudley] test purpose.
            // Try to read and show the firmware version automatically if supported before starting the OTA upgrade process.
            // Or set prepareAndReadFwVersionAutomatically to false to let the App always run the OTA process directly after click the Firmware Upgrade button.
            let prepareAndReadFwVersionAutomatically = true
            if !prepareAndReadFwVersionAutomatically { return }
            if let otaDevice = self.otaDevice, otaDevice.getDeviceType() != .mesh, MeshFrameworkManager.shared.isMeshNetworkConnected() {
                MeshFrameworkManager.shared.disconnectMeshNetwork(completion: { (isConnected: Bool, connId: Int, addr: Int, isOverGatt: Bool, error: Int) in
                    self.otaUpgradePrepare()
                })
            } else {
                self.otaUpgradePrepare()
            }
        }
    }

    func notificationInit() {
        /* [Dudley]: When do firmware OTA, the mesh notification should be suppressed to avoid any confusion.
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED), object: nil)
         NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
         name: Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED), object: nil)
        */

        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: OtaConstants.Notification.OTA_STATUS_UPDATED), object: nil)
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
        case Notification.Name(rawValue: OtaConstants.Notification.OTA_STATUS_UPDATED):
            if let otaStatus = OtaConstants.Notification.getOtaNotificationData(userInfo: userInfo) {
                let otaState = OtaUpgrader.OtaState(rawValue: otaStatus.otaState) ?? OtaUpgrader.OtaState.idle
                if otaStatus.errorCode == OtaErrorCode.SUCCESS {
                    if otaStatus.otaState == OtaUpgrader.OtaState.idle.rawValue {
                        log("OTA state: \(otaStatus.description).")
                    } else if otaStatus.otaState == OtaUpgrader.OtaState.readAppInfo.rawValue {
                        // try to get and show the read firmware version from remote device.
                        let appInfo = String(otaStatus.description.trimmingCharacters(in: CharacterSet.whitespaces))
                        log("OTA state: \(otaState.description) finished success. \(appInfo)")
                        var version = ""
                        if let otaDevice = self.otaDevice, otaDevice.getDeviceType() == .mesh, appInfo.hasPrefix("CID:") {
                            let componentInfoValue = MeshComponentInfo(componentInfo: appInfo)
                            version = componentInfoValue.VER
                        } else {
                            let appVersion = String(appInfo.split(separator: " ").last ?? "")
                            if !appVersion.isEmpty, appVersion != "success" {
                                let characterSet = CharacterSet(charactersIn: "0123456789.")
                                version = appVersion.trimmingCharacters(in: characterSet)
                            }
                        }
                        if !version.isEmpty {
                            otaDeviceFwVersionLabel.text = version
                        }
                    } else if otaStatus.otaState == OtaUpgrader.OtaState.dataTransfer.rawValue {
                        if otaStatus.transferredImageSize == 0 {
                            log("OTA state: \(otaState.description) started.")
                        }
                        // Update and log firmware image download percentage value.
                        otaProgressUpdated(percentage: Float(otaStatus.transferredImageSize) / Float(otaStatus.fwImageSize))
                    } else if otaStatus.otaState == OtaUpgrader.OtaState.complete.rawValue {
                        otaUpdatedStarted = false
                        // OTA upgrade process finished, navigate to previous view controller if success.
                        self.stopOtaUpgradingAnimating()
                        if !self.isPreparingForOta {
                            self.log("done: OTA upgrade completed success.\n")
                            UtilityManager.showAlertDialogue(parentVC: self,
                                                             message: "Congratulation! OTA process has finshed successfully.",
                                                             title: "Success", completion: nil,
                                                             action: UIAlertAction(title: "OK", style: .default,
                                                                                   handler: { (action) in
                                                                                    //self.onLeftBarButtonItemClick(self.backBarButtonItem)
                                                             }))
                        } else {
                            self.log("done: prepare for OTA upgrade is ready.\nPlease select a firmware image and click the Firmware Upgrade button to start OTA.\n")
                        }
                        self.isPreparingForOta = false
                    } else {
                        // Log normal OTA upgrade successed step.
                        log("OTA state: \(otaState.description) finished success.")
                        if otaState == OtaUpgrader.OtaState.otaServiceDiscover, let otaDevice = self.otaDevice {
                            log("OTA version: OTA_VERSION_\(otaDevice.otaVersion)")
                        }
                    }
                } else {
                    if otaStatus.otaState == OtaUpgrader.OtaState.complete.rawValue {
                        otaUpdatedStarted = false
                        // OTA upgrade process finished
                        self.log("done: OTA upgrade stopped with error. Error Code: \(otaStatus.errorCode), \(otaStatus.description)\n")
                        self.stopOtaUpgradingAnimating()
                        if !self.isPreparingForOta {
                            UtilityManager.showAlertDialogue(parentVC: self,
                                                             message: "Oops! OTA process stopped with some error, please reset device and retry again later.")
                        } else {
                            if otaStatus.errorCode == OtaErrorCode.ERROR_DEVICE_OTA_NOT_SUPPORTED {
                                UtilityManager.showAlertDialogue(parentVC: self,
                                                                 message: "Oops! Target device doesn't support Cypress OTA function, please select the device that support Cypress OTA function and try again.",
                                                                 title: "Error", completion: nil,
                                                                 action: UIAlertAction(title: "OK", style: .default,
                                                                                       handler: { (action) in
                                                                                        //self.onLeftBarButtonItemClick(self.backBarButtonItem)
                                                                 }))
                            } else {
                                self.log("Please select the firmare image, then click the \"Firmware Upgrade\" button to try again.\n\n")
                            }
                        }
                        self.isPreparingForOta = false
                    } else {
                        // Log normal OTA upgrade failed step.
                        log("error: OTA state: \(otaState.description) failed. Error Code:\(otaStatus.errorCode), message:\(otaStatus.description)")
                    }
                }
            }
        default:
            break
        }
    }

    //
    // This function will try to connect to the OTA device, then try to discover OTA services,
    // try and read the AppInfo and update to UI if possible.
    // Also, to call this function alonely can help to verify the feature of connecting to different OTA devices.
    //
    func doOtaUpgradePrepare() {
        guard let otaDevice = self.otaDevice else {
            meshLog("error: DeviceOtaUpgradeViewController, otaUpgradePrepare, invalid OTA device instance")
            log("error: invalid nil OTA device object")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil OTA device object.")
            return
        }

        isPreparingForOta = true
        startOtaUpgradingAnimating()
        let error = otaDevice.prepareOta()
        guard error == OtaErrorCode.SUCCESS else {
            stopOtaUpgradingAnimating()
            if error == OtaErrorCode.BUSYING {
                return
            }
            meshLog("error: DeviceOtaUpgradeViewController, otaUpgradePrepare, failed to prepare for OTA")
            self.log("error: failed to prepare for OTA, error:\(error)")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to prepare for OTA. Error Code: \(error).", title: "Error")
            return
        }
    }
    func otaUpgradePrepare() {
        DispatchQueue.main.async {
            self.doOtaUpgradePrepare()  // because self.otaDevice instance is from main thread, so make suer it running in main thread.
        }
    }

    func firmwareImagesInit() {
        let defaultDocumentsPath = NSHomeDirectory() + "/Documents"
        let meshPath = "mesh"
        let fwImagePath = "\(meshPath)/fwImages"
        let meshSearchPath = "\(defaultDocumentsPath)/\(meshPath)"
        let fwImagesSearchPath = "\(defaultDocumentsPath)/\(fwImagePath)"

        otaFwImageNames.removeAll()
        let foundInFwImages = addFirmwareImageNames(atPath: meshSearchPath, prefix: fwImagePath)
        let foundInMesh = addFirmwareImageNames(atPath: fwImagesSearchPath, prefix: meshPath)
        let foundInDocuments = addFirmwareImageNames(atPath: defaultDocumentsPath)
        if !foundInFwImages, !foundInMesh, !foundInDocuments {
            meshLog("error: DeviceOtaUpgradeViewController, firmwareImagesInit, no valid firmware images found")
            UtilityManager.showAlertDialogue(parentVC: self, message: "No valid firmware images found under App's \"Documents/mesh/fwImages\", \"Documents/mesh\" and  \"Documents\" directories. Please copy valid firmware images into your device, then try again later.", title: "Error")
        }
    }

    func addFirmwareImageNames(atPath: String, prefix: String? = nil) -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: atPath, isDirectory: &isDirectory)
        if !exists || !isDirectory.boolValue {
            meshLog("error: DeviceOtaUpgradeViewController, addFirmwareImageNames, \(atPath) not exsiting")
            return false
        }

        let namePrefix = ((prefix == nil) || (prefix?.isEmpty ?? true)) ? "" : (prefix! + "/")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: atPath) {
            for fileName in files {
                // ecdsa256_genkey.exe tool will auto append .signed extension to the signed image file name.
                if fileName.hasSuffix(".bin") || fileName.hasSuffix(".bin.signed") {
                    otaFwImageNames.append(namePrefix + fileName)
                    meshLog("DeviceOtaUpgradeViewController, addFirmwareImageNames, found image: \(namePrefix + fileName)")
                }
            }
        }

        if otaFwImageNames.isEmpty {
            return false
        }
        return true
    }

    func getFullPath(for selectFileName: String) -> String {
        return NSHomeDirectory() + "/Documents/" + selectFileName
    }

    func otaProgressUpdated(percentage: Float) {
        let pct: Float = (percentage > 1.0) ? 1.0 : ((percentage < 0.0) ? 0.0 : percentage)
        let latestPercentage = Int(pct * 100)
        otaProgressPercentage.text = String(format: "%d", latestPercentage) + "%"
        otaProgressBar.progress = percentage

        if otaUpdatedStarted, lastTransferredPercentage != latestPercentage {
            log("transferred size: \(latestPercentage)%%")
            lastTransferredPercentage = latestPercentage
        }
    }

    func log(_ message: String) {
        let seconds = Date().timeIntervalSince(otaBasciDate)
        let msg = String(format: "[%.3f] \(message)\n", seconds)
        otaUpgradeLogTextView.text += msg
        let bottom = NSRange(location: otaUpgradeLogTextView.text.count, length: 1)
        otaUpgradeLogTextView.scrollRangeToVisible(bottom)
    }

    @IBAction func onOtaFirmwareUpgradeButtonClick(_ sender: UIButton) {
        meshLog("DeviceOtaUpgradeViewController, onOtaFirmwareUpgradeButtonClick")
        log("OTA update button triggerred")
        otaUpdatedStarted = false
        lastTransferredPercentage = -1  // indicates invalid value, will be udpated.
        otaProgressUpdated(percentage: 0.0)

        guard let otaDevice = self.otaDevice else {
            meshLog("error: DeviceOtaUpgradeViewController, onOtaFirmwareUpgradeButtonClick, invalid OTA device instance")
            log("error: invalid nil OTA device object")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil OTA device object.")
            return
        }
        var fwImagePath = NSHomeDirectory() + "/Documents/"
        guard let fwImageName = self.selectedFwImageName else {
            meshLog("error: DeviceOtaUpgradeViewController, onOtaFirmwareUpgradeButtonClick, no firmware image selected")
            log("error: no firmware image selected")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Please select a firmware image firstly, then try again.")
            return
        }

        fwImagePath = fwImagePath + fwImageName
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: fwImagePath, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue, let fwImageData = FileManager.default.contents(atPath: fwImagePath) else {
            meshLog("error: DeviceOtaUpgradeViewController, onOtaFirmwareUpgradeButtonClick, selected firmware image not exists")
            log("error: unable to read the content of the selected firmware image")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Firmware image \"\(fwImagePath)\" not found or failed to read the image file. Please copy and select valid firmware images into your device, then retry later.", title: "Error")
            return
        }
        meshLog("DeviceOtaUpgradeViewController, onOtaFirmwareUpgradeButtonClick, otaDevice=\(otaDevice), fwImagePath=\(fwImagePath), imageSize=\(fwImageData.count)")

        // the CoreBlutooth peripheral object has been cleaned when disconnected, here try to restore it for quick action if possible.
        if self.otaDevice?.otaDevice == nil {
            self.otaDevice?.otaDevice = tmpCBDeviceObject
        }

        if otaDevice.getDeviceType() != .mesh, false {
            UtilityManager.showAlertDialogue(
                parentVC: self,
                message: "Are you sure you want to upgrade the \"\(otaDevice.getDeviceName())\" device from \(otaDevice.getDeviceType()) device to mesh device ?\n\nClick \"OK\" button to continue.\nClick \"Cancel\" button to exit",
                title: "Warning",
                cancelHandler: { (action: UIAlertAction) in return },
                okayHandler: { (action: UIAlertAction) in self.doOtaFirmwareUpgrade(otaDevice: otaDevice, fwImage: fwImageData) }
            )
            return
        }
        doOtaFirmwareUpgrade(otaDevice: otaDevice, fwImage: fwImageData)
    }

    func doOtaFirmwareUpgrade(otaDevice: OtaDeviceProtocol, fwImage: Data) {
        DispatchQueue.main.async {  // because self.otaDevice instance is from main thread, so make suer it running in main thread.
            // Try to start OTA process.
            self.isPreparingForOta = false
            self.startOtaUpgradingAnimating()
            let error = otaDevice.startOta(fwImage: fwImage)
            guard error == OtaErrorCode.SUCCESS else {
                self.stopOtaUpgradingAnimating()
                meshLog("error: DeviceOtaUpgradeViewController, doOtaFirmwareUpgrade, failed to start OTA process")
                self.log("error: failed to start OTA process, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to start OTA process. Error Code: \(error).", title: "Error")
                return
            }
            meshLog("DeviceOtaUpgradeViewController, doOtaFirmwareUpgrade, OTA process running")
            self.log("OTA upgrade process started")
            self.otaUpdatedStarted = true
        }
    }

    @IBAction func onLeftBarButtonItemClick(_ sender: UIBarButtonItem) {
        meshLog("DeviceOtaUpgradeViewController, onLeftBarButtonItemClick")
        OtaManager.shared.resetOtaUpgradeStatus()
        if let otaDevice = self.otaDevice, otaDevice.getDeviceType() == .mesh, let groupName = self.groupName {
            meshLog("DeviceOtaUpgradeViewController, navigate back to ComponentViewController page)")
            UserSettings.shared.currentActiveGroupName = groupName
            UserSettings.shared.currentActiveComponentName = otaDevice.getDeviceName()
            UtilityManager.navigateToViewController(targetClass: ComponentViewController.self)
        } else {
            meshLog("DeviceOtaUpgradeViewController, navigate to FirmwareUpgradeViewController page)")
            if let otaDevice = self.otaDevice, otaDevice.getDeviceType() != .mesh {
                otaDevice.disconnect()
            }
            UtilityManager.navigateToViewController(targetClass: FirmwareUpgradeViewController.self)
        }
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func onRightBarButtonItemClick(_ sender: UIBarButtonItem) {
        meshLog("DeviceOtaUpgradeViewController, onRightBarButtonItemClick")
    }

    func startOtaUpgradingAnimating() {
        otaFirmwareUpgradeButton.isEnabled = false
        otaUpgradingActivityIndicator.startAnimating()
        otaUpgradingActivityIndicator.isHidden = false
    }

    func stopOtaUpgradingAnimating() {
        otaUpgradingActivityIndicator.stopAnimating()
        otaUpgradingActivityIndicator.isHidden = true
        otaFirmwareUpgradeButton.isEnabled = true
    }
}

extension DeviceOtaUpgradeViewController: CustomDropDownViewDelegate {
    func customDropDwonViewWillShowDropList(_ dropDownView: CustomDropDownView) {
        meshLog("customDropDwonViewWillShowDropList, dropListItems=\(dropDownView.dropListItems)")
    }

    func customDropDownViewDidUpdateValue(_ dropDownView: CustomDropDownView, selectedIndex: Int) {
        meshLog("customDropDownViewDidUpdateValue, selectedIndex=\(selectedIndex), text=\(String(describing: dropDownView.text))")
        if let selectedText = dropDownView.text, selectedText.count > 0 {
            selectedFwImageName = selectedText
            if !isPreparingForOta {
                otaFirmwareUpgradeButton.isEnabled = true
            }
            log("selected firmware image: \"\(selectedText)\"")
        } else {
            log("error: no firmware image selected, please copy vaild firmware images and try again later")
            selectedFwImageName = nil
            otaFirmwareUpgradeButton.isEnabled = false
        }
    }
}
