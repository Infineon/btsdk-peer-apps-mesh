//
//  VendorSpecificDataViewController.swift
//  MeshApp
//
//  Created by Dudley Du on 2019/6/5.
//  Copyright © 2019 Cypress Semiconductor. All rights reserved.
//

import UIKit
import MeshFramework

class VendorSpecificDataViewController: UIViewController {

    @IBOutlet weak var deviceNameView: UIView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var setVendorDataView: CustomCardView!
    @IBOutlet weak var companyIdTextField: UITextField!
    @IBOutlet weak var modelIdTextField: UITextField!
    @IBOutlet weak var opcodeTextField: UITextField!
    @IBOutlet weak var setVendorDataTextfield: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var receivedVendorDataView: CustomCardView!
    @IBOutlet weak var receivedVedorDataTextView: UITextView!

    private var logBaseTime = Date(timeIntervalSinceNow: 0)

    var groupName: String?
    var deviceName: String? {
        didSet {
            if deviceNameLabel != nil {
                deviceNameLabel.text = deviceName ?? MeshConstantText.UNKNOWN_DEVICE_NAME
            }
        }
    }
    var componentType: Int = MeshConstants.MESH_COMPONENT_UNKNOWN

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        notificationInit()
        viewInit()
    }

    func viewInit() {
        deviceNameLabel.text = self.deviceName ?? MeshConstantText.UNKNOWN_DEVICE_NAME
        if let deviceName = self.deviceName, componentType == MeshConstants.MESH_COMPONENT_UNKNOWN {
            componentType = MeshFrameworkManager.shared.getMeshComponentType(componentName: deviceName)
        }
        receivedVedorDataTextView.text = ""
    }

    func notificationInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_VENDOR_SPECIFIC_DATA_CHANGED), object: nil)
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
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_VENDOR_SPECIFIC_DATA_CHANGED):
            guard let vendorData = MeshNotificationConstants.getVendorSpecificData(userInfo: userInfo) else {
                meshLog("error, VendorSpecificDataViewController, getVendorSpecificData, no valid data received, userInfo=\(userInfo)")
                return
            }

            log("Company ID: \(vendorData.companyId), Model ID: \(vendorData.modelId), OpCode: \(vendorData.opcode), TTL: \(vendorData.ttl), Data(hex): \(vendorData.data.dumpHexBytes())")
        default:
            break
        }
    }

    func log(_ message: String) {
        let seconds = Date().timeIntervalSince(logBaseTime)
        let msg = String(format: "[%.3f] \(message)\n", seconds)
        receivedVedorDataTextView.text += msg
        let bottom = NSRange(location: receivedVedorDataTextView.text.count, length: 1)
        receivedVedorDataTextView.scrollRangeToVisible(bottom)
    }

    @IBAction func onSendVendorDataButtonClick(_ sender: UIButton) {
        guard let deviceName = self.deviceName else {
            meshLog("error: VendorSpecificDataViewController, onSendVendorDataButtonClick, invalid deviceName, nil")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid device name or not set.", title: "Error")
            return
        }
        guard let vendorData = UtilityManager.convertHexDigitStringToData(hexDigit: setVendorDataTextfield.text) else {
            if !(setVendorDataTextfield.text?.isEmpty ?? true), !UtilityManager.isValidDigitString(digit: setVendorDataTextfield.text, isHexdecimal: true) {
                meshLog("error: VendorSpecificDataViewController, onSendVendorDataButtonClick, invalid vendor data, contain not hex digit characters")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Invalid vendor data, contains non hexdecimal digit characters. Please correct the invalid data and try again!", title: "Error")
                return
            }
            meshLog("error: VendorSpecificDataViewController, onSendVendorDataButtonClick, vendor data not set, nil")
            UtilityManager.showAlertDialogue(parentVC: self, message: "No vendor specific data set, please input hexdecimal vendor specific data firstly!", title: "Error")
            return
        }

        let companyId: Int! = UtilityManager.convertDigitStringToInt(digit: companyIdTextField.text) ?? MeshConstants.MESH_VENDOR_COMPANY_ID
        let modelId: Int! = UtilityManager.convertDigitStringToInt(digit: modelIdTextField.text) ?? MeshConstants.MESH_VENDOR_MODEL_ID
        let opcode: Int! = UtilityManager.convertDigitStringToInt(digit: opcodeTextField.text) ?? MeshConstants.MESH_VENDOR_OPCODE1

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected(handler: { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                meshLog("error: VendorSpecificDataViewController, onSendVendorDataButtonClick. Error Code: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to set the vendor data, Mesh network not connected yet!")
                return
            }

            meshLog("VendorSpecificDataViewController, onSendVendorDataButtonClick, deviceName: \(deviceName), companyId: \(String(describing: companyId)), modelId: \(String(describing: modelId)), opcode: \(String(describing: opcode)), data: \(vendorData.dumpHexBytes())")
            let error = MeshFrameworkManager.shared.meshClientVendorDataSet(deviceName: deviceName, companyId: companyId, modelId: modelId, opcode: opcode, disable_ntwk_retransmit: MeshConstants.MESH_VENDOR_DISABLE_NETWORK_RETRANSMIT, data: vendorData)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                meshLog("VendorSpecificDataViewController, onSendVendorDataButtonClick, failed to send out data, error: \(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to send out the vendor data, please check the values of Company Id, Model Id and OpCode are all set correctly! Error Code: \(error)", title: "Error")
                return
            }
            meshLog("VendorSpecificDataViewController, onSendVendorDataButtonClick, send out success")
        })
    }
}

extension VendorSpecificDataViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        companyIdTextField.resignFirstResponder()
        modelIdTextField.resignFirstResponder()
        opcodeTextField.resignFirstResponder()
        setVendorDataTextfield.resignFirstResponder()
    }
}
