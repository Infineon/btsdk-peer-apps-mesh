//
//  LightLCSettingsViewController.swift
//  MeshApp
//
//  Created by Dudley Du on 2019/6/11.
//  Copyright © 2019 Cypress Semiconductor. All rights reserved.
//

import UIKit
import MeshFramework

class LightLCSettingsViewController: UIViewController {
    @IBOutlet weak var topNavigationbar: UINavigationBar!
    @IBOutlet weak var topNavigationItem: UINavigationItem!
    @IBOutlet weak var topLeftBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var topRightBarButtonItem: UIBarButtonItem!

    @IBOutlet weak var rootView: UIView!
    @IBOutlet weak var rootScrollView: UIScrollView!

    @IBOutlet weak var lightLCSettingView: CustomCardView!
    @IBOutlet weak var lightLCModeSwitch: UISwitch!

    @IBOutlet weak var occupancySettingsView: CustomCardView!
    @IBOutlet weak var occupanyModeSwitch: UISwitch!

    @IBOutlet weak var lightLCOnOffView: CustomCardView!
    @IBOutlet weak var lightLCOnOffSwitch: UISwitch!

    @IBOutlet weak var propertySettingsView: CustomCardView!
    @IBOutlet weak var propertyIdSelectCustomDropDownButton: CustomDropDownButton!
    @IBOutlet weak var propertyIdValueTextField: UITextField!

    var groupName: String?
    var deviceName: String?
    var componentType: Int = MeshConstants.MESH_COMPONENT_UNKNOWN
    var lightLcProperty: MeshPropertyId.MeshLightLcProperty = MeshPropertyId.LightLcProperties[0]

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        notificationInit()
        viewInit()
    }

    func viewInit() {
        self.deviceName = (self.deviceName == nil) ? MeshConstantText.UNKNOWN_DEVICE_NAME : self.deviceName
        topNavigationItem.rightBarButtonItem = nil
        propertyIdValueTextField.delegate = self

        propertyIdSelectCustomDropDownButton.dropDownItems = getPropertyIdList()
        propertyIdSelectCustomDropDownButton.setSelection(select: lightLcProperty.name)
        propertyIdValueTextField.text = ""

        lightLCModeSwitch.isOn = false
        occupanyModeSwitch.isOn = false
        lightLCOnOffSwitch.isOn = false
        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, viewInit, mesh network not connected, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Mesh network not connected, please go to Network Status, sync to connect to the mesh network firstly. Error Code: \(error).")
                return
            }
            _ = MeshFrameworkManager.shared.meshClientGetLightLcMode(componentName: self.deviceName!)
            _ = MeshFrameworkManager.shared.meshClientGetLightLcOccupancyMode(componentName: self.deviceName!)
            _ = MeshFrameworkManager.shared.meshClientOnOffGet(deviceName: self.deviceName!)
        }
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


        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LIGHT_LC_MODE_STATUS), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LIGHT_LC_OCCUPANCY_MODE_STATUS), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LIGHT_LC_PROPERTY_STATUS), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_ON_OFF_STATUS), object: nil)
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

        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LIGHT_LC_MODE_STATUS):
            if let networkName = MeshFrameworkManager.shared.getOpenedMeshNetworkName(), let deviceName = self.deviceName,
                let lightLcMode = MeshNotificationConstants.getLightLcModeStatus(userInfo: userInfo),
                MeshFrameworkManager.shared.meshClientIsSameNodeElements(networkName: networkName, elementName: deviceName, anotherElementName: lightLcMode.deviceName) {
                lightLCModeSwitch.isOn = (lightLcMode.mode == MeshConstants.MESH_CLIENT_LC_MODE_OFF) ? false : true
                print("LightLCSettingsViewController, notificationHandler, Light LC mode: \(lightLcMode.mode)")
                self.showToast(message: "Light LC mode: \(lightLcMode.mode)")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LIGHT_LC_OCCUPANCY_MODE_STATUS):
            if let networkName = MeshFrameworkManager.shared.getOpenedMeshNetworkName(), let deviceName = self.deviceName,
                let lightLcOccupancyMode = MeshNotificationConstants.getLightLcOccupancyModeStatus(userInfo: userInfo), MeshFrameworkManager.shared.meshClientIsSameNodeElements(networkName: networkName, elementName: deviceName, anotherElementName: lightLcOccupancyMode.deviceName) {
                occupanyModeSwitch.isOn = (lightLcOccupancyMode.mode == MeshConstants.MESH_CLIENT_LC_OCCUPANCY_MODE_OFF) ? false : true
                print("LightLCSettingsViewController, notificationHandler, Light LC occupany mode: \(lightLcOccupancyMode.mode)")
                self.showToast(message: "Light LC occupany mode: \(lightLcOccupancyMode.mode)")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LIGHT_LC_PROPERTY_STATUS):
            if let networkName = MeshFrameworkManager.shared.getOpenedMeshNetworkName(), let deviceName = self.deviceName,
                let lightLcProperty = MeshNotificationConstants.getLightLcPropertyStatus(userInfo: userInfo),
                lightLcProperty.propertyId == self.lightLcProperty.id,
                MeshFrameworkManager.shared.meshClientIsSameNodeElements(networkName: networkName, elementName: deviceName, anotherElementName: lightLcProperty.deviceName) {
                propertyIdValueTextField.text = "\(lightLcProperty.value)"
                print("LightLCSettingsViewController, notificationHandler, Light LC property ID: \(String.init(format: "0x%x", lightLcProperty.propertyId)), value: \(lightLcProperty.value)")
                self.showToast(message: "Light LC property ID: \(String.init(format: "0x%x", lightLcProperty.propertyId)), value: \(lightLcProperty.value)")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_ON_OFF_STATUS):
            if let networkName = MeshFrameworkManager.shared.getOpenedMeshNetworkName(), let deviceName = self.deviceName,
                let onoffStatus = MeshNotificationConstants.getOnOffStatus(userInfo: userInfo),
                MeshFrameworkManager.shared.meshClientIsSameNodeElements(networkName: networkName, elementName: deviceName, anotherElementName: onoffStatus.deviceName) {
                lightLCOnOffSwitch.isOn = onoffStatus.isOn
                print("LightLCSettingsViewController, notificationHandler, Light LC ON/OFF status: \(onoffStatus.isOn ? "ON" : "OFF")")
                self.showToast(message: "Light LC ON/OFF status: \(onoffStatus.isOn ? "ON" : "OFF")")
            }
        default:
            break
        }
    }

    @IBAction func onTopLeftBarButtonItemClick(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func onTopRightBarButtonItemClick(_ sender: UIBarButtonItem) {
    }

    @IBAction func onLightLCModeSetSwitchClick(_ sender: UISwitch) {
        guard let componentName = self.deviceName else {
            lightLCModeSwitch.isOn = !lightLCModeSwitch.isOn
            print("error: LightLCSettingsViewController, onLightLCModeSetSwitchClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error: invalid device name for the Light Controller.")
            return
        }
        let mode = lightLCModeSwitch.isOn ? MeshConstants.MESH_CLIENT_LC_MODE_ON : MeshConstants.MESH_CLIENT_LC_MODE_OFF
        let error = MeshFrameworkManager.shared.meshClientSetLightLcMode(componentName: componentName, mode: mode)
        guard error == MeshErrorCode.MESH_SUCCESS else {
            lightLCModeSwitch.isOn = !lightLCModeSwitch.isOn
            print("error: LightLCSettingsViewController, onLightLCModeSetSwitchClick, failed to call meshClientSetLightLcMode, error: \(error)")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send Set Light LC mode command. Error Code: \(error).")
            return
        }

        print("LightLCSettingsViewController, onLightLCModeSetSwitchClick, meshClientSetLightLcMode return success")
    }

    @IBAction func onLightLCModeGetButtonClick(_ sender: UIButton) {
        guard let componentName = self.deviceName else {
            print("error: LightLCSettingsViewController, onLightLCModeGetButtonClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error: invalid device name for the Light Controller.")
            return
        }

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onLightLCModeGetButtonClick, failed to connect to mesh network, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the Mesh Network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientGetLightLcMode(componentName: componentName)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onLightLCModeGetButtonClick, failed to call meshClientGetLightLcMode, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send Get Light LC mode command. Error Code: \(error).")
                return
            }

            print("LightLCSettingsViewController, onLightLCModeGetButtonClick, meshClientGetLightLcMode return success")
        }
    }

    @IBAction func onOccupanySetSwitchClick(_ sender: UISwitch) {
        guard let componentName = self.deviceName else {
            occupanyModeSwitch.isOn = !occupanyModeSwitch.isOn
            print("error: LightLCSettingsViewController, onOccupanySetSwitchClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error: invalid device name for the Light Controller.")
            return
        }

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                self.occupanyModeSwitch.isOn = !self.occupanyModeSwitch.isOn
                print("error: LightLCSettingsViewController, onOccupanySetSwitchClick, failed to connect to mesh network, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the Mesh Network. Error Code: \(error).")
                return
            }

            let mode = self.occupanyModeSwitch.isOn ? MeshConstants.MESH_CLIENT_LC_OCCUPANCY_MODE_ON : MeshConstants.MESH_CLIENT_LC_OCCUPANCY_MODE_OFF
            let error = MeshFrameworkManager.shared.meshClientSetLightLcOccupancyMode(componentName: componentName, mode: mode)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                self.occupanyModeSwitch.isOn = !self.occupanyModeSwitch.isOn
                print("error: LightLCSettingsViewController, onOccupanySetSwitchClick, failed to call meshClientSetLightLcOccupancyMode, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send Set Light LC occupancy mode command. Error Code: \(error).")
                return
            }

            print("LightLCSettingsViewController, onOccupanySetSwitchClick, meshClientSetLightLcOccupancyMode return success")
        }
    }

    @IBAction func onOccupanyGetButtonClick(_ sender: UIButton) {
        guard let componentName = self.deviceName else {
            print("error: LightLCSettingsViewController, onOccupanyGetButtonClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error: invalid device name for the Light Controller.")
            return
        }

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onOccupanyGetButtonClick, failed to connect to mesh network, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the Mesh Network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientGetLightLcOccupancyMode(componentName: componentName)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onOccupanyGetButtonClick, failed to call meshClientGetLightLcOccupancyMode, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send Get Light LC occupancy mode command. Error Code: \(error).")
                return
            }

            print("LightLCSettingsViewController, onOccupanyGetButtonClick, meshClientGetLightLcOccupancyMode return success")
        }
    }

    @IBAction func onLightLCOnOffSwitchClick(_ sender: UISwitch) {
        guard let componentName = self.deviceName else {
            lightLCOnOffSwitch.isOn = !lightLCOnOffSwitch.isOn
            print("error: LightLCSettingsViewController, onLightLCOnOffSwitchClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error: invalid device name for the Light Controller.")
            return
        }

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                self.lightLCOnOffSwitch.isOn = !self.lightLCOnOffSwitch.isOn
                print("error: LightLCSettingsViewController, onLightLCOnOffSwitchClick, failed to connect to mesh network, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the Mesh Network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientSetLightLcOnOffSet(componentName: componentName, isOn: self.lightLCOnOffSwitch.isOn, reliable: true, transitionTime: 0, delay: 0)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                self.lightLCOnOffSwitch.isOn = !self.lightLCOnOffSwitch.isOn
                print("error: LightLCSettingsViewController, onLightLCOnOffSwitchClick, failed to call meshClientSetLightLcOnOffSet, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send Set Light LC ON/OFF command. Error Code: \(error).")
                return
            }

            print("LightLCSettingsViewController, onLightLCOnOffSwitchClick, meshClientSetLightLcOnOffSet return success")
        }
    }

    @IBAction func onLightLCOnOffGetButtonClick(_ sender: UIButton) {
        guard let componentName = self.deviceName else {
            print("error: LightLCSettingsViewController, onLightLCOnOffGetButtonClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error: invalid device name for the Light Controller.")
            return
        }

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onLightLCOnOffGetButtonClick, failed to connect to mesh network, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the Mesh Network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientOnOffGet(deviceName: componentName)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onLightLCOnOffGetButtonClick, failed to call meshClientOnOffGet, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send Get Light LC ON/OFF status command. Error Code: \(error).")
                return
            }

            print("LightLCSettingsViewController, onLightLCOnOffGetButtonClick, meshClientOnOffGet return success")
        }
    }

    @IBAction func onPropertyGetButtonClick(_ sender: UIButton) {
        guard let componentName = self.deviceName else {
            print("error: LightLCSettingsViewController, onPropertyGetButtonClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error: invalid device name for the Light Controller.")
            return
        }

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onPropertyGetButtonClick, failed to connect to mesh network, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the Mesh Network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientGetLightLcProperty(componentName: componentName, propertyId: self.lightLcProperty.id)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onPropertyGetButtonClick, failed to call meshClientGetLightLcProperty, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send Get Light LC Property command. Error Code: \(error).")
                return
            }

            print("LightLCSettingsViewController, onPropertyGetButtonClick, meshClientGetLightLcProperty return success")
        }
    }

    @IBAction func onPropertyIdSelectionCustomDropDownButtonClick(_ sender: CustomDropDownButton) {
        propertyIdSelectCustomDropDownButton.showDropList(width: 300, parent: self) {
            print("\(self.propertyIdSelectCustomDropDownButton.selectedIndex), \(self.propertyIdSelectCustomDropDownButton.selectedString)")
            if self.propertyIdSelectCustomDropDownButton.selectedString != self.lightLcProperty.name {
                self.propertyIdValueTextField.text = ""     // clear value data when property id changed.
            }
            self.lightLcProperty = self.getLightLcProperty(name: self.propertyIdSelectCustomDropDownButton.selectedString)
        }
    }

    @IBAction func onPropertySetButtonClick(_ sender: UIButton) {
        guard let componentName = self.deviceName else {
            print("error: LightLCSettingsViewController, onPropertySetButtonClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error: invalid device name for the Light Controller.")
            return
        }
        guard let value = UtilityManager.convertDigitStringToInt(digit: self.propertyIdValueTextField.text) else {
            print("error: LightLCSettingsViewController, onPropertySetButtonClick, invalid device name for the Light Controller")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid property value string, please input a valid integer value.")
            return
        }

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onPropertySetButtonClick, failed to connect to mesh network, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the Mesh Network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientSetLightLcProperty(componentName: componentName, propertyId: self.lightLcProperty.id, value: value)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: LightLCSettingsViewController, onPropertySetButtonClick, failed to call meshClientSetLightLcProperty, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send Set Light LC Property command. Error Code: \(error).")
                return
            }

            print("LightLCSettingsViewController, onPropertySetButtonClick, meshClientSetLightLcProperty return success")
        }
    }

    func getPropertyIdList() -> [String] {
        var propertyList: [String] = []
        for item in MeshPropertyId.LightLcProperties {
            propertyList.append(item.name)
        }
        return propertyList
    }

    func getLightLcProperty(name: String) -> MeshPropertyId.MeshLightLcProperty {
        for item in MeshPropertyId.LightLcProperties {
            if item.name == name {
                return item
            }
        }
        // should not go to here.
        return MeshPropertyId.LightLcProperties[0]
    }
}

extension LightLCSettingsViewController: UITextFieldDelegate {
    // used to make sure the input UITextField view won't be covered by the keyboard.
    func adjustingHeightWithKeyboard(show: Bool, notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardFrame = (userInfo[UIWindow.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let changeInHeight = (keyboardFrame.size.height + 5) * (show ? 1 : -1)
        rootScrollView.contentInset.bottom += changeInHeight
        rootScrollView.scrollIndicatorInsets.bottom += changeInHeight
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
