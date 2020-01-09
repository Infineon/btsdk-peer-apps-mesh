/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * OTA support device classes implementation.
 */

import Foundation
import CoreBluetooth
// import HomeKit       // disable HomeKit support for sample code upload for AppStore,

public typealias OtaCompletionHandler = (Data?, Error?) -> Void

public protocol OtaDeviceProtocol {
    func getDeviceName() -> String
    func getDeviceType() -> OtaDeviceType
    func equal(_ device: OtaDeviceProtocol) -> Bool

    var otaVersion: Int { get }                 // default is 1;
    var otaDeviceHasConnected: Bool { get set } // indicates mesh device connected state.
    var otaDevice: AnyObject? { get set }       // system platform device instance that reference remote OTA device.
    var otaService: AnyObject? { get set }
    var otaControlPointCharacteristic: AnyObject? { get set }
    var otaDataCharacteristic: AnyObject? { get set }
    var otaAppInfoCharacteristic: AnyObject? { get set }

    /*
     * OtaUpgrader will call this API to parepare for OTA, including connect to remote device, discover OTA service,
     * and read App Info if possible.
     */
    func prepareOta() -> Int

    /*
     * OtaUpgrader will call this API to start OTA upgrade process.
     */
    func startOta(fwImage: Data) -> Int

    /*
     * OtaUpgrader will call this API to connect to the remote device.
     * Whenever the connecting established success or failed or timeouted, the OtaUpgraderProtocol.didUpdateConnectionState interface must be invoked.
     */
    func connect()

    /*
     * OtaUpgrader will call this API to disconnect from the remote device.
     * Whenever the disconnecting success or failed or timeouted, the OtaUpgraderProtocol.didUpdateConnectionState interface must be invoked.
     */
    func disconnect()

    /*
     * OtaUpgrader will call this API to start discovering OTA service,
     * Whenever the OTA service is discovered or not or timeout, the OtaUpgraderProtocol.didUpdateOtaServiceCharacteristicState interface must be invoked.
     */
    func discoverOtaServiceCharacteristic()

    /*
     * OtaUpgrader will call this API to enable the indication/notificaiton of the OTA service Control Point characteristic,
     * Whenever the indication/notificaiton is enabled or not or timeout, the OtaUpgraderProtocol.didUpdateNotificationState interface must be invoked.
     */
    func enableOtaNotification(enabled: Bool)

    /*
     * OtaUpgrader will call this API to write data to the specific characteristic to remote device,
     * Whenever the write operation success or failed or timeout, the OtaUpgraderProtocol.didUpdateValueFor interface must be invoked.
     */
    func writeValue(to: OtaCharacteristic, value: Data, completion: @escaping OtaCompletionHandler)

    /*
     * OtaManager will call this API when the write operation has been done by the system BLE stach
     * after called the system API peripheral.writeValue with type parameter set to .withResponse, or the timeout error happenned.
     * When this API called, writeValue completion must be called.
     */
    func didWriteValue(for: OtaCharacteristic, error: Error?)

    /*
     * OtaUpgrader will call this API to read data from the specific characteristic from remote device,
     * Whenever the read operation success or failed or timeout, the OtaUpgraderProtocol.didUpdateValueFor interface must be invoked.
     */
    func readValue(from: OtaCharacteristic)
}


public class OtaBleDevice: NSObject, OtaDeviceProtocol {
    public var otaDeviceHasConnected: Bool = false

    public var otaVersion: Int {
        guard let serviceUuid = mOtaService?.uuid, serviceUuid == OtaConstants.BLE_V2.UUID_SERVICE_UPGRADE else {
            return OtaConstants.OTA_VERSION_1
        }
        return OtaConstants.OTA_VERSION_2
    }

    private var mOtaDevice: CBPeripheral?
    public var otaDevice: AnyObject? {
        get { return mOtaDevice }
        set { mOtaDevice = newValue as? CBPeripheral }
    }
    private var mOtaService: CBService?
    public var otaService: AnyObject? {
        get { return mOtaService }
        set { mOtaService = newValue as? CBService }
    }
    private var mOtaControlPointCharacteristic: CBCharacteristic?
    public var otaControlPointCharacteristic: AnyObject? {
        get { return mOtaControlPointCharacteristic }
        set { mOtaControlPointCharacteristic = newValue as? CBCharacteristic }
    }
    private var mOtaDataCharacteristic: CBCharacteristic?
    public var otaDataCharacteristic: AnyObject? {
        get { return mOtaDataCharacteristic }
        set { mOtaDataCharacteristic = newValue as? CBCharacteristic }
    }
    private var mOtaAppInfoCharacteristic: CBCharacteristic?
    public var otaAppInfoCharacteristic: AnyObject? {
        get { return mOtaAppInfoCharacteristic }
        set { mOtaAppInfoCharacteristic = newValue as? CBCharacteristic }
    }

    public override init() {
        super.init()
    }

    public convenience init(peripheral: CBPeripheral) {
        self.init()
        self.mOtaDevice = peripheral
    }

    public func getDeviceName() -> String {
        return mOtaDevice?.name ?? "Unknown Device Name"
    }

    public func getDeviceType() -> OtaDeviceType {
        return OtaDeviceType.ble
    }

    public func equal(_ device: OtaDeviceProtocol) -> Bool {
        if let bleDevice = device as? OtaBleDevice, bleDevice == self {
            return true
        }
        return false
    }

    public func prepareOta() -> Int {
        return OtaUpgrader.shared.otaUpgradePrepare(for: self)
    }

    public func startOta(fwImage: Data) -> Int {
        return OtaUpgrader.shared.otaUpgradeStart(for: self, fwImage: fwImage)
    }

    public func connect() {
        guard let peripheral = mOtaDevice else {
            OtaUpgrader.shared.didUpdateConnectionState(isConnected: false,
                                                        error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                                                        desc: "peripheral object is nil"))
            return
        }

        if MeshGattClient.shared.centralManager.state == .poweredOn {
            if peripheral.state == .connected {
                OtaUpgrader.shared.didUpdateConnectionState(isConnected: true, error: nil)
                return
            }

            MeshGattClient.shared.centralManager.connect(peripheral, options: nil)
        } else {
            OtaUpgrader.shared.didUpdateConnectionState(isConnected: false,
                                                        error: OtaError(code: OtaErrorCode.FAILED,
                                                                        desc: "BLE not enabled or not ready yet"))
        }
    }

    public func disconnect() {
        guard let peripheral = mOtaDevice else {
            OtaUpgrader.shared.didUpdateConnectionState(isConnected: false,
                                                        error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                                                        desc: "peripheral object is nil"))
            return
        }

        if MeshGattClient.shared.centralManager.state == .poweredOn {
            if peripheral.state == .disconnected {
                OtaUpgrader.shared.didUpdateConnectionState(isConnected: false, error: nil)
                return
            }

            MeshGattClient.shared.centralManager.cancelPeripheralConnection(peripheral)
        } else {
            OtaUpgrader.shared.didUpdateConnectionState(isConnected: false,
                                                        error: OtaError(code: OtaErrorCode.FAILED,
                                                                        desc: "BLE not enabled or not ready yet"))
        }
    }

    public func discoverOtaServiceCharacteristic() {
        guard let peripheral = mOtaDevice else {
            OtaUpgrader.shared.didUpdateOtaServiceCharacteristicState(isDiscovered: false,
                                                                      error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                                                                      desc: "peripheral object is nil"))
            return
        }

        peripheral.discoverServices([OtaConstants.BLE.UUID_SERVICE_UPGRADE, OtaConstants.BLE_V2.UUID_SERVICE_UPGRADE])
    }

    public func enableOtaNotification(enabled: Bool) {
        guard let peripheral = mOtaDevice, let controlPointCharacteristic = mOtaControlPointCharacteristic else {
            OtaUpgrader.shared.didUpdateNotificationState(isEnabled: false,
                                                          error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                                                          desc: "peripheral object or control point characteristic is nil"))
            return
        }

        if controlPointCharacteristic.isNotifying {
            OtaUpgrader.shared.didUpdateNotificationState(isEnabled: true, error: nil)
            return // return early
        }

        peripheral.setNotifyValue(enabled, for: controlPointCharacteristic)
    }

    private var writeValueCompletionCallback: OtaCompletionHandler?
    public func writeValue(to characteristic: OtaCharacteristic, value: Data, completion: @escaping OtaCompletionHandler) {
        guard let peripheral = mOtaDevice else {
            completion(nil, OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES, desc: "peripheral object is nil"))
            return
        }

        var writeType: CBCharacteristicWriteType = .withResponse
        var bleCharacteristic: CBCharacteristic?
        if characteristic == .controlPointCharacteristic, let controlPointCharacteristic = mOtaControlPointCharacteristic {
            bleCharacteristic = controlPointCharacteristic
            writeType = .withResponse
        } else if characteristic == .dataCharacteristic, let dataCharacteristic = mOtaDataCharacteristic {
            bleCharacteristic = dataCharacteristic
            writeType = .withResponse
        } else if characteristic == .appInfoCharacteristic, let appInfoCharacteristic = mOtaAppInfoCharacteristic {
            bleCharacteristic = appInfoCharacteristic
            writeType = .withResponse
        }
        guard let writeCharacteristic = bleCharacteristic else {
            completion(nil, OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES, desc: "invalid ota characteristic, write characteristic object is nil"))
            return
        }

        writeValueCompletionCallback = completion
        peripheral.writeValue(value, for: writeCharacteristic, type: writeType)
    }

    public func didWriteValue(for characteristic: OtaCharacteristic, error: Error?) {
        if let completion = writeValueCompletionCallback {
            writeValueCompletionCallback = nil
            completion(nil, error)
        }
    }

    public func readValue(from characteristic: OtaCharacteristic) {
        guard let peripheral = mOtaDevice else {
            OtaUpgrader.shared.didUpdateValueFor(characteristic: characteristic, value: nil,
                                                 error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES, desc: "peripheral object is nil"))
            return
        }

        var bleCharacteristic: CBCharacteristic?
        if characteristic == .controlPointCharacteristic, let controlPointCharacteristic = mOtaControlPointCharacteristic {
            bleCharacteristic = controlPointCharacteristic
        } else if characteristic == .dataCharacteristic, let dataCharacteristic = mOtaDataCharacteristic {
            bleCharacteristic = dataCharacteristic
        } else if characteristic == .appInfoCharacteristic, let appInfoCharacteristic = mOtaAppInfoCharacteristic {
            bleCharacteristic = appInfoCharacteristic
        }
        guard let readCharacteristic = bleCharacteristic else {
            OtaUpgrader.shared.didUpdateValueFor(characteristic: characteristic,
                                                 value: nil,
                                                 error: OtaError(code: OtaErrorCode.INVALID_CBCHARACTERISTIC_OBJECT, desc: "read chararcterisc is nil, not support"))
            return
        }

        peripheral.readValue(for: readCharacteristic)
    }
}

public class OtaMeshDevice: OtaBleDevice {
    private var meshName: String

    public init(meshName: String) {
        self.meshName = meshName
        super.init()
    }

    override public func getDeviceName() -> String {
        return self.meshName
    }

    override public func getDeviceType() -> OtaDeviceType {
        return OtaDeviceType.mesh
    }

    override public func equal(_ device: OtaDeviceProtocol) -> Bool {
        if let meshDevice = device as? OtaMeshDevice, meshDevice == self, meshDevice.getDeviceName() == device.getDeviceName() {
            return true
        }
        return false
    }

    override public func connect() {
        if otaDeviceHasConnected {
            OtaUpgrader.shared.didUpdateConnectionState(isConnected: true, error: nil)
            return
        }

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                meshLog("OtaMeshDevice, connect, failed to connect to mesh network firstly ,error:\(error)")
                self.otaDevice = nil
                OtaUpgrader.shared.didUpdateConnectionState(isConnected: false,
                                                            error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                                                            desc: "unable to connect to mesh network"))
                return
            }

            MeshFrameworkManager.shared.meshClientConnectComponent(componentName: self.getDeviceName(), scanDuration: MeshConstants.MESH_DEFAULT_SCAN_DURATION * 4) { (status: Int, componentName: String, error: Int) in

                meshLog("OtaMeshDevice, connect, meshClientConnectComponent, status:\(status), componentName:\(componentName), error:\(error)")
                guard error == MeshErrorCode.MESH_SUCCESS, status == MeshConstants.MESH_CLIENT_NODE_CONNECTED else {
                    // failed to connect to the mesh device.
                    self.otaDevice = nil
                    OtaUpgrader.shared.didUpdateConnectionState(isConnected: false,
                                                                error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                                                                desc: "unable to connect to remote mesh device"))
                    return
                }

                self.otaDevice = MeshNativeHelper.getCurrentConnectedPeripheral()
                meshLog("OtaMeshDevice, connect, meshClientConnectComponent, otaDevice:\(String(describing: self.otaDevice))")

                OtaUpgrader.shared.didUpdateConnectionState(isConnected: true, error: nil)
            }
        }
    }

    override public func disconnect() {
        _ = MeshFrameworkManager.shared.meshClientDisconnect(1)
        OtaUpgrader.shared.didUpdateConnectionState(isConnected: false, error: nil)
    }

    override public func writeValue(to characteristic: OtaCharacteristic, value: Data, completion: @escaping OtaCompletionHandler) {
        guard let encryptedData = MeshFrameworkManager.shared.meshClientOtaDataEncrypt(componenetName: getDeviceName(), data: value) else {
            completion(nil, OtaError(code: OtaErrorCode.FAILED, desc: "failed to encrypt OTA data for mesh device"))
            return
        }

        super.writeValue(to: characteristic, value: encryptedData) { (data, error) in
            completion(data, error)
        }
    }
}

#if false && os(iOS)
public class OtaHomeKitDevice: NSObject, OtaDeviceProtocol {
    public var otaVersion: Int {
        return OtaConstants.OTA_VERSION_1
    }

    private var mOtaDevice: HMAccessory?
    public var otaDevice: AnyObject? {
        get { return mOtaDevice }
        set { mOtaDevice = newValue as? HMAccessory }
    }
    private var mOtaService: HMService?
    public var otaService: AnyObject? {
        get { return mOtaService }
        set { mOtaService = newValue as? HMService }
    }
    private var mOtaControlPointCharacteristic: HMCharacteristic?
    public var otaControlPointCharacteristic: AnyObject? {
        get { return mOtaControlPointCharacteristic }
        set { mOtaControlPointCharacteristic = newValue as? HMCharacteristic }
    }
    private var mOtaDataCharacteristic: HMCharacteristic?
    public var otaDataCharacteristic: AnyObject? {
        get { return mOtaDataCharacteristic }
        set { mOtaDataCharacteristic = newValue as? HMCharacteristic }
    }
    private var mOtaAppInfoCharacteristic: HMCharacteristic?
    public var otaAppInfoCharacteristic: AnyObject? {
        get { return mOtaAppInfoCharacteristic }
        set { mOtaAppInfoCharacteristic = newValue as? HMCharacteristic }
    }

    public var isPaired: Bool {
        guard let accessory = mOtaDevice, accessory.room != nil, accessory.services.count > 0 else {
            return false
        }
        return true
    }

    init(accessory: HMAccessory) {
        super.init()
        accessory.delegate = self
        mOtaDevice = accessory
    }

    public func getDeviceName() -> String {
        return mOtaDevice?.name ?? "Unknown Device Name"
    }

    public func getDeviceType() -> OtaDeviceType {
        return OtaDeviceType.homeKit
    }

    public func equal(_ device: OtaDeviceProtocol) -> Bool {
        if let hmDevice = device as? OtaHomeKitDevice, hmDevice == self,
            let hmAccessory = device.otaDevice as? HMAccessory, let selfAccessory = self.otaDevice as? HMAccessory,
            hmAccessory == selfAccessory {
            return true
        }
        return false
    }

    public func prepareOta() -> Int {
        return OtaUpgrader.shared.otaUpgradePrepare(for: self)
    }

    public func startOta(fwImage: Data) -> Int {
        return OtaUpgrader.shared.otaUpgradeStart(for: self, fwImage: fwImage)
    }

    public func connect() {
        OtaUpgrader.shared.didUpdateConnectionState(isConnected: true, error: nil)
    }

    public func disconnect() {
        OtaUpgrader.shared.didUpdateConnectionState(isConnected: false, error: nil)
    }

    public func discoverOtaServiceCharacteristic() {
        guard let hmAccessory = mOtaDevice else {
            OtaUpgrader.shared.didUpdateOtaServiceCharacteristicState(isDiscovered: false,
                                                                      error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                                                                      desc: "hmAccessory object is nil"))
            return
        }

        for service in hmAccessory.services {
            if service.serviceType == OtaConstants.HomeKit.UUID_SERVICE_UPGRADE.description {
                otaService = service

                for characteristic in service.characteristics {
                    if characteristic.characteristicType == OtaConstants.HomeKit.UUID_CHARACTERISTIC_CONTROL_POINT.description {
                        otaControlPointCharacteristic = characteristic
                    } else if characteristic.characteristicType == OtaConstants.HomeKit.UUID_CHARACTERISTIC_DATA.description {
                        otaDataCharacteristic = characteristic
                    } else if characteristic.characteristicType == OtaConstants.HomeKit.UUID_CHARACTERISTIC_APP_INFO.description {
                        otaAppInfoCharacteristic = characteristic
                    }
                }
            }
        }

        if otaControlPointCharacteristic != nil, otaDataCharacteristic != nil {
            OtaUpgrader.shared.didUpdateOtaServiceCharacteristicState(isDiscovered: true, error: nil)
        } else {
            OtaUpgrader.shared.didUpdateOtaServiceCharacteristicState(isDiscovered: false, error: nil)
        }
    }

    public func enableOtaNotification(enabled: Bool) {
        guard let controlPointCharacteristic = mOtaControlPointCharacteristic else {
            OtaUpgrader.shared.didUpdateNotificationState(isEnabled: false,
                                                          error: OtaError(code: OtaErrorCode.INVALID_HMCHARACTERISTIC_OBJECT,
                                                                          desc: "Control Point HMCharacteristic is nil"))
            return
        }

        if controlPointCharacteristic.isNotificationEnabled {
            OtaUpgrader.shared.didUpdateNotificationState(isEnabled: true, error: nil)
        } else {
            controlPointCharacteristic.enableNotification(true) { (error) in
                guard error == nil else {
                    OtaUpgrader.shared.didUpdateNotificationState(isEnabled: false, error: error)
                    return
                }

                OtaUpgrader.shared.didUpdateNotificationState(isEnabled: controlPointCharacteristic.isNotificationEnabled, error: nil)
            }
        }
    }

    public func readValue(from characteristic: OtaCharacteristic) {
        guard let _ = mOtaDevice else {
            OtaUpgrader.shared.didUpdateOtaServiceCharacteristicState(isDiscovered: false,
                                                                      error: OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                                                                      desc: "hmAccessory object is nil"))
            return
        }

        var hmCharacteristic: HMCharacteristic?
        if characteristic == .controlPointCharacteristic, let controlPointCharacteristic = mOtaControlPointCharacteristic {
            hmCharacteristic = controlPointCharacteristic
        } else if characteristic == .dataCharacteristic, let dataCharacteristic = mOtaDataCharacteristic {
            hmCharacteristic = dataCharacteristic
        } else if characteristic == .appInfoCharacteristic, let appInfoCharacteristic = mOtaAppInfoCharacteristic {
            hmCharacteristic = appInfoCharacteristic
        }
        guard let readCharacteristic = hmCharacteristic else {
            OtaUpgrader.shared.didUpdateValueFor(characteristic: characteristic,
                                                 value: nil,
                                                 error: OtaError(code: OtaErrorCode.INVALID_HMCHARACTERISTIC_OBJECT,
                                                                 desc: "read HMCharacteristic is nil, not support"))
            return
        }

        readCharacteristic.readValue { (error) in
            guard error == nil else {
                OtaUpgrader.shared.didUpdateValueFor(characteristic: characteristic, value: nil, error: error)
                return
            }

            OtaUpgrader.shared.didUpdateValueFor(characteristic: characteristic, value: readCharacteristic.value as? Data, error: nil)
        }
    }

    public func writeValue(to characteristic: OtaCharacteristic, value: Data, completion: @escaping OtaCompletionHandler) {
        guard let _ = mOtaDevice else {
            completion(nil, OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES, desc: "hmAccessory object is nil"))
            return
        }

        var hmCharacteristic: HMCharacteristic?
        if characteristic == .controlPointCharacteristic, let controlPointCharacteristic = mOtaControlPointCharacteristic {
            hmCharacteristic = controlPointCharacteristic
        } else if characteristic == .dataCharacteristic, let dataCharacteristic = mOtaDataCharacteristic {
            hmCharacteristic = dataCharacteristic
        }
        guard let writeCharacteristic = hmCharacteristic else {
            completion(nil, OtaError(code: OtaErrorCode.INVALID_OBJECT_INSTANCES,
                                     desc: "invalid OtaCharacteristic type or HMCharacteristic instance"))
            return
        }

        writeCharacteristic.writeValue(value) { (error) in
            guard error == nil else {
                completion(nil, error)
                return
            }

            completion(nil, nil)
        }
    }

    public func didWriteValue(for: OtaCharacteristic, error: Error?) {
        // protocol placehold, not used.
    }
}

extension OtaHomeKitDevice: HMAccessoryDelegate {
    public func accessoryDidUpdateName(_ accessory: HMAccessory) {
        meshLog("OtaHomeKitDevice, accessoryDidUpdateName accessory: \(accessory)")
    }

    public func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        meshLog("OtaHomeKitDevice, accessoryDidUpdateReachability accessory: \(accessory.name), isReachable: \(accessory.isReachable)")
    }

    public func accessoryDidUpdateServices(_ accessory: HMAccessory) {
        meshLog("OtaHomeKitDevice, accessoryDidUpdateServices accessory: \(accessory.name)")
        OtaHomeKitDevice.dumpHomeKitAccessory(accessory)
    }

    public func accessory(_ accessory: HMAccessory, didUpdateNameFor service: HMService) {
        meshLog("OtaHomeKitDevice, accessory service: \(service.uniqueIdentifier.uuidString) name has been updated to \"\(service.name)\"")
    }

    public func accessory(_ accessory: HMAccessory, didUpdateAssociatedServiceTypeFor service: HMService) {
        meshLog("OtaHomeKitDevice, accessory service:\(service.name) type has been updated to \"\(service.serviceType)\"")
    }

    public func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        meshLog("OtaHomeKitDevice, accessory:\(accessory.name) didUpdateValueFor characteristicType:\(characteristic.characteristicType), value: \(String(describing: characteristic.value))")

        let data = characteristic.value as? Data
        if self.otaControlPointCharacteristic as? HMCharacteristic == characteristic {
            OtaUpgrader.shared.didUpdateValueFor(characteristic: .controlPointCharacteristic, value: data, error: nil)
        } else if self.otaDataCharacteristic as? HMCharacteristic == characteristic {
            OtaUpgrader.shared.didUpdateValueFor(characteristic: .dataCharacteristic, value: data, error: nil)
        } else if self.otaAppInfoCharacteristic as? HMCharacteristic == characteristic {
            OtaUpgrader.shared.didUpdateValueFor(characteristic: .appInfoCharacteristic, value: data, error: nil)
        }
    }

    public static func dumpHomeKitAccessory(_ accessory: HMAccessory) {
        meshLog("OtaHomeKitDevice, dumpHomeKitAccessory accessory: \(accessory)")
        meshLog("  isReachable: \(accessory.isReachable), isBlocked: \(accessory.isBlocked), isBridged: \(accessory.isBridged), service count: \(accessory.services.count)")
        for service in accessory.services {
            meshLog("  - accessory service: \(service.name), \(service)")
            // HMService uniqueIdentifier UUID, allocated by HomeKit framework.
            meshLog("    service.uniqueIdentifier: \(service.uniqueIdentifier)")
            // BLE Service UUID.
            meshLog("    service.serviceType: \(service.serviceType)")
            // Inlcuded BLE Service UUID.
            meshLog("    service.associatedServiceType: \(String(describing: service.associatedServiceType))")
            for characteristic in service.characteristics {
                meshLog("    - characteristic: \(characteristic)")
                // HMCharacteristic uniqueIdentifier UUID, allocated by HomeKit framework.
                meshLog("      characteristic.uniqueIdentifier: \(characteristic.uniqueIdentifier)")
                // BLE Characterisitic UUID.
                meshLog("      characteristic.characteristicType: \(characteristic.characteristicType)")
                meshLog("      characteristic.properties: \(characteristic.properties)")
            }
        }
    }
}
#endif  // #if os(iOS)
