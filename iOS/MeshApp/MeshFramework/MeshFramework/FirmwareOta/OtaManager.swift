/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * OTA management and interface implementation.
 */

import Foundation
import CoreBluetooth
#if false
import HomeKit
#endif

public enum OtaDeviceType {
    case ble
    case mesh
    case homeKit
}

public protocol OtaManagerDelegate {
    func onOtaDevicesUpdate()
}

public class OtaManager: NSObject {
    public static let shared = OtaManager()

    /* TODO[optional]:
     *      Show or disable BLE and HomeKit devices in the firmware devices list when mesh network has been openned.
     *      By default filterOutNonMeshDevicesWhenMeshNetworkOpened is set to true, so non-Mesh deviecs will be disabled when mesh network is opened.
     */
    public let filterOutNonMeshDevicesWhenMeshNetworkOpened = true

    public var isOtaScanning: Bool = false

    // indicates that the the otaUpgradeStart() has been executed.
    public var isOtaUpgrading: Bool {
        // When do OTA prepare fisrt, then do upgrade later, the OtaUpgrader.shared.isOtaUpgradeRunning is false between
        // prepare and upgarde, but the OtaUpgrader.shared.isOtaUpgradePrepareReady should be true if prepared success,
        // so, we need to monitor the network and connection changes.
        return (OtaUpgrader.shared.isOtaUpgradeRunning || OtaUpgrader.shared.isOtaUpgradePrepareReady)
    }
    // indicates the OTA Service has been discovered when isOtaUpgrading is true.
    public var isOtaDeviceConnected: Bool {
        return OtaUpgrader.shared.isDeviceConnected
    }
    public var shouldBlockingOtherGattProcess: Bool {
        guard isOtaUpgrading else {
            return false
        }

        if let otaDevice = OtaManager.shared.activeOtaDevice, otaDevice.getDeviceType() == .mesh {
            return false
        }
        return true
    }
    public var delegate: OtaManagerDelegate?

    #if false && os(iOS)
    // for discovering HomeKit devices for OTA.
    private var mHMAccessoryBrowser: HMAccessoryBrowser?
    private var mHomeManager: HMHomeManager?
    #endif  // #if os(iOS)

    private var mOtaDevices: [OtaDeviceProtocol] = []
    public var otaDevices: [OtaDeviceProtocol] {
        return mOtaDevices
    }

    public var activeOtaDevice: OtaDeviceProtocol?

    public override init() {
        super.init()
        #if false && os(iOS)
        self.mHMAccessoryBrowser = HMAccessoryBrowser()
        self.mHMAccessoryBrowser?.delegate = self
        #endif // #if os(iOS)
    }

    // TODO
    public func waitingForHomeKitPreInit() {
        #if false && os(iOS)
        // on iPad device, it must be initialized in main thread, and it will take long time for the first time.
        //TODO: need to fix "Main Thread Checker: UI API called on a background thread: -[UIApplication applicationState]" issue.
        let supportHomeKitDevices = false  // Do NOT support HomeKit currently.
        guard supportHomeKitDevices else {
            return
        }
        if self.mHomeManager == nil {
            self.mHomeManager = HMHomeManager()
            self.mHomeManager?.delegate = self
        }
        #endif // #if os(iOS)
    }

    public func startScan() {
        isOtaScanning = true
        didUpdateMeshDevices()
        MeshGattClient.shared.startScan()
        #if false && os(iOS)
        self.mHMAccessoryBrowser?.startSearchingForNewAccessories()
        if hmHomeManager != nil, self.mHomeManager == nil {
            self.mHomeManager = hmHomeManager
        }
        #endif  // #if os(iOS)
    }

    public func stopScan() {
        isOtaScanning = false
        #if false && os(iOS)
        mHMAccessoryBrowser?.stopSearchingForNewAccessories()
        #endif  // #if os(iOS)
        MeshGattClient.shared.stopScan()
    }

    public func clearOtaDevices() {
        mOtaDevices.removeAll()
    }

    public func resetOtaUpgradeStatus() {
        OtaUpgrader.shared.otaUpgradeStatusReset()
    }

    public func dumpOtaStatus() {
        OtaUpgrader.shared.dumpOtaUpgradeStatus()
        print("dumpOtaStatus, isOtaScanning:\(isOtaScanning), shouldBlockingOtherGattProcess:\(OtaManager.shared.shouldBlockingOtherGattProcess)")
    }

    static public func getOtaDeviceTypeString(by deviceType: OtaDeviceType) -> String {
        switch deviceType {
        case .ble:
            return "LE"
        case .homeKit:
            return "HM"
        case .mesh:
            return "M"
        }
    }

    public func didUpdateMeshDevices() {
        if let networkName = MeshFrameworkManager.shared.getOpenedMeshNetworkName(),
            let components = MeshFrameworkManager.shared.getlAllMeshGroupComponents(groupName: networkName) {
            for component in components {
                // create mesh ota device instance.
                self.addOtaDevice(device: OtaMeshDevice(meshName: component))
            }
        }
    }

    #if false && os(iOS)
    public func didUpdateHomeKitDevices() {
        for home in mHomeManager?.homes ?? [] {
            for accessory in home.accessories {
                print("home: \(home.name), \(accessory), service.count=\(accessory.services.count)")
                if validAccessoryFilter(accessory) {
                    self.addOtaDevice(device: OtaHomeKitDevice(accessory: accessory))
                }
            }
        }

        for accessory in mHMAccessoryBrowser?.discoveredAccessories ?? [] {
            print("discoveredAccessories, \(accessory), service.count=\(accessory.services.count)")
            if validAccessoryFilter(accessory) {
                if validAccessoryFilter(accessory) {
                    self.addOtaDevice(device: OtaHomeKitDevice(accessory: accessory))
                }
            }
        }
    }
    #endif  // #if os(iOS)

    func addOtaDevice(device: OtaDeviceProtocol) {
        let deviceType = device.getDeviceType()

        #if false && os(iOS)
        if deviceType == .homeKit, let newDevice = device as? OtaHomeKitDevice {
            for existDevice in mOtaDevices {
                if let addedDevice = existDevice as? OtaHomeKitDevice, let newAccessory = newDevice.otaDevice as? HMAccessory,
                    let existAccessory = addedDevice.otaDevice as? HMAccessory, newAccessory.uniqueIdentifier == existAccessory.uniqueIdentifier {
                    return  // this device has been added, skip.
                }
            }

            // The device is new, add it.
            mOtaDevices.append(device)
            // Call the notification callback about the devices udpated if required.
            delegate?.onOtaDevicesUpdate()
            return
        }
        #endif  // #if os(iOS)

        if deviceType == .mesh, let newDevice = device as? OtaMeshDevice {
            for existDevice in mOtaDevices {
                if let addedDevice = existDevice as? OtaMeshDevice, newDevice.getDeviceName() == addedDevice.getDeviceName() {
                    return  // this device has been added, skip.
                }
            }
        } else if deviceType == .ble, let newDevice = device as? OtaBleDevice {
            for existDevice in mOtaDevices {
                if let addedDevice = existDevice as? OtaBleDevice, let newPeripheral = newDevice.otaDevice as? CBPeripheral,
                    let existPeripheral = addedDevice.otaDevice as? CBPeripheral, newPeripheral.identifier == existPeripheral.identifier {
                    return  // this device has been added, skip.
                }
            }
        }

        // The device is new, add it.
        mOtaDevices.append(device)
        // Call the notification callback about the devices udpated if required.
        delegate?.onOtaDevicesUpdate()
    }

    func validPeripheralFilter(_ peripheral: CBPeripheral) -> Bool {
        // TODO [opetional]:
        //      Add the peripheral device filter here is necessory.
        //      Return true will be added to OTA device list, otherwise will be ignored.
        if MeshFrameworkManager.shared.getOpenedMeshNetworkName() != nil {
            return !OtaManager.shared.filterOutNonMeshDevicesWhenMeshNetworkOpened
        }
        return true
    }

    #if false && os(iOS)
    func validAccessoryFilter(_ accessory: HMAccessory) -> Bool {
        // TODO [opetional]:
        //      the accessory device filter here is necessory.
        //      Return true will be added to OTA device list, otherwise will be ignored.
        //  e.g.: filter based on device name.
        if !accessory.isReachable {
            return false
        }
        if MeshFrameworkManager.shared.getOpenedMeshNetworkName() != nil {
            return !OtaManager.shared.filterOutNonMeshDevicesWhenMeshNetworkOpened
        }
        return true
    }
    #endif  // os(iOS)

    func getOtaUpgraderInstance() -> OtaUpgraderProtocol? {
        guard let _ = self.activeOtaDevice else {
            print("error: OtaManager, getActiveOtaUpgraderInstance, activeOtaDeviceDelegate is nil")
            return nil
        }

        return OtaUpgrader.shared
    }
}

// Manage devices and operations through Bluetooth GATT protocol.
extension OtaManager {
    ///
    /// CBCentralManagerDelegate callbacks
    ///

    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("OtaManager, centralManager didDiscover peripheral, isOtaUpgrading:\(self.isOtaUpgrading), isOtaDeviceConnected:\(self.isOtaDeviceConnected), isOtaScanning:\(self.isOtaScanning)")
        guard self.isOtaScanning else {
            return
        }

        // must be connectale device.
        guard let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool, connectable else {
            return
        }

        print("OtaManager, centralManager didDiscover peripheral, \(peripheral), rssi=\(RSSI), \(advertisementData)")
        if MeshNativeHelper.isMeshProxyServiceAdvertisementData(advertisementData) {
            // all provisioined mesh devices are reterived through mesh network, so bypass all active provsioned mesh devices.
            return
        }

        if validPeripheralFilter(peripheral) {
            self.addOtaDevice(device: OtaBleDevice(peripheral: peripheral))
        }
    }

    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("OtaManager, centralManager didConnect peripheral, isOtaUpgrading:\(self.isOtaUpgrading), isOtaDeviceConnected:\(self.isOtaDeviceConnected)")
        self.activeOtaDevice?.otaDevice = peripheral
        // For mesh device, the connect event should be processed in the meshClientConnectComponent() callback function.
        if self.isOtaUpgrading, let otaDevice = self.activeOtaDevice, otaDevice.getDeviceType() != .mesh {
            print("OtaManager, centralManager didConnect peripheral:\(peripheral), otaDevice:\(otaDevice)")
            self.getOtaUpgraderInstance()?.didUpdateConnectionState(isConnected: true, error: nil)
        }
    }

    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("OtaManager, centralManager didFailToConnect peripheral, isOtaUpgrading:\(self.isOtaUpgrading), isOtaDeviceConnected:\(self.isOtaDeviceConnected)")
        self.activeOtaDevice?.otaDevice = nil
        if self.isOtaUpgrading {
            print("OtaManager, centralManager didFailToConnect peripheral, \(peripheral), \(String(describing: error))")
            self.getOtaUpgraderInstance()?.didUpdateConnectionState(isConnected: false, error: error)
        }
    }

    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("OtaManager, centralManager didDisconnectPeripheral peripheral, isOtaUpgrading:\(self.isOtaUpgrading), isOtaDeviceConnected:\(self.isOtaDeviceConnected)")
        self.activeOtaDevice?.otaDevice = nil
        if self.isOtaUpgrading, self.isOtaDeviceConnected {
            print("OtaManager, centralManager didDisconnectPeripheral peripheral, \(peripheral), \(String(describing: error))")
            self.getOtaUpgraderInstance()?.didUpdateConnectionState(isConnected: false, error: error)
        }
    }

    ///
    /// CBPeripheralDelegate callbacks
    ///

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("OtaManager, peripheral didDiscoverServices, isOtaUpgrading:\(self.isOtaUpgrading), isOtaDeviceConnected:\(self.isOtaDeviceConnected)")
        guard self.isOtaUpgrading, self.isOtaDeviceConnected else {
            return
        }

        print("OtaManager, peripheral didDiscoverServices, \(peripheral), error:\(String(describing: error))")
        guard error == nil, let services = peripheral.services, services.count > 0 else {
            self.getOtaUpgraderInstance()?.didUpdateOtaServiceCharacteristicState(isDiscovered: false, error: error)
            self.activeOtaDevice?.disconnect()
            return
        }

        for (i,srv) in services.enumerated() {
            print("OtaManager, peripheral didDiscoverServices, \(i): \(srv.uuid.description)")
        }

        if let service: CBService = services.filter({OtaConstants.UUID_GATT_OTA_SERVICES.contains($0.uuid)}).first {
            self.activeOtaDevice?.otaService = service
            print("OtaManager, peripheral didDiscoverServices, GATT OTA Service found. OTA Version: OTA_VERSION_\(service.uuid == OtaConstants.BLE_V2.UUID_SERVICE_UPGRADE ? OtaConstants.OTA_VERSION_2 : OtaConstants.OTA_VERSION_1)")

            peripheral.discoverCharacteristics(nil, for: service)
        } else {
            print("OtaManager, peripheral didDiscoverServices, GATT OTA Service not found")
            self.getOtaUpgraderInstance()?.didUpdateOtaServiceCharacteristicState(isDiscovered: false, error: nil)
            self.activeOtaDevice?.disconnect()
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("OtaManager, peripheral didDiscoverCharacteristicsFor, isOtaUpgrading:\(self.isOtaUpgrading), isOtaDeviceConnected:\(self.isOtaDeviceConnected)")
        guard let activeOtaDevice = self.activeOtaDevice, self.isOtaUpgrading, self.isOtaDeviceConnected else {
            return
        }

        print("OtaManager, peripheral didDiscoverCharacteristicsFor service:\(service), error:\(String(describing: error))")
        guard error == nil else {
            self.getOtaUpgraderInstance()?.didUpdateOtaServiceCharacteristicState(isDiscovered: false, error: error)
            self.activeOtaDevice?.disconnect()
            return
        }

        if let characteristics = service.characteristics {
            let supportControlPointUuids = [OtaConstants.BLE.UUID_CHARACTERISTIC_CONTROL_POINT, OtaConstants.BLE_V2.UUID_CHARACTERISTIC_CONTROL_POINT]
            if let characteristic: CBCharacteristic = characteristics.filter({supportControlPointUuids.contains($0.uuid)}).first {
                print("OtaManager, peripheral didDiscoverCharacteristicsFor service, OTA Control Point characteristic found")
                self.activeOtaDevice?.otaControlPointCharacteristic = characteristic
            }

            let supportDataUuids = [OtaConstants.BLE.UUID_CHARACTERISTIC_DATA, OtaConstants.BLE_V2.UUID_CHARACTERISTIC_DATA]
            if let characteristic: CBCharacteristic = characteristics.filter({supportDataUuids.contains($0.uuid)}).first {
                print("OtaManager, peripheral didDiscoverCharacteristicsFor service, OTA Data characteristic found")
                self.activeOtaDevice?.otaDataCharacteristic = characteristic
            }

            let supportAppInfoUuids = [OtaConstants.BLE.UUID_CHARACTERISTIC_APP_INFO, OtaConstants.BLE_V2.UUID_CHARACTERISTIC_APP_INFO]
            if let characteristic: CBCharacteristic = characteristics.filter({supportAppInfoUuids.contains($0.uuid)}).first {
                print("OtaManager, peripheral didDiscoverCharacteristicsFor service, OTA App Info characteristic found")
                self.activeOtaDevice?.otaAppInfoCharacteristic = characteristic
            }
        }

        if activeOtaDevice.otaControlPointCharacteristic != nil, activeOtaDevice.otaDataCharacteristic != nil {
            print("OtaManager, peripheral didDiscoverCharacteristicsFor service, all OTA characteristic found in the service")
            if let appInfoCharacteristic = activeOtaDevice.otaAppInfoCharacteristic as? CBCharacteristic {
                peripheral.readValue(for: appInfoCharacteristic)
            } else {
                self.getOtaUpgraderInstance()?.didUpdateOtaServiceCharacteristicState(isDiscovered: true, error: nil)
            }
        } else {
            print("error: OtaManager, peripheral didDiscoverCharacteristicsFor service, no characteristic found in the service")
            self.getOtaUpgraderInstance()?.didUpdateOtaServiceCharacteristicState(isDiscovered: false, error: nil)
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let supportControlPointUuids = [OtaConstants.BLE.UUID_CHARACTERISTIC_CONTROL_POINT, OtaConstants.BLE_V2.UUID_CHARACTERISTIC_CONTROL_POINT]
        if !supportControlPointUuids.contains(characteristic.uuid) {
            return
        }

        print("OtaManager, peripheral didUpdateNotificationStateFor characteristic, isOtaUpgrading:\(self.isOtaUpgrading), isOtaDeviceConnected:\(self.isOtaDeviceConnected)")
        guard self.isOtaUpgrading, self.isOtaDeviceConnected else {
            return
        }

        print("OtaManager, peripheral didUpdateNotificationStateFor characteristic=\(characteristic)")
        guard let activeOtaDevice = self.activeOtaDevice else {
            print("error: OtaManager, peripheral didUpdateNotificationStateFor characteristic, activeOtaDevice is nil")
            return
        }
        guard activeOtaDevice.otaControlPointCharacteristic as? CBCharacteristic == characteristic else {
            print("warnnig: OtaManager, peripheral didUpdateNotificationStateFor characteristic, not Control Point characteristic")
            return
        }
        guard error == nil else {
            print("error: OtaManager, peripheral didUpdateNotificationStateFor characteristic, failed to enable notification, error:\(String(describing: error))")
            self.getOtaUpgraderInstance()?.didUpdateNotificationState(isEnabled: false, error: error)
            activeOtaDevice.disconnect()
            return
        }
        guard characteristic.isNotifying else {
            print("error: OtaManager, peripheral didUpdateNotificationStateFor characteristic, notification not enabled, isNotifying=\(characteristic.isNotifying)")
            self.getOtaUpgraderInstance()?.didUpdateNotificationState(isEnabled: false, error: error)
            activeOtaDevice.disconnect()
            return
        }

        self.getOtaUpgraderInstance()?.didUpdateNotificationState(isEnabled: true, error: nil)
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard self.isOtaUpgrading, self.isOtaDeviceConnected else {
            return
        }
        print("OtaManager, peripheral didDiscoverDescriptorsFor characteristic=\(characteristic)")
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard self.isOtaDeviceConnected else {
            return
        }
        print("OtaManager, peripheral didUpdateValueFor descriptor=\(descriptor)")
    }

    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard self.isOtaUpgrading, self.isOtaDeviceConnected else {
            return
        }
        print("OtaManager, peripheral didWriteValueFor descriptor=\(descriptor)")
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("OtaManager, peripheral didUpdateValueFor characteristic, isOtaUpgrading:\(self.isOtaUpgrading), isOtaDeviceConnected:\(self.isOtaDeviceConnected)")
        guard self.isOtaUpgrading, self.isOtaDeviceConnected else {
            return
        }
        guard let activeOtaDevice = self.activeOtaDevice else {
            print("error: OtaManager, peripheral didUpdateValueFor characteristic, activeOtaDevice is nil")
            return
        }

        var data = characteristic.value
        if activeOtaDevice.getDeviceType() == .mesh, let encryptedData = data  {
            // decrpypt mesh data before send to OtaUpgrader.
            data = MeshFrameworkManager.shared.meshClientOtaDataDecrypt(componenetName: activeOtaDevice.getDeviceName(), data: encryptedData)
        }

        if activeOtaDevice.otaControlPointCharacteristic as? CBCharacteristic == characteristic {
            self.getOtaUpgraderInstance()?.didUpdateValueFor(characteristic: .controlPointCharacteristic, value: data, error: error)
        } else if activeOtaDevice.otaDataCharacteristic as? CBCharacteristic == characteristic {
            self.getOtaUpgraderInstance()?.didUpdateValueFor(characteristic: .dataCharacteristic, value: data, error: error)
        } else if activeOtaDevice.otaAppInfoCharacteristic as? CBCharacteristic == characteristic {
            self.getOtaUpgraderInstance()?.didUpdateValueFor(characteristic: .appInfoCharacteristic, value: data, error: error)
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard self.isOtaUpgrading, self.isOtaDeviceConnected else {
            return
        }

        guard let activeOtaDevice = self.activeOtaDevice else {
            print("error: OtaManager, peripheral didWriteValueFor characteristic, activeOtaDevice is nil")
            return
        }

        if activeOtaDevice.otaControlPointCharacteristic as? CBCharacteristic == characteristic {
            activeOtaDevice.didWriteValue(for: .controlPointCharacteristic, error: error)
        } else if activeOtaDevice.otaDataCharacteristic as? CBCharacteristic == characteristic {
            activeOtaDevice.didWriteValue(for: .dataCharacteristic, error: error)
        } else if activeOtaDevice.otaAppInfoCharacteristic as? CBCharacteristic == characteristic {
            activeOtaDevice.didWriteValue(for: .appInfoCharacteristic, error: error)
        }
    }
}

#if false && os(iOS)
// Manage devices and operations through HomeKit protocol.
extension OtaManager: HMAccessoryBrowserDelegate, HMHomeManagerDelegate {
    public func accessoryBrowser(_ browser: HMAccessoryBrowser, didFindNewAccessory accessory: HMAccessory) {
        print("OtaDeviceManager, accessoryBrowser, HMAccessoryBrowser, didFindNewAccessory accessory: \(accessory)")
        didUpdateHomeKitDevices()
    }

    public func accessoryBrowser(_ browser: HMAccessoryBrowser, didRemoveNewAccessory accessory: HMAccessory) {
        print("OtaDeviceManager, accessoryBrowser, HMAccessoryBrowser, didRemoveNewAccessory accessory: \(accessory)")
        didUpdateHomeKitDevices()
    }

    public func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        print("OtaDeviceManager, homeManager, didAdd home: \(home.name)")
        didUpdateHomeKitDevices()
    }

    public func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        print("OtaDeviceManager, homeManager, didRemove home: \(home.name)")
        didUpdateHomeKitDevices()
    }

    public func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        print("OtaDeviceManager, homeManager, DidUpdateHomes")
        didUpdateHomeKitDevices()
    }

    public func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager) {
        print("OtaDeviceManager, homeManager, DidUpdatePrimaryHome")
        didUpdateHomeKitDevices()
    }
}
#endif  // #if os(iOS)
