//
//  MeshOtaDfuViewController.swift
//  MeshApp
//
//  Created by Dudley Du on 2019/4/2.
//  Copyright © 2019 Cypress Semiconductor. All rights reserved.
//

import UIKit
import MeshFramework

class MeshOtaDfuViewController: UIViewController {
    @IBOutlet weak var dfuNavigationBar: UINavigationBar!
    @IBOutlet weak var dfuNavigationItem: UINavigationItem!
    @IBOutlet weak var dfuNavigationLeftButtonItem: UIBarButtonItem!
    @IBOutlet weak var dfuNavigationRightButtonItem: UIBarButtonItem!

    @IBOutlet weak var deviceNameView: UIView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var deviceTypeLable: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    @IBOutlet weak var meshDfuContentView: UIView!
    @IBOutlet weak var dfuTypeLabel: UILabel!
    @IBOutlet weak var dfuTypeDropDownButton: CustomDropDownButton!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var dfuFwImagesDropDownButton: CustomDropDownButton!
    @IBOutlet weak var dfuMetadataImagesDropDownButton: CustomDropDownButton!
    @IBOutlet weak var versionTitleLabel: UILabel!
    @IBOutlet weak var toDeviceTitleLable: UILabel!
    @IBOutlet weak var toDeviceChoseDropDownButton: CustomDropDownButton!

    @IBOutlet weak var buttonsTopView: UIView!
    @IBOutlet weak var buttunsLeftSubView: UIView!
    @IBOutlet weak var buttonsRightSubView: UIView!
    @IBOutlet weak var getDfuStatusButton: CustomLayoutButton!
    @IBOutlet weak var applyDfuButton: CustomLayoutButton!
    @IBOutlet weak var startUpgradeButton: CustomLayoutButton!
    @IBOutlet weak var stopUpgradeButton: CustomLayoutButton!

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var upgradeLogLabel: UILabel!
    @IBOutlet weak var upgradePercentageLabel: UILabel!
    @IBOutlet weak var upgradeLogTextView: UITextView!

    private var otaBasicDate = Date(timeIntervalSinceNow: 0)
    private var dfustatusTimer: Timer?

    private let OTA_GET_DFU_STATUS_MONITOR_INTERVAL = 30    // unit: seconds.

    var deviceName: String?
    var groupName: String?  // When groupName is not nil, it comes from CmponentViewControl; if groupName is nil, it comes from FirmwareUpgradeViewController.

    var tmpCBDeviceObject: AnyObject?     // only valid when the view controller active.

    var otaDevice: OtaDeviceProtocol?
    var otaFwImageNames: [String] = []
    var otaMetadataImageNames: [String] = []
    var selectedProxyToDeviceName: String?
    var selectedFwImageName: String?
    var selectedMetadataImageName: String?
    var otaDfuFirmware: Data?
    var otaDfuMetadata: OtaDfuMetadata?

    var isPreparingForOta: Bool = false
    var otaUpdatedStarted: Bool = false
    var lastTransferredPercentage: Int = -1  // indicates invalid value, will be udpated.

    override func viewDidLoad() {
        super.viewDidLoad()
        meshLog("MeshOtaDfuViewController, viewDidLoad")

        // Do any additional setup after loading the view.c
        otaDevice = OtaManager.shared.activeOtaDevice
        tmpCBDeviceObject = otaDevice?.otaDevice
        if deviceName == nil {
            deviceName = otaDevice?.getDeviceName() ?? MeshConstantText.UNKNOWN_DEVICE_NAME
        }

        notificationInit()
        viewInit()
    }

    override func viewDidDisappear(_ animated: Bool) {
        self.dfustatusTimer?.invalidate()
        self.dfustatusTimer = nil
        NotificationCenter.default.removeObserver(self)
        OtaManager.shared.resetOtaUpgradeStatus()
        tmpCBDeviceObject = nil
        super.viewDidDisappear(animated)
    }

    func getValidProxyToDeviceList() -> [String] {
        var validToDevices: [String] = []
        if let proxyDevice = self.otaDevice, let groups = MeshFrameworkManager.shared.getAllMeshNetworkGroups() {
            for group in groups {
                if group == MeshAppConstants.MESH_DEFAULT_ALL_COMPONENTS_GROUP_NAME ||  group.hasPrefix("dfu_") {
                    continue
                }

                let components = MeshFrameworkManager.shared.getMeshGroupComponents(groupName: group) ?? []
                validToDevices.append(contentsOf: components)
            }
            validToDevices.removeAll(where: { $0 == proxyDevice.getDeviceName() })
            return validToDevices
        }
        return []
    }

    func updateVersionAndToDeviceUI(dfuType: Int) {
        if dfuType == MeshDfuType.APP_OTA_TO_DEVICE {
            getDfuStatusButton.isEnabled = false
        } else {
            getDfuStatusButton.isEnabled = true
        }

        toDeviceTitleLable.isHidden = true
        toDeviceChoseDropDownButton.isHidden = true
        toDeviceChoseDropDownButton.isEnabled = false
        versionTitleLabel.isHidden = false
        versionTitleLabel.isHidden = false
    }

    func viewInit() {
        /*
         * Note, the Apply function has been implemented in the internal of the DFU devices, so not used any more.
         * When implementing any new desgin, the Apply button should be removed.
         */
        applyDfuButton.isEnabled = false
        applyDfuButton.isHidden = true

        dfuNavigationItem.title = "Mesh DFU"
        versionLabel.text = "Not Avaiable"
        upgradeLogTextView.text = ""
        log("OTA Upgrade view loaded")
        log("OTA device type: \(otaDevice?.getDeviceType() ?? OtaDeviceType.mesh)")
        log("OTA device name: \"\(otaDevice?.getDeviceName() ?? "Not Avaiable")\"")

        getDfuStatusButton.setTitleColor(UIColor.gray, for: .disabled)
        applyDfuButton.setTitleColor(UIColor.gray, for: .disabled)
        startUpgradeButton.setTitleColor(UIColor.gray, for: .disabled)
        stopUpgradeButton.setTitleColor(UIColor.gray, for: .disabled)

        dfuNavigationItem.rightBarButtonItem = nil  // not used currently.
        upgradeLogTextView.layer.borderWidth = 1
        upgradeLogTextView.layer.borderColor = UIColor.gray.cgColor
        upgradeLogTextView.isEditable = false
        upgradeLogTextView.isSelectable = false
        upgradeLogTextView.layoutManager.allowsNonContiguousLayout = false

        otaUpdatedStarted = false
        lastTransferredPercentage = -1  // indicates invalid value, will be udpated.
        otaProgressUpdated(percentage: 0.0)

        toDeviceChoseDropDownButton.dropDownItems = getValidProxyToDeviceList()
        toDeviceChoseDropDownButton.setSelection(select: 0)
        dfuTypeDropDownButton.dropDownItems = MeshDfuType.DFU_TYPE_TEXT_LIST
        if let dfuType = OtaUpgrader.activeDfuType, let dfuTypeString = MeshDfuType.getDfuTypeText(type: dfuType) {
            dfuTypeDropDownButton.setSelection(select: dfuTypeString)
        } else {
            dfuTypeDropDownButton.setSelection(select: MeshDfuType.getDfuTypeText(type: MeshDfuType.PROXY_DFU_TO_ALL)!)
        }

        selectedProxyToDeviceName = toDeviceChoseDropDownButton.selectedString
        updateVersionAndToDeviceUI(dfuType: MeshDfuType.getDfuType(by: dfuTypeDropDownButton.selectedString) ?? 0)

        guard let otaDevice = self.otaDevice else {
            meshLog("error: MeshOtaDfuViewController, viewInit, invalid otaDevice instance nil")
            log("error: invalid nil OTA device object")
            DispatchQueue.main.async {
                UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil OTA device object.", title: "Error")
            }
            return
        }
        deviceNameLabel.text = otaDevice.getDeviceName()
        deviceTypeLable.text = OtaManager.getOtaDeviceTypeString(by: otaDevice.getDeviceType())
        if otaDevice.getDeviceType() != .mesh {
            dfuTypeDropDownButton.isEnabled = false
        }
        stopAnimating()

        DispatchQueue.main.async {
            // read and update firmware image list.
            self.firmwareImagesInit()
            self.dfuFwImagesDropDownButton.dropDownItems = self.otaFwImageNames
            self.dfuMetadataImagesDropDownButton.dropDownItems = self.otaMetadataImageNames
            if self.otaFwImageNames.count > 0 {
                if let imageName = OtaUpgrader.activeDfuFwImageFileName, let index = self.otaFwImageNames.firstIndex(of: imageName) {
                    self.dfuFwImagesDropDownButton.setSelection(select: index)
                } else {
                    self.dfuFwImagesDropDownButton.setSelection(select: 0)
                }
                self.selectedFwImageName = self.dfuFwImagesDropDownButton.selectedString
                self.log("Selected image file name: \"\(self.selectedFwImageName!)\"for firmware OTA.")
            }
            if self.otaMetadataImageNames.count > 0 {
                if let metadataImageName = OtaUpgrader.activeDfuFwMetadataFileName, let index = self.otaMetadataImageNames.firstIndex(of: metadataImageName) {
                    self.dfuMetadataImagesDropDownButton.setSelection(select: index)
                } else {
                    self.dfuMetadataImagesDropDownButton.setSelection(select: 0)
                }
                self.dfuMetadataImagesDropDownButton.setSelection(select: 0)
                self.selectedMetadataImageName = self.dfuMetadataImagesDropDownButton.selectedString
                self.log("Selected image info file name: \"\(self.selectedMetadataImageName!)\" for firmware OTA.")
            }

            // [Dudley] test purpose.
            // Try to read and show the firmware version automatically if supported before starting the OTA upgrade process.
            // Or set prepareAndReadFwVersionAutomatically to false to let the App always run the OTA process directly after click the Firmware Upgrade button.
            let prepareAndReadFwVersionAutomatically = false
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
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_DFU_STATUS), object: nil)
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
                            let characterSet = CharacterSet(charactersIn: "0123456789.")
                            version = appVersion.trimmingCharacters(in: characterSet)
                        }
                        if !version.isEmpty {
                            versionLabel.text = version
                        }
                        if let device = self.otaDevice {
                            log("Device: \(device.getDeviceName()), Component Info: \(appInfo)")
                        }
                    } else if otaStatus.otaState == OtaUpgrader.OtaState.dataTransfer.rawValue {
                        if otaStatus.transferredImageSize == 0 {
                            log("OTA state: \(otaState.description) started.")
                        }
                        // Update and log firmware image download percentage value.
                        let percentage = Float(otaStatus.transferredImageSize) / Float(otaStatus.fwImageSize)
                        otaProgressUpdated(percentage: percentage)
                    } else if otaStatus.otaState == OtaUpgrader.OtaState.complete.rawValue {
                        otaUpdatedStarted = false
                        if !self.isPreparingForOta {
                            if otaStatus.otaSubState == OtaUpgrader.OtaState.apply.rawValue {
                                // OTA VERSION 2, apply completed.
                                // All DFU process has been finished, so try to stop DFU.
                                let error = OtaUpgrader.shared.otaDfuStop()     // try to stop any started DFU.
                                meshLog("MeshOtaDfuViewController, notificationHandler, Apply completed, do otaDfuStop, error:\(error)")
                                self.log("Try to stop DFU upgrading, \(error).", force: true)

                                if otaStatus.errorCode == MeshErrorCode.MESH_SUCCESS {
                                    self.log("done: OTA DFU Apply completed success.\n")
                                } else {
                                    self.log("error: OTA DFU Apply completed with failure. Error Code:\(otaStatus.errorCode), message:\(otaStatus.description)\n")
                                }
                                self.stopAnimating()
                            } else {
                                if MeshDfuType.getDfuType(by: dfuTypeDropDownButton.selectedString) == MeshDfuType.APP_OTA_TO_DEVICE {
                                    self.log("done: OTA image download completed success.")
                                    self.stopAnimating()
                                } else if OtaUpgrader.isDfuStarted {
                                    self.startAnimating()
                                    self.log("DFU upgrade started.")
                                    self.startDfuUpgradingTimer(fwDistrPhase: dfuTypeDropDownButton.selectedString)
                                }
                                /*
                                UtilityManager.showAlertDialogue(parentVC: self,
                                                                 message: "OTA process has finshed successfully, now starting DFU upgrading process.",
                                                                 title: "Success", completion: nil,
                                                                 action: UIAlertAction(title: "OK", style: .default,
                                                                                       handler: { (action) in
                                                                                        //self.onDfuNavigationLeftButtonItemClick(self.dfuNavigationLeftButtonItem)
                                                                 }))
                                 */
                            }
                        } else {
                            self.log("done: prepare for OTA upgrade is ready.\n")
                            if self.selectedFwImageName == nil || self.selectedMetadataImageName == nil {
                                self.log("Please select firmware image and metadata file, then click the Start DFU button to start DFU OTA\n")
                            }
                            // OTA upgrade process finished, navigate to previous view controller if success.
                            self.stopAnimating()
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
                        self.stopAnimating()
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
                                                                                        self.onDfuNavigationLeftButtonItemClick(self.dfuNavigationLeftButtonItem)
                                                                 }))
                            } else {
                                self.log("Please select the firmare image, then click the \"Start DFU\" button to try again.\n\n")
                            }
                        }
                        self.isPreparingForOta = false
                    } else {
                        // Log normal OTA upgrade failed step.
                        log("error: OTA state: \(otaState.description) failed. Error Code:\(otaStatus.errorCode), message:\(otaStatus.description)")
                    }
                }
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_DFU_STATUS):
            if let dfuStatus = MeshNotificationConstants.getDfuStatus(userInfo: userInfo) {
                meshLog("MeshOtaDfuViewController, notificationHandler, DFU device: \(dfuStatus.componentName), DFU status: \(dfuStatus.status), progress: \(dfuStatus.progress)%")
                switch dfuStatus.status {
                case OtaConstants.MESH_DFU_FW_DISTR_PHASE_IDLE:
                    meshLog("MeshOtaDfuViewController, notificationHandler, MESH_DFU_FW_DISTR_PHASE_IDLE, progress:\(dfuStatus.progress)%")
                    if MeshDfuType.getDfuType(by: dfuTypeDropDownButton.selectedString) != MeshDfuType.APP_OTA_TO_DEVICE {
                        if OtaUpgrader.isDfuStarted, OtaUpgrader.dfuState != OtaDfuState.DFU_STATE_UPLOADING {
                            self.log("DFU start uploading ...", force: true)
                            OtaUpgrader.dfuState = OtaDfuState.DFU_STATE_UPLOADING
                        }
                        self.otaDfuProgressUpdated(percentage: Double(dfuStatus.progress))
                        self.log("DFU uploading progress=\(dfuStatus.progress)%%", force: true)
                    }
                    break
                case OtaConstants.MESH_DFU_FW_DISTR_PHASE_TRANSFER_ACTIVE:
                    if dfuStatus.progress >= 100 {
                        self.otaDfuProgressUpdated(percentage: Double(100.0))
                        dfustatusTimer?.invalidate()
                        dfustatusTimer = nil
                    } else {
                        self.otaDfuProgressUpdated(percentage: Double(dfuStatus.progress))
                        if !(dfustatusTimer?.isValid ?? false) {
                            self.startAnimating()
                            startDfuUpgradingTimer(fwDistrPhase: "transfer DFU firmware image")
                        }
                    }
                    meshLog("MeshOtaDfuViewController, notificationHandler, MESH_DFU_FW_DISTR_PHASE_TRANSFER_ACTIVE, progress:\(dfuStatus.progress)%")
                    if OtaUpgrader.isDfuStarted, OtaUpgrader.dfuState != OtaDfuState.DFU_STATE_UPDATING {
                        self.log("DFU uploading completed", force: true)
                        self.log("DFU start updating ...", force: true)
                        OtaUpgrader.dfuState = OtaDfuState.DFU_STATE_UPDATING
                    }
                    self.log("DFU updating progress=\(dfuStatus.progress)%%", force: true)
                    break
                case OtaConstants.MESH_DFU_FW_DISTR_PHASE_TRANSFER_SUCCESS:
                    meshLog("MeshOtaDfuViewController, notificationHandler, MESH_DFU_FW_DISTR_PHASE_TRANSFER_SUCCESS, progress:\(dfuStatus.progress)%")
                    self.log("DFU updating completed", force: true)

                    self.otaDfuProgressUpdated(percentage: Double(100.0))
                    break
                case OtaConstants.MESH_DFU_FW_DISTR_PHASE_APPLY_ACTIVE:
                    meshLog("MeshOtaDfuViewController, notificationHandler, MESH_DFU_FW_DISTR_PHASE_APPLY_ACTIVE, progress:\(dfuStatus.progress)%")
                    self.log("DFU status=APPLY_ACTIVE, progress: \(dfuStatus.progress)%%.", force: true)
                    if dfuStatus.progress >= 100 {
                        self.otaDfuProgressUpdated(percentage: Double(100.0))
                    } else {
                        self.otaDfuProgressUpdated(percentage: Double(dfuStatus.progress))
                        if !(dfustatusTimer?.isValid ?? false) {
                            self.startAnimating()
                            startDfuUpgradingTimer(fwDistrPhase: "apply distribution DFU firmware image")
                        }
                    }
                    break
                case OtaConstants.MESH_DFU_FW_DISTR_PHASE_COMPLETED:
                    self.log("DFU distribution finished.", force: true)

                    OtaUpgrader.otaDfuProcessCompleted();

                    self.otaDfuProgressUpdated(percentage: 100.0)
                    dfustatusTimer?.invalidate()
                    dfustatusTimer = nil

                    /*
                    UtilityManager.showAlertDialogue(
                        parentVC: self,
                        message: "Mesh network DFU OTA upgrading has completed successfully, Do you want to apply the new firmware to all DFU target devices?\n\nClick \"OK\" button to Apply to the DFU target devices.\nClick \"Cancel\" button to exit. Or click the \"Apply DFU\" button later to apply to the DFU target devices later.",
                        title: "Success",
                        cancelHandler: { (action: UIAlertAction) in return },
                        okayHandler: { (action: UIAlertAction) in self.onApplyDfuButtonClick(self.applyDfuButton) }
                    )
                    */
                    self.otaUpdatedStarted = false
                    self.stopAnimating()
                    break
                default:
                    if dfuStatus.status == OtaConstants.MESH_DFU_FW_DISTR_PHASE_FAILED {
                        self.log("error: DFU status=FAILED, stopped.", force: true)
                    } else {
                        self.log("error: DFU process encounter error, error: \(dfuStatus.status).", force: true)
                    }

                    OtaUpgrader.otaDfuProcessCompleted();

                    dfustatusTimer?.invalidate()
                    dfustatusTimer = nil

                    self.otaUpdatedStarted = false
                    self.stopAnimating()
                    break
                }
            }

            self.getDfuStatusButton.isEnabled = true
        default:
            break
        }
    }

    func clearDfuGroups() {
        guard let networkName = MeshFrameworkManager.shared.getOpenedMeshNetworkName() else { return }
        let allGroups = MeshFrameworkManager.shared.getAllMeshNetworkGroups(networkName: networkName) ?? []
        for group in allGroups {
            if group.hasPrefix("dfu_") {
                MeshFrameworkManager.shared.deleteMeshGroup(groupName: group) { (networkName: String?, _ error: Int) in
                    guard error == MeshErrorCode.MESH_SUCCESS else {
                        meshLog("error: MeshOtaDfuViewController, clearDfuGroups, failed to delete DFU group:\(group), error:\(error)")
                        return
                    }
                    meshLog("MeshOtaDfuViewController, clearDfuGroups, delete DFU group:\(group) done")
                }
            }
        }
    }

    //
    // This function will try to connect to the OTA device, then try to discover OTA services,
    // try and read the AppInfo and update to UI if possible.
    // Also, to call this function alonely can help to verify the feature of connecting to different OTA devices.
    //
    func doOtaUpgradePrepare() {
        guard let otaDevice = self.otaDevice else {
            meshLog("error: MeshOtaDfuViewController, otaUpgradePrepare, invalid OTA device instance")
            log("error: invalid nil OTA device object")
            if let dfuTimer = self.dfustatusTimer, dfuTimer.isValid {
                return  // do not raise up the alter view when triggerred by the DFU upgrading get status timer.
            }
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil OTA device object.")
            return
        }

        isPreparingForOta = true
        startAnimating()
        let error = otaDevice.prepareOta()
        guard error == OtaErrorCode.SUCCESS else {
            stopAnimating()
            if error == OtaErrorCode.BUSYING {
                return
            }
            meshLog("error: MeshOtaDfuViewController, otaUpgradePrepare, failed to prepare for OTA")
            if let dfuTimer = self.dfustatusTimer, dfuTimer.isValid {
                return  // do not raise up the alter view when triggerred by the DFU upgrading get status timer.
            }
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
        otaMetadataImageNames.removeAll()
        let foundInFwImages = addFirmwareImageNames(atPath: meshSearchPath, prefix: fwImagePath)
        let foundInMesh = addFirmwareImageNames(atPath: fwImagesSearchPath, prefix: meshPath)
        let foundInDocuments = addFirmwareImageNames(atPath: defaultDocumentsPath)
        if !foundInFwImages, !foundInMesh, !foundInDocuments {
            meshLog("error: MeshOtaDfuViewController, firmwareImagesInit, no valid firmware images found")
            UtilityManager.showAlertDialogue(parentVC: self, message: "No valid firmware images found under App's \"Documents/mesh/fwImages\", \"Documents/mesh\" and  \"Documents\" directories. Please copy valid firmware images into your device, then try again later.", title: "Error")
        }
    }

    func addFirmwareImageNames(atPath: String, prefix: String? = nil) -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: atPath, isDirectory: &isDirectory)
        if !exists || !isDirectory.boolValue {
            meshLog("error: MeshOtaDfuViewController, addFirmwareImageNames, \(atPath) not exsiting")
            return false
        }

        let namePrefix = ((prefix == nil) || (prefix?.isEmpty ?? true)) ? "" : (prefix! + "/")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: atPath) {
            for fileName in files {
                // ecdsa256_genkey.exe tool will auto append .signed extension to the signed image file name.
                if fileName.hasSuffix(".bin") || fileName.hasSuffix(".bin.signed") {
                    otaFwImageNames.append(namePrefix + fileName)
                    meshLog("MeshOtaDfuViewController, addFirmwareImageNames, found image: \(namePrefix + fileName)")
                } else if fileName.hasPrefix("image_info") || fileName.hasSuffix("image_info") {
                    otaMetadataImageNames.append(namePrefix + fileName)
                    meshLog("MeshOtaDfuViewController, addFirmwareImageNames, found metadata image: \(namePrefix + fileName)")
                }
            }
        }

        if otaFwImageNames.isEmpty, otaMetadataImageNames.isEmpty {
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
        if percentage <= 0.0 {
            upgradePercentageLabel.text = String(format: "%d%%", latestPercentage)
        } else {
            upgradePercentageLabel.text = String(format: "%d", latestPercentage) + ((latestPercentage >= 100) ? "%, Completed" : "%, Downloading")
        }
        progressView.progress = pct

        if otaUpdatedStarted, lastTransferredPercentage != latestPercentage {
            log("transferred size: \(latestPercentage)%%")
            lastTransferredPercentage = latestPercentage
        }
    }

    func otaDfuProgressUpdated(percentage: Double) {
        if percentage > 100.0 {
            upgradePercentageLabel.text = "100%, DFU Completed Success"
            progressView.progress = 1.0
        } else {
            if OtaUpgrader.dfuState == OtaDfuState.DFU_STATE_UPDATING {
                upgradePercentageLabel.text = "\(String.init(format: "%d", Int(percentage.rounded())))%, DFU Distributing"
            } else if OtaUpgrader.dfuState == OtaDfuState.DFU_STATE_UPLOADING {
                upgradePercentageLabel.text = "\(String.init(format: "%d", Int(percentage.rounded())))%, DFU Uploading"
            } else {
                upgradePercentageLabel.text = "\(String.init(format: "%d", Int(percentage.rounded())))%, DFU Upgrading"
            }
            progressView.progress = Float(percentage.rounded() / 100.0)
        }
    }

    func log(_ message: String, force: Bool = false) {
        if !force, let timer = self.dfustatusTimer, timer.isValid {
            return  // disable the log when in DFU Upgrading monitoring state.
        }
        let seconds = Date().timeIntervalSince(otaBasicDate)
        let msg = String(format: "[%.3f] \(message)\n", seconds)
        upgradeLogTextView.text += msg
        let bottom = NSRange(location: upgradeLogTextView.text.count, length: 1)
        upgradeLogTextView.scrollRangeToVisible(bottom)
    }

    func startAnimating() {
        applyDfuButton.isEnabled = false
        startUpgradeButton.isEnabled = false
        stopUpgradeButton.isEnabled = true
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
    }

    func stopAnimating() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        applyDfuButton.isEnabled = true
        startUpgradeButton.isEnabled = true
        stopUpgradeButton.isEnabled = true
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func onDfuNavigationLeftButtonItemClick(_ sender: UIBarButtonItem) {
        meshLog("MeshOtaDfuViewController, onDfuNavigationLeftButtonItemClick")
        OtaManager.shared.resetOtaUpgradeStatus()
        if let otaDevice = self.otaDevice, otaDevice.getDeviceType() == .mesh, let groupName = self.groupName {
            meshLog("MeshOtaDfuViewController, navigate back to ComponentViewController page)")
            UserSettings.shared.currentActiveGroupName = groupName
            UserSettings.shared.currentActiveComponentName = otaDevice.getDeviceName()
            UtilityManager.navigateToViewController(targetClass: ComponentViewController.self)
        } else {
            meshLog("MeshOtaDfuViewController, navigate to FirmwareUpgradeViewController page)")
            if let otaDevice = self.otaDevice, otaDevice.getDeviceType() != .mesh {
                otaDevice.disconnect()
            }
            UtilityManager.navigateToViewController(targetClass: FirmwareUpgradeViewController.self)
        }
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func onDfuNavigationRightButtonItemClick(_ sender: UIBarButtonItem) {
    }

    @IBAction func onDfuTypeDropDownButtonClick(_ sender: CustomDropDownButton) {
        dfuTypeDropDownButton.showDropList(width: 220, parent: self) {
            meshLog("\(self.dfuTypeDropDownButton.selectedIndex), \(self.dfuTypeDropDownButton.selectedString)")
            self.log("Selected DFU type: \(self.dfuTypeDropDownButton.selectedString) for firmware OTA.")
            self.updateVersionAndToDeviceUI(dfuType: MeshDfuType.getDfuType(by: self.dfuTypeDropDownButton.selectedString) ?? 0)

            OtaUpgrader.storeActiveDfuInfo(dfuType: MeshDfuType.getDfuType(by: self.dfuTypeDropDownButton.selectedString),
                                           fwImageFileName: self.dfuFwImagesDropDownButton.selectedString,
                                           fwMetadataFileName: self.dfuMetadataImagesDropDownButton.selectedString)
        }
    }

    @IBAction func onToDeviceChoseDropDownButtonCLick(_ sender: CustomDropDownButton) {
        let width = Int(meshDfuContentView.bounds.size.width) - 16
        toDeviceChoseDropDownButton.showDropList(width: width, parent: self) {
            meshLog("selectedProxyToDevice, \(self.toDeviceChoseDropDownButton.selectedIndex), \(self.toDeviceChoseDropDownButton.selectedString)")
            self.log("Selected proxy to device name: \(self.toDeviceChoseDropDownButton.selectedString)")
            self.selectedProxyToDeviceName = self.toDeviceChoseDropDownButton.selectedString
        }
    }


    @IBAction func onDfuFwImagesDropDownButtonClick(_ sender: CustomDropDownButton) {
        let width = Int(meshDfuContentView.bounds.size.width) - 16
        dfuFwImagesDropDownButton.showDropList(width: width, parent: self) {
            meshLog("selectedFwImageName, \(self.dfuFwImagesDropDownButton.selectedIndex), \(self.dfuFwImagesDropDownButton.selectedString)")
            self.log("Selected image name: \(self.dfuFwImagesDropDownButton.selectedString) for firmware OTA.")
            self.selectedFwImageName = self.dfuFwImagesDropDownButton.selectedString
            if let firmwareFile = self.selectedFwImageName {
                self.otaDfuFirmware = OtaUpgrader.readParseFirmwareImage(at: firmwareFile)
            }

            OtaUpgrader.storeActiveDfuInfo(dfuType: MeshDfuType.getDfuType(by: self.dfuTypeDropDownButton.selectedString),
                                           fwImageFileName: self.dfuFwImagesDropDownButton.selectedString,
                                           fwMetadataFileName: self.dfuMetadataImagesDropDownButton.selectedString)
        }
    }

    @IBAction func onDfuMetadataImagesDropDownButtonClick(_ sender: CustomDropDownButton) {
        let width = Int(meshDfuContentView.bounds.size.width) - 16
        dfuMetadataImagesDropDownButton.showDropList(width: width, parent: self) {
            meshLog("selectedMetadataImageName, \(self.dfuMetadataImagesDropDownButton.selectedIndex), \(self.dfuMetadataImagesDropDownButton.selectedString)")
            self.log("Selected image info name: \(self.dfuMetadataImagesDropDownButton.selectedString) for firmware OTA.")
            self.selectedMetadataImageName = self.dfuMetadataImagesDropDownButton.selectedString
            if let metadataFile = self.selectedMetadataImageName {
                self.otaDfuMetadata = OtaUpgrader.readParseMetadataImage(at: metadataFile)
            }

            OtaUpgrader.storeActiveDfuInfo(dfuType: MeshDfuType.getDfuType(by: self.dfuTypeDropDownButton.selectedString),
                                           fwImageFileName: self.dfuFwImagesDropDownButton.selectedString,
                                           fwMetadataFileName: self.dfuMetadataImagesDropDownButton.selectedString)
        }
    }

    @IBAction func onGetDfuStatusButtonClick(_ sender: CustomLayoutButton) {
        meshLog("MeshOtaDfuViewController, onGetDfuStatusButtonClick")
        self.getDfuStatusButton.isEnabled = false
        if self.otaDevice?.otaDevice == nil {
            // The CoreBlutooth peripheral object will been cleaned when disconnected.
            // So, if use keep state this OTA page, try to restore the peripheral object to speed up the process.
            self.otaDevice?.otaDevice = tmpCBDeviceObject
        }
        guard let _ = self.deviceName, let otaDevice = self.otaDevice else {
            self.getDfuStatusButton.isEnabled = true
            meshLog("error: MeshOtaDfuViewController, onGetDfuStatusButtonClick, invalid device name, nil")
            self.log("error: failed to get DFU status with invalid componenent name, nil")
            return
        }

        OtaUpgrader.storeActiveDfuInfo(dfuType: MeshDfuType.getDfuType(by: self.dfuTypeDropDownButton.selectedString),
                                       fwImageFileName: self.dfuFwImagesDropDownButton.selectedString,
                                       fwMetadataFileName: self.dfuMetadataImagesDropDownButton.selectedString)

        let error = OtaUpgrader.shared.otaGetDfuStatus(for: otaDevice)
        guard error == MeshErrorCode.MESH_SUCCESS else {
            self.getDfuStatusButton.isEnabled = true
            meshLog("error: MeshOtaDfuViewController, onGetDfuStatusButtonClick, failed to call meshClientDfuGetStatus, error=\(error)")
            self.log("error: failed to send DFU get status command, error:\(error)\(error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED ? ". Device not connected." : "").", force: true)

            if error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED {
                self.log("Please try a little alter after the device has been connected and ready for OTA.\n")
                self.otaUpgradePrepare()
                if let dfuTimer = self.dfustatusTimer, dfuTimer.isValid {
                    return  // do not raise up the alter view when triggerred by the DFU upgrading get status timer.
                }
                UtilityManager.showAlertDialogue(parentVC: self, message: "Device not connected, please retry a little later after the device has been connected and ready for OTA.", title: "Error")
            }
            return
        }
    }

    @IBAction func onApplyDfuButtonClick(_ sender: CustomLayoutButton) {
        meshLog("MeshOtaDfuViewController, onApplyDfuButtonClick")
        #if true
        /*
         * Note, the Apply function has been implemented in the internal of the DFU devices, so not used any more.
         * When implementing any new desgin, the Apply button should be removed.
         */
        UtilityManager.showAlertDialogue(parentVC: self, message: "DFU firmware Apply function has been implemented in mesh devices, so this function is not required and do nothing currently. Please ignored this button in the UI if exists.", title: "Warning")
        return
        #else
        if self.otaDevice?.otaDevice == nil {
            // The CoreBlutooth peripheral object will been cleaned when disconnected.
            // So, if use keep state this OTA page, try to restore the peripheral object to speed up the process.
            self.otaDevice?.otaDevice = tmpCBDeviceObject
        }
        guard let _ = self.deviceName, let otaDevice = self.otaDevice else {
            meshLog("error: MeshOtaDfuViewController, onApplyDfuButtonClick, invalid device name, nil")
            return
        }

        let error = OtaUpgrader.shared.otaDfuApply(for: otaDevice)
        guard error == MeshErrorCode.MESH_SUCCESS else {
            meshLog("error: MeshOtaDfuViewController, onApplyDfuButtonClick, failed to do otaDfuApply, error=\(error)\(error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED ? ". Device not connected." : "")")
            self.log("error: failed to send DFU Apply command, error:\(error)\(error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED ? ". Device not connected." : "")")

            if error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED {
                self.log("Please try a little alter after the device has been connected and ready for OTA.\n")
                self.otaUpgradePrepare()
                UtilityManager.showAlertDialogue(parentVC: self, message: "Device not connected, please retry a little later after the device has been connected and ready for OTA.", title: "Error")
            }
            return
        }
        meshLog("MeshOtaDfuViewController, onApplyDfuButtonClick, OtaUpgrader.shared.otaDfuApply called")
        #endif
    }

    @IBAction func onStartUpgradeButtonClick(_ sender: CustomLayoutButton) {
        meshLog("MeshOtaDfuViewController, onStartUpgradeButtonClick")
        let selectedDfuType = MeshDfuType.getDfuType(by: dfuTypeDropDownButton.selectedString)!
        guard let componentName = self.deviceName, let otaDevice = self.otaDevice else {
            meshLog("error: MeshOtaDfuViewController, onStartUpgradeButtonClick, invalid device or device name, nil")
            log("error: invalid nil OTA device instance")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil OTA device instance.")
            return
        }
        guard let firmwareFile = self.selectedFwImageName, let otaDfuFirmware = OtaUpgrader.readParseFirmwareImage(at: firmwareFile) else {
                meshLog("error: MeshOtaDfuViewController, onStartUpgradeButtonClick, failed to read and parse firmware image file")
                self.log("error: failed to read and parse firmware image file")
                return
        }
        guard let metadataFile = self.selectedMetadataImageName, let otaDfuMetadata = OtaUpgrader.readParseMetadataImage(at: metadataFile) else {
            meshLog("error: MeshOtaDfuViewController, onStartUpgradeButtonClick, failed to read and parse firmware metadata file")
            self.log("error: failed to read and parse firmware metadata file")
            return
        }
        meshLog("MeshOtaDfuViewController, onStartUpgradeButtonClick, read new firmwareFile=\(firmwareFile) metadataFile=\(metadataFile), firmware version=\(otaDfuMetadata.firmwareVersionMajor).\(otaDfuMetadata.firmwareVersionMinor).\(otaDfuMetadata.firmwareVersionRevision), DFU Type=\(selectedDfuType)")

        otaUpdatedStarted = false
        lastTransferredPercentage = -1  // indicates invalid value, will be udpated.
        otaProgressUpdated(percentage: 0.0)
        if self.otaDevice?.otaDevice == nil {
            // The CoreBlutooth peripheral object will been cleaned when disconnected.
            // So, if use keep state this OTA page, try to restore the peripheral object to speed up the process.
            self.otaDevice?.otaDevice = tmpCBDeviceObject
        }

        self.isPreparingForOta = false
        self.startAnimating()
        let error = OtaUpgrader.shared.otaDfuStart(for: otaDevice, dfuType: selectedDfuType, fwImage: otaDfuFirmware, metadata: otaDfuMetadata)
        guard error == MeshErrorCode.MESH_SUCCESS else {
            self.stopAnimating()
            meshLog("error: MeshOtaDfuViewController, onStartUpgradeButtonClick, failed to call otaDfuStart for \(componentName), error=\(error)")
            self.log("error: failed to start OTA process, error:\(error).\(error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED ? " Mesh network not connected." : "")")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to start OTA process. Error Code: \(error).\(error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED ? " Mesh network not connected." : "")", title: "Error")
            return
        }
        meshLog("MeshOtaDfuViewController, onStartUpgradeButtonClick, OTA process running")
        self.otaUpdatedStarted = true
        if selectedDfuType == MeshDfuType.APP_OTA_TO_DEVICE {
            self.log("OTA upgrade process started")
        } else {
            self.log("\(MeshDfuType.getDfuTypeText(type: selectedDfuType) ?? "DFU") process started")
            //self.startDfuUpgradingTimer(fwDistrPhase: self.dfuTypeDropDownButton.selectedString)
        }
    }

    @IBAction func onStopUpgradeButtonClick(_ sender: CustomLayoutButton) {
        meshLog("MeshOtaDfuViewController, onStopUpgradeButtonClick")
        let selectedDfuType = MeshDfuType.getDfuType(by: dfuTypeDropDownButton.selectedString)!
        if self.otaDevice?.otaDevice == nil {
            // The CoreBlutooth peripheral object will been cleaned when disconnected.
            // So, if use keep state this OTA page, try to restore the peripheral object to speed up the process.
            self.otaDevice?.otaDevice = tmpCBDeviceObject
        }
        guard let _ = self.deviceName, let _ = self.otaDevice else {
            meshLog("error: MeshOtaDfuViewController, onStopUpgradeButtonClick, invalid device or device name, nil")
            log("error: invalid nil OTA device instance")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil OTA device instance.")
            return
        }

        dfustatusTimer?.invalidate()
        dfustatusTimer = nil
        self.stopAnimating()
        let error = OtaUpgrader.shared.otaDfuStop()
        guard error == MeshErrorCode.MESH_SUCCESS else {
            meshLog("error: MeshOtaDfuViewController, onStopUpgradeButtonClick, failed to call meshClientDfuStop, error=\(error)\(error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED ? ". Device not connected." : "")")
            self.log("error: failed to send DFU stop command, error:\(error)\(error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED ? ". Device not connected." : "")")

            if error == MeshErrorCode.MESH_ERROR_NOT_CONNECTED {
                self.log("Please try a little alter after the device has been connected and ready for OTA.\n")
                self.otaUpgradePrepare()
                UtilityManager.showAlertDialogue(parentVC: self, message: "Device not connected, please retry a little later after the device has been connected and ready for OTA.", title: "Error")
            }
            return
        }
        meshLog("MeshOtaDfuViewController, onStopUpgradeButtonClick, done: DFU stop command send success")
        self.log("done: OTA DFU upgrade stopped by user.")
    }

    func startDfuUpgradingTimer(fwDistrPhase: String = "") {
        dfustatusTimer?.invalidate()
        dfustatusTimer = nil
        if #available(iOS 10.0, *) {
            dfustatusTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(OTA_GET_DFU_STATUS_MONITOR_INTERVAL), repeats: true, block: { (timer) in
                self.meshDfuStatusTimerHandler(timer)
            })
        } else {
            dfustatusTimer = Timer.scheduledTimer(timeInterval: TimeInterval(OTA_GET_DFU_STATUS_MONITOR_INTERVAL),    // Update DFU status in every 5 seconds.
                target: self,
                selector: #selector(meshDfuStatusTimerHandler),
                userInfo: nil,
                repeats: true)
        }
    }

    @objc private func meshDfuStatusTimerHandler(_ timer: Timer) {
        DispatchQueue.main.async {
            self.startAnimating() // DFU Upgrading still in progress.
            guard self.getDfuStatusButton.isEnabled else {
                return  // busying, try to get the DFU status in next timer slot.
            }
            self.onGetDfuStatusButtonClick(self.getDfuStatusButton)
        }
    }
}
