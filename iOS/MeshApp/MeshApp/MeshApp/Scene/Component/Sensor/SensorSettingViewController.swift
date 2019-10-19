/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Sensor setting view controller implementation.
 */

import UIKit
import MeshFramework

fileprivate enum SensorSettingCustomDropDownViewTag: Int {
    case publishTo
    case cadenceMeasurementType
    case cadenceMeasurementLoaction
    case cadencePublishPeriod
    case sensorProperties
}

class SensorSettingViewController: UIViewController {
    @IBOutlet weak var titleNavigationItem: UINavigationItem!
    @IBOutlet weak var leftNavigationBarButtonitem: UIBarButtonItem!
    @IBOutlet weak var rightNavigationBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var publishSettingsCardView: CustomCardView!
    @IBOutlet weak var cadenceSettingsCardView: CustomCardView!
    @IBOutlet weak var SensorSettingsCardView: CustomCardView!
    @IBOutlet weak var publishToDropListButton: CustomDropDownButton!
    @IBOutlet weak var publishPeriodTimeTextView: UITextField!
    @IBOutlet weak var publishSetButton: UIButton!

    @IBOutlet weak var cadenceStatusTriggerTypeDropDwonButton: CustomDropDownButton!

    @IBOutlet weak var cadenceSettingsFastCadenceButton: UIButton!
    @IBOutlet weak var cadenceSettingsTriggersButton: UIButton!
    @IBOutlet weak var cadenceSetButton: UIButton!

    @IBOutlet weak var fastCadenceMeasurementDropListbutton: CustomDropDownButton!
    @IBOutlet weak var fastCadenceRangeMinValueTextView: UITextField!
    @IBOutlet weak var fastCadenceRangeMaxValueTextView: UITextField!
    @IBOutlet weak var fastCadencePublishPeriodDropListButton: CustomDropDownButton!

    @IBOutlet weak var fastCadenceView: UIView!
    @IBOutlet weak var triggerView: UIView!
    @IBOutlet weak var triggerPublishNoMoreThanSecondsTextView: UITextField!
    @IBOutlet weak var triggerPublishIncreaseUnitTextView: UITextField!
    @IBOutlet weak var triggerPublishDecreaseUnitTextView: UITextField!

    @IBOutlet weak var sensorPropertyDropListButton: CustomDropDownButton!
    @IBOutlet weak var sensorSettingPropertyValueTextView: UITextField!
    @IBOutlet weak var sensorSettingSetButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!

    var groupName: String?
    var componentName: String?
    var componentType: Int = MeshConstants.MESH_COMPONENT_UNKNOWN
    var propertyId: Int = MeshPropertyId.UNKNOWN

    var fastCadenceViewRect: CGRect?
    var triggerViewRect: CGRect?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        notificationInit()
        viewInit()
    }

    func viewInit() {
        titleNavigationItem.rightBarButtonItem = nil

        cadenceSettingsFastCadenceButton.titleEdgeInsets.left = 10
        cadenceSettingsTriggersButton.titleEdgeInsets.left = 10

        cadenceSettingsFastCadenceButton.setImage(UIImage(named: MeshAppImageNames.checkboxFilledImage), for: .selected)
        cadenceSettingsTriggersButton.setImage(UIImage(named: MeshAppImageNames.checkboxFilledImage), for: .selected)

        sensorSettingSetButton.setTitleColor(UIColor.lightGray, for: .disabled)

        publishPeriodTimeTextView.delegate = self
        fastCadenceRangeMinValueTextView.delegate = self
        fastCadenceRangeMaxValueTextView.delegate = self
        triggerPublishNoMoreThanSecondsTextView.delegate = self
        triggerPublishIncreaseUnitTextView.delegate = self
        triggerPublishDecreaseUnitTextView.delegate = self
        sensorSettingPropertyValueTextView.delegate = self

        initDefaultValues()
    }

    func initDefaultValues() {
        guard let componentName = self.componentName else {
            return
        }

        publishToDropListButton.dropDownItems = getPublishToTargets()
        cadenceStatusTriggerTypeDropDwonButton.dropDownItems = MeshControl.TRIGGER_TYPE_TEXT_LIST
        fastCadenceMeasurementDropListbutton.dropDownItems = MeshControl.MEASUREMENT_TYPE_TEXT_LIST
        fastCadencePublishPeriodDropListButton.dropDownItems = MeshControl.FAST_CADENCE_PERIOD_DIVISOR_TEXT_LIST
        let sensorSettingProperties = getSensorSettingProperties()
        sensorPropertyDropListButton.dropDownItems = sensorSettingProperties

        onFastCadenceButtonSelected(isSelected: cadenceSettingsFastCadenceButton.isSelected)
        onTriggerButtonSelected(isSelected: cadenceSettingsTriggersButton.isSelected)
        sensorSettingEnable(isEnabled: !sensorSettingProperties.isEmpty)

        // initialize Publication Settings.
        if let publishTarget = MeshFrameworkManager.shared.meshClientGetPublicationTarget(componentName: componentName, isClient: false, method: MeshControl.METHOD_SENSOR) {
            publishToDropListButton.setSelection(select: publishTarget)
        } else {
            publishToDropListButton.setSelection(select: 0)
        }
        let publishPeriod = MeshFrameworkManager.shared.meshClientGetPublicationPeriod(componentName: componentName, isClient: false, method: MeshControl.METHOD_SENSOR)
        if publishPeriod > 0 {
            publishPeriodTimeTextView.text = "\(publishPeriod)"
        }

        // initialize Cadence Settings.
        if let cadenceSettings = MeshFrameworkManager.shared.meshClientSensorCadenceGet(deviceName: componentName, propertyId: self.propertyId) {
            if let triggerTypeText = MeshControl.getTriggerTypeText(type: cadenceSettings.triggerType) {
                cadenceStatusTriggerTypeDropDwonButton.setSelection(select: triggerTypeText)
            } else {
                cadenceStatusTriggerTypeDropDwonButton.setSelection(select: 0)
            }

            // settings for Fast Cadence.
            fastCadenceMeasurementDropListbutton.setSelection(select: MeshControl.MEASUREMENT_TYPE_INSIDE)
            fastCadenceRangeMinValueTextView.text = "\(cadenceSettings.fastCadenceLow)"
            fastCadenceRangeMaxValueTextView.text = "\(cadenceSettings.fastCadenceHigh)"
            if let divisorText = MeshControl.getFastCadencePeriodDivisorText(divisor: cadenceSettings.fastCadencePeriodDivisor) {
                fastCadencePublishPeriodDropListButton.setSelection(select: divisorText)
            } else {
                fastCadencePublishPeriodDropListButton.setSelection(select: MeshControl.DEFAULT_FAST_CADENCE_PERIOD_DIVISOR)
            }

            // settings for Triggers.
            triggerPublishNoMoreThanSecondsTextView.text = "\(cadenceSettings.minInterval)"
            triggerPublishIncreaseUnitTextView.text = "\(cadenceSettings.triggerDeltaUp)"
            triggerPublishDecreaseUnitTextView.text = "\(cadenceSettings.triggerDeltaDown)"
        }

        // initialize sensor property settings.
        sensorPropertyDropListButton.setSelection(select: 0)
    }

    func getPublishToTargets() -> [String] {
        var targets: [String] = []
        if let groups = MeshFrameworkManager.shared.getAllMeshNetworkGroups() {
            for group in groups {
                targets.append(group)
            }
        }
        targets.append(contentsOf: MeshControl.PUBLICATION_TARGETS)
        return targets
    }

    func getSensorSettingProperties() -> [String] {
        var properties: [String] = []
        guard let componentName = self.componentName else {
            return properties
        }

        if let settingPropertyIds = MeshFrameworkManager.shared.meshClientSensorSettingGetPropertyIds(componentName: componentName, propertyId: self.propertyId) {
            for id in settingPropertyIds {
                properties.append(MeshPropertyId.getPropertyIdText(id))
            }
        }
        return properties
    }

    func onTriggerButtonSelected(isSelected: Bool) {
        let color: UIColor = isSelected ? UIColor.black : UIColor.lightGray
        for viewItem in triggerView.subviews {
            if let label = viewItem as? UILabel {
                label.textColor = color
            } else if let textFeild = viewItem as? UITextField {
                textFeild.textColor = color
            }
        }

        triggerPublishNoMoreThanSecondsTextView.isEnabled = isSelected
        triggerPublishIncreaseUnitTextView.isEnabled = isSelected
        triggerPublishDecreaseUnitTextView.isEnabled = isSelected
    }

    func onFastCadenceButtonSelected(isSelected: Bool) {
        let color: UIColor = isSelected ? UIColor.black : UIColor.lightGray
        for viewItem in fastCadenceView.subviews {
            if let label = viewItem as? UILabel {
                label.textColor = color
            } else if let textFeild = viewItem as? UITextField {
                textFeild.textColor = color
            }
        }

        fastCadenceMeasurementDropListbutton.isEnabled = isSelected
        fastCadenceRangeMinValueTextView.isEnabled = isSelected
        fastCadenceRangeMaxValueTextView.isEnabled = isSelected
        fastCadencePublishPeriodDropListButton.isEnabled = isSelected
    }

    func sensorSettingEnable(isEnabled: Bool) {
        let color: UIColor = isEnabled ? UIColor.black : UIColor.lightGray
        for viewItem in SensorSettingsCardView.subviews {
            if let label = viewItem as? UILabel {
                label.textColor = color
            } else if let textFeild = viewItem as? UITextField {
                textFeild.textColor = color
            }
        }

        sensorPropertyDropListButton.isEnabled = isEnabled
        sensorSettingPropertyValueTextView.isEnabled = isEnabled
        sensorSettingSetButton.isEnabled = isEnabled
        SensorSettingsCardView.isHidden = !isEnabled
    }

    func notificationInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: UIWindow.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: UIWindow.keyboardWillHideNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED), object: nil)
    }

    @objc func notificationHandler(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        switch notification.name {
        case UIWindow.keyboardWillShowNotification:
            adjustingHeightWithKeyboard(show: true, notification: notification)
        case UIWindow.keyboardWillHideNotification:
            adjustingHeightWithKeyboard(show: false, notification: notification)
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
        default:
            break
        }
    }


    @IBAction func onFastCadenceSettingButtonClick(_ sender: UIButton) {
        cadenceSettingsFastCadenceButton.isSelected = !cadenceSettingsFastCadenceButton.isSelected
        onFastCadenceButtonSelected(isSelected: cadenceSettingsFastCadenceButton.isSelected)
    }

    @IBAction func onTriggerSettingButtonClick(_ sender: UIButton) {
        cadenceSettingsTriggersButton.isSelected = !cadenceSettingsTriggersButton.isSelected
        onTriggerButtonSelected(isSelected: cadenceSettingsTriggersButton.isSelected)
    }

    // MARK: - UI operations

    @IBAction func onPublishToDropListButtonClick(_ sender: CustomDropDownButton) {
        publishToDropListButton.showDropList(width: 220, parent: self) {
            print("\(self.publishToDropListButton.selectedIndex), \(self.publishToDropListButton.selectedString)")
        }
    }

    @IBAction func onCadenceStatusTriggerTypeDropDwonButtonClick(_ sender: CustomDropDownButton) {
        cadenceStatusTriggerTypeDropDwonButton.showDropList(width: 150, parent: self) {
            print("onCadenceStatusTriggerTypeDropDwonButtonClick, \(self.cadenceStatusTriggerTypeDropDwonButton.selectedIndex), \(self.cadenceStatusTriggerTypeDropDwonButton.selectedString)")
        }
    }

    @IBAction func onFastCadenceMeasurementDropListbuttonClick(_ sender: CustomDropDownButton) {
        fastCadenceMeasurementDropListbutton.showDropList(width: 150, parent: self) {
            print("fastCadenceMeasurementDropListbutton, \(self.fastCadenceMeasurementDropListbutton.selectedIndex), \(self.fastCadenceMeasurementDropListbutton.selectedString)")
        }
    }

    @IBAction func onFastCadencePublishPeriodDropListButtonClick(_ sender: CustomDropDownButton) {
        fastCadencePublishPeriodDropListButton.showDropList(width: 100, parent: self) {
            print("fastCadencePublishPeriodDropListButton, \(self.fastCadencePublishPeriodDropListButton.selectedIndex), \(self.fastCadencePublishPeriodDropListButton.selectedString)")
        }
    }

    @IBAction func onSensorPropertyDropListButtonClick(_ sender: CustomDropDownButton) {
        sensorPropertyDropListButton.showDropList(width: 220, parent: self) {
            print("sensorPropertyDropListButton, \(self.sensorPropertyDropListButton.selectedIndex), \(self.sensorPropertyDropListButton.selectedString)")
        }
    }

    // MARK: - apply setting data to the remote device

    @IBAction func onPublishSetButtonClick(_ sender: UIButton) {
        print("SensorSettingViewController, onPublishSetButtonClick")
        guard let componentName = self.componentName else {
            print("error: SensorSettingViewController, onPublishSetButtonClick, invalid nil mesh component name")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil mesh component name.")
            return
        }
        guard let periodText = publishPeriodTimeTextView.text, !periodText.isEmpty else {
            print("error: SensorSettingViewController, onPublishSetButtonClick, period textField is empty or not set")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Please input the publish period time firstly before click the Publsh Set button.")
            return
        }

        let publishTarget = publishToDropListButton.selectedString
        let publishPeriod = Int(periodText) ?? MeshConstants.MESH_DEFAULT_PUBLISH_PERIOD
        print("SensorSettingViewController, onPublishSetButtonClick, input values, publishTarget:\(publishTarget), publishPeriod:\(publishPeriod), groupName=\(String(describing: self.groupName))")
        if let groupName = self.groupName, groupName != publishTarget {
            UtilityManager.showAlertDialogue(parentVC: self,
                                             message: "Are you sure to set publish target to \"\(publishTarget)\" instead of active group \"\(groupName)\"?\nClick OK to continue.\nClick Cancle to change the publish target.",
                title: "Warnning",
                cancelHandler: { (action: UIAlertAction) in return },
                okayHandler: { (action: UIAlertAction) in
                    DispatchQueue.main.async {
                        self.doPublishSet(componentName: componentName, publishTargetName: publishTarget, publishPeriod: publishPeriod)
                    }
            }
            )
        }

        doPublishSet(componentName: componentName, publishTargetName: publishTarget, publishPeriod: publishPeriod)
    }
    func doPublishSet(componentName: String, publishTargetName: String, publishPeriod: Int) {
        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: SensorViewController, doPublishSet, failed to connect to mesh network, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the mesh network. Error Code: \(error).")
                return
            }

            var error = MeshFrameworkManager.shared.setMeshPublicationConfiguration()
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: SensorSettingViewController, onPublishSetButtonClick, failed to call setMeshPublicationConfiguration API, error:\(error)")
                if error == MeshErrorCode.MESH_ERROR_INVALID_STATE {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Mesh network is busying, please try again a little later.")
                } else {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to set mesh publication configuration. Error Code: \(error).")
                }
                return
            }

            error = MeshFrameworkManager.shared.configureMeshPublication(componentName: componentName, isClient: false, method: MeshControl.METHOD_SENSOR, targetName: publishTargetName, publishPeriod: publishPeriod)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: SensorSettingViewController, onPublishSetButtonClick, failed to call setMeshPublicationConfiguration API, error:\(error)")
                if error == MeshErrorCode.MESH_ERROR_INVALID_STATE {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Mesh network is busying, please try again a little later.")
                } else {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to set mesh publication configuration. Error Code: \(error).")
                }
                return
            }

            print("SensorSettingViewController, onPublishSetButtonClick, configureMeshPublication success, publishTarget:\(publishTargetName), publishPeriod:\(publishPeriod)")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Publish Set done successfully.", title: "Success")
        }
    }

    @IBAction func onCadenceSetButtonClick(_ sender: UIButton) {
        print("SensorSettingViewController, onCadenceSetButtonClick")
        guard let componentName = self.componentName else {
            print("error: SensorSettingViewController, onCadenceSetButtonClick, invalid nil mesh component name")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil mesh component name.")
            return
        }
        guard let minIntervalText = triggerPublishNoMoreThanSecondsTextView.text else {
            print("error: SensorSettingViewController, onCadenceSetButtonClick, triggerPublishNoMoreThanSecondsTextView not set")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Please set minimum interval more than 1 second(s).")
            return
        }

        let triggerType: Int = MeshControl.getTriggerType(typeText: cadenceStatusTriggerTypeDropDwonButton.selectedString)  ?? MeshConstants.SENSOR_TRIGGER_TYPE
        let fastCadenceLow: Int = Int(fastCadenceRangeMinValueTextView.text ?? "") ?? MeshConstants.SENSOR_FAST_CADENCE_LOW
        let fastCadenceHigh: Int = Int(fastCadenceRangeMaxValueTextView.text ?? "") ?? MeshConstants.SENSOR_FAST_CADENCE_HIGH
        let fastCadencePeriodDivisor: Int = MeshControl.getFastCadencePeriodDivisor(divisorText: fastCadencePublishPeriodDropListButton.selectedString) ?? MeshConstants.SENSOR_FAST_CADENCE_PERIOD_DIVISOR
        let minInterval: Int = Int(minIntervalText) ?? MeshConstants.SENSOR_MIN_INTERVAL
        let triggerDeltaDown: Int = Int(triggerPublishDecreaseUnitTextView.text ?? "") ?? MeshConstants.SENSOR_TRIGGER_DELTA_DOWN
        let triggerDeltaUp: Int = Int(triggerPublishIncreaseUnitTextView.text ?? "") ?? MeshConstants.SENSOR_TRIGGER_DELTA_UP

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: SensorViewController, onCadenceSetButtonClick, failed to connect to mesh network, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the mesh network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientSensorCadenceSet(deviceName: componentName, propertyId: self.propertyId,
                                                                               fastCadencePeriodDivisor: fastCadencePeriodDivisor,
                                                                               triggerType: triggerType,
                                                                               triggerDeltaDown: triggerDeltaDown,
                                                                               triggerDeltaUp: triggerDeltaUp,
                                                                               minInterval: minInterval,
                                                                               fastCadenceLow: fastCadenceLow,
                                                                               fastCadenceHigh: fastCadenceHigh)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: SensorSettingViewController, onCadenceSetButtonClick, failed to call meshClientSensorCadenceSet API, error:\(error)")
                if error == MeshErrorCode.MESH_ERROR_INVALID_STATE {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Mesh network is busying, please try again a little later.")
                } else {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to set mesh sensor cadence setting values. Error Code: \(error).")
                }
                return
            }

            print("SensorSettingViewController, onCadenceSetButtonClick, call meshClientSensorCadenceSet done success")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Cadence Set done successfully.", title: "Success")
        }
    }

    @IBAction func onSensorSettingSetButtonClick(_ sender: UIButton) {
        print("SensorSettingViewController, onSensorSettingSetButtonClick")
        guard let componentName = self.componentName else {
            print("error: SensorSettingViewController, onSensorSettingSetButtonClick, invalid nil mesh component name")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid nil mesh component name.")
            return
        }
        guard let valueText = sensorSettingPropertyValueTextView.text, !valueText.isEmpty else {
            print("error: SensorSettingViewController, onSensorSettingSetButtonClick, sensor setting value textField is empty or not set")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Please set the property setting value firstly before click the Sensor Setting Set button.")
            return
        }

        let settingPropertyId = MeshPropertyId.getPropertyIdByText(sensorPropertyDropListButton.selectedString)
        var bytes = [UInt8](repeating: 0, count: 2)
        if let valueText = sensorSettingPropertyValueTextView.text, !valueText.isEmpty {
            bytes[0] = UInt8(valueText) ?? 0
        }
        print("SensorSettingViewController, onSensorSettingSetButtonClick, settingPropertyId:\(String(format: "0x%04x", settingPropertyId)) set values: \(Data(bytes).dumpHexBytes())")

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: SensorViewController, onSensorSettingSetButtonClick, failed to connect to mesh network, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the mesh network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientSensorSettingSet(componentName: componentName, propertyId: self.propertyId, settingPropertyId: settingPropertyId, value: Data(bytes))
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: SensorSettingViewController, onSensorSettingSetButtonClick, failed to call meshClientSensorSettingSet API, error:\(error)")
                if error == MeshErrorCode.MESH_ERROR_INVALID_STATE {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Mesh network is busying, please try again a little later.")
                } else {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to set mesh sensor setting values. Error Code: \(error).")
                }
                return
            }

            print("SensorSettingViewController, onSensorSettingSetButtonClick, call meshClientSensorSettingSet API done success)")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Sensor Setting Set done successfully.", title: "Success")
        }
    }

    @IBAction func onLeftTopNagivationBarButtonItemClick(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SensorSettingViewController: UITextFieldDelegate {
    // used to make sure the input UITextField view won't be covered by the keyboard.
    func adjustingHeightWithKeyboard(show: Bool, notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardFrame = (userInfo[UIWindow.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let changeInHeight = (keyboardFrame.size.height + 5) * (show ? 1 : -1)
        scrollView.contentInset.bottom += changeInHeight
        scrollView.scrollIndicatorInsets.bottom += changeInHeight
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // hide the keyboard when click on the screen outside the keyboard.
        self.view.endEditing(true)
    }

    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
    }

    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        self.view.endEditing(true)
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return true
    }

    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
}
