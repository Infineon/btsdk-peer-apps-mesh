/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * This file implements the MeshGattClient class wrap all iOS platform specific Bluetooth operations.
 */

import Foundation
import CoreBluetooth

open class MeshGattClient: NSObject {
    public static let shared = MeshGattClient()

    public let centralManager = CBCentralManager()
    private let serialQueue = DispatchQueue(label: "MeshGattClient-serialQueue")

    private var unprovisionedDeviceList: [[String: UUID]] = []
    private var isScanningUnprovisionedDevice: Bool = false

    var mGattService:CBService?
    var mGattDataInCharacteristic:CBCharacteristic?
    var mGattDataOutCharacteristic:CBCharacteristic?

    var mGattEstablishedConnectionCount: Int = 0 {
        didSet {
            print("MeshGattClient, mGattEstablishedConnectionCount=\(mGattEstablishedConnectionCount)")
            // Currently, with the support of the mesh library, only one connection can be established at any time
            // between the provisioner and target mesh device.
            if mGattEstablishedConnectionCount < 0 {
                mGattEstablishedConnectionCount = MeshConstants.MESH_CONNECTION_ID_DISCONNECTED
            } else if mGattEstablishedConnectionCount > 1 {
                mGattEstablishedConnectionCount = MeshConstants.MESH_CONNECTION_ID_CONNECTED
            }
        }
    }

    var doOtaUpgrade: Bool = false

    public override init() {
        super.init()
        centralManager.delegate = self
    }

    open func startScan() {
        if centralManager.state == .poweredOn {
            print("MeshGattClient, BLE scan started, isOtaScanning: \(OtaManager.shared.isOtaScanning)")
            if false, centralManager.isScanning {
                centralManager.stopScan()   // stop scanning before connecting to make connecting stable and fast in provisioning.
            }
            let serviceUUIDs = OtaManager.shared.isOtaScanning ? nil : [MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING, MeshUUIDConstants.UUID_SERVICE_MESH_PROXY]
            centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
        } else {
            print("MeshGattClient, BLE scan not supported, centralManager.state=\(centralManager.state.rawValue), isScanning=\(centralManager.isScanning)")
        }
    }

    open func stopScan() {
        if centralManager.state == .poweredOn {
            print("MeshGattClient, BLE scan stopped")
            centralManager.stopScan()
        } else {
            print("MeshGattClient, BLE not pwered on, centralManager.state=\(centralManager.state.rawValue), isScanning=\(centralManager.isScanning)")
        }
    }

    open func connect(peripheral: CBPeripheral) {
        print("MeshGattClient, connect, connecting to mesh device, \(peripheral)")
        if centralManager.state == .poweredOn {
            if peripheral.state == .disconnected {
                centralManager.connect(peripheral, options: nil)
            } else {
                print("error: MeshGattClient, connect, invalid centralManager.state=\(centralManager.state.rawValue), connection cancelled, please try again")
                centralManager.cancelPeripheralConnection(peripheral)
            }
        } else {
            print("error: MeshGattClient, connect, invalid centralManager.state=\(centralManager.state.rawValue)")
        }
    }

    open func disconnect(peripheral: CBPeripheral) {
        print("MeshGattClient, disconnect, disconnecting from mesh device, \(peripheral)")
        if centralManager.state == .poweredOn {
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            print("warnning: MeshGattClient, disconnect, invalid centralManager.state=\(centralManager.state.rawValue)")
        }
    }

    func retrievePeripheral(identifier: UUID) -> CBPeripheral? {
        guard let peripheral: CBPeripheral = centralManager.retrievePeripherals(withIdentifiers: [identifier]).first else {
            return nil
        }
        return peripheral
    }

    func writeData(for peripheral:CBPeripheral, serviceUUID: CBUUID, data: Data) {
        guard let service = peripheral.services?.filter({$0.uuid == serviceUUID}).first else {
            print("error: MeshGattClient, writeData, invalid peripheral service nil")
            return
        }

        var characteristic: CBCharacteristic?
        switch serviceUUID {
        case MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING:
            characteristic = service.characteristics?.filter({$0.uuid == MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN}).first
            print("\(characteristic == nil ? "error: " : "")MeshGattClient, writeData, PROVISIONING_DATA_IN characteristic=\(String(describing: characteristic))")
        case MeshUUIDConstants.UUID_SERVICE_MESH_PROXY:
            characteristic = service.characteristics?.filter({$0.uuid == MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN}).first
            print("\(characteristic == nil ? "error: " : "")MeshGattClient, writeData, PROXY_DATA_IN characteristic=\(String(describing: characteristic))")
        default:
            print("error: MeshGattClient, writeData, invalid target characteristic=\(String(describing: characteristic))")
            break
        }

        if let targetCharacteristic = characteristic {
            serialQueue.sync {
                print("MeshGattClient, writeData, withoutResponse, data=\(data.dumpHexBytes())")
                peripheral.writeValue(data, for: targetCharacteristic, type: .withoutResponse)
            }
        }
    }
}

extension MeshGattClient {
    open func scanUnprovisionedDeviceStart() {
        if isScanningUnprovisionedDevice {
            scanUnprovisionedDeviceStop()
        }

        isScanningUnprovisionedDevice = true
        clearUnprovisionedDeviceList()
        MeshFrameworkManager.shared.meshClientScanUnprovisionedDevice(start: true)
    }

    open func scanUnprovisionedDeviceStop() {
        MeshFrameworkManager.shared.meshClientScanUnprovisionedDevice(start: false)
        isScanningUnprovisionedDevice = false
    }

    open func onUnprovisionedDeviceFound(uuid: UUID, oob: UInt16, uriHash: UInt32, name: String) {
        let newDevice = [name: uuid]
        let storedDevice = unprovisionedDeviceList.filter { ($0.values.first == uuid) }
        if !unprovisionedDeviceList.contains(newDevice), storedDevice.isEmpty {
            print("MeshGattClient, addUnprovisionedDevice, name:\(name), uuid:\(uuid.uuidString)")
            unprovisionedDeviceList.append(newDevice)
            NotificationCenter.default.post(name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_DEVICE_FOUND),
                                            object: nil,
                                            userInfo: [MeshNotificationConstants.USER_INFO_KEY_DEVICE_UUID: uuid,
                                                       MeshNotificationConstants.USER_INFO_KEY_DEVICE_OOB: oob,
                                                       MeshNotificationConstants.USER_INFO_KEY_DEVICE_URI_HASH: uriHash,
                                                       MeshNotificationConstants.USER_INFO_KEY_DEVICE_NAME: name])
        }
    }

    open func removeUnprovisionedDevice(uuid: UUID) {
        for (index, device) in unprovisionedDeviceList.enumerated() {
            for (name, uuid) in device {
                if uuid == uuid {
                    print("MeshGattClient, removeUnprovisionedDevice, name:\(name), uuid:\(uuid.uuidString)")
                    unprovisionedDeviceList.remove(at: index)
                    return
                }
            }
        }
    }

    open func clearUnprovisionedDeviceList() {
        print("MeshGattClient, clearUnprovisionedDeviceList")
        unprovisionedDeviceList.removeAll()
    }

    open func getUnprovisionDeviceList() -> [[String: UUID]] {
        return unprovisionedDeviceList
    }
}

extension MeshGattClient: CBCentralManagerDelegate {
    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("info: MeshGattClient, centralManagerDidUpdateState, central.state=\(central.state.rawValue), .poweredon")
            // Automatcailly connect to the mesh network when the Bluetooth is turned on.
            mGattEstablishedConnectionCount = 0
            MeshNativeHelper.setCurrentConnectedPeripheral(nil)
            if let _ = MeshFrameworkManager.shared.getOpenedMeshNetworkName() {
                MeshFrameworkManager.shared.connectMeshNetwork { (isConnected: Bool, connId: Int, addr: Int, isOverGatt: Bool, error: Int) in
                    print("MeshGattClient, automatically connectingToMeshNetwork completion, isConnected:\(isConnected), connId:\(connId), addr:\(addr), isOverGatt:\(isOverGatt), error:\(error)")
                }
            }
            break
        case .poweredOff, .resetting:
            print("info: MeshGattClient, centralManagerDidUpdateState, central.state=\(central.state.rawValue), .poweredoff")
            // Disconnectted from the mesh network when the Bluetooth is turned off.
            mGattEstablishedConnectionCount = 0
            MeshNativeHelper.setCurrentConnectedPeripheral(nil)
            MeshFrameworkManager.shared.meshClientConnectionStateChanged(connId: mGattEstablishedConnectionCount)
            break
        default:
            print("error: MeshGattClient, centralManagerDidUpdateState, unsupported central.state=\(central.state.rawValue)")
        }
    }

    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if OtaManager.shared.isOtaScanning {
            OtaManager.shared.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        print("MeshGattClient, centralManager didDiscover peripheral, \(peripheral), rssi=\(RSSI), \(advertisementData)")
        if (!MeshNativeHelper.isMeshAdvertisementData(advertisementData)) {
            return
        }
        MeshFrameworkManager.shared.meshClientAdvertisementDataReport(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("MeshGattClient, centralManager didConnect peripheral, \(peripheral)")
        mGattEstablishedConnectionCount += 1
        peripheral.delegate = self
        MeshNativeHelper.setCurrentConnectedPeripheral(peripheral)
        // do not notify connection state change here, do it only after the service, characteristic, and notification is discovered and enabled.

        if OtaManager.shared.isOtaUpgrading {
            OtaManager.shared.centralManager(central, didConnect: peripheral)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        // try to discovery mesh provisioning/proxy service and characteristics.
        peripheral.discoverServices(nil)
    }

    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("error: MeshGattClient, centralManager didFailToConnect peripheral, \(peripheral), \(String(describing: error))")
        MeshNativeHelper.setCurrentConnectedPeripheral(nil)

        if OtaManager.shared.isOtaUpgrading {
            OtaManager.shared.centralManager(central, didFailToConnect: peripheral, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }
    }

    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("MeshGattClient, centralManager didDisconnectPeripheral peripheral, \(peripheral), \(String(describing: error))")
        mGattEstablishedConnectionCount -= 1
        MeshNativeHelper.setCurrentConnectedPeripheral(nil)

        MeshFrameworkManager.shared.meshClientConnectionStateChanged(connId: mGattEstablishedConnectionCount)

        if OtaManager.shared.isOtaUpgrading {
            OtaManager.shared.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }
    }
}

extension MeshGattClient: CBPeripheralDelegate {
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if OtaManager.shared.isOtaUpgrading, let _ = peripheral.services?.filter({OtaConstants.UUID_GATT_OTA_SERVICES.contains($0.uuid)}).first {
            OtaManager.shared.peripheral(peripheral, didDiscoverServices: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        print("MeshGattClient, peripheral didDiscoverServices, \(peripheral)")
        if let error = error {
            print("error: MeshGattClient, peripheral didDiscoverServices with \(error)")
            disconnect(peripheral: peripheral)
            return
        }
        guard let services = peripheral.services, services.count > 0 else {
            print("error: MeshGattClient, peripheral didDiscoverServices, no Service found")
            disconnect(peripheral: peripheral)
            return
        }

        if MeshFrameworkManager.shared.isMeshProvisionConnecting() {
            // Connecting to Mesh Provisioning Sevice
            if let service: CBService = services.filter({$0.uuid == MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING}).first {
                mGattService = service
                print("MeshGattClient, peripheral didDiscoverServices, found Mesh Provisioning Service")

                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                print("error: MeshGattClient, peripheral didDiscoverServices, no Mesh Provisioning Service found")
                disconnect(peripheral: peripheral)
            }
        } else {
            // Connecting to Mesh Proxy Service
            if let service: CBService = services.filter({$0.uuid == MeshUUIDConstants.UUID_SERVICE_MESH_PROXY}).first {
                mGattService = service
                print("MeshGattClient, peripheral didDiscoverServices, found Mesh Proxy Service")

                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                print("error: MeshGattClient, peripheral didDiscoverServices, no Mesh Proxy Service found")
                disconnect(peripheral: peripheral)
            }
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_SERVICES.filter({service.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        if service.uuid != MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING && service.uuid != MeshUUIDConstants.UUID_SERVICE_MESH_PROXY {
            return
        }

        print("MeshGattClient, peripheral didDiscoverCharacteristicsFor service=\(service)")
        if let error = error {
            print("error: MeshGattClient, peripheral didDiscoverCharacteristicsFor service with \(error)")
            disconnect(peripheral: peripheral)
            return
        }

        if let characteristics = service.characteristics {
            let dataIn = MeshFrameworkManager.shared.isMeshProvisionConnecting() ?
                MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN :
                MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN
            if let characteristic: CBCharacteristic = characteristics.filter({$0.uuid == dataIn}).first {
                mGattDataInCharacteristic = characteristic
                print("MeshGattClient, peripheral didDiscoverServices, found Mesh Data In characteristic")
            } else {
                print("error: MeshGattClient, peripheral didDiscoverServices, no Mesh Data In characteristic found")
                disconnect(peripheral: peripheral)
                return
            }


            let dataOut = MeshFrameworkManager.shared.isMeshProvisionConnecting() ?
                MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_OUT :
                MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_OUT
            if let characteristic: CBCharacteristic = characteristics.filter({$0.uuid == dataOut}).first {
                mGattDataOutCharacteristic = characteristic
                print("MeshGattClient, peripheral didDiscoverServices, found Mesh Data Out characteristic")

                // Must enable the notification for the Mesh Data Out characteristic.
                peripheral.setNotifyValue(true, for: characteristic)
            } else {
                print("error: MeshGattClient, peripheral didDiscoverServices, no Mesh Data Out characteristic found")
                disconnect(peripheral: peripheral)
                return
            }
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_CHARACTERISTICS.filter({characteristic.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        print("MeshGattClient, peripheral didUpdateNotificationStateFor characteristic=\(characteristic)")
        if let error = error {
            print("error: MeshGattClient, peripheral didUpdateNotificationStateFor characteristic with \(error)")
            disconnect(peripheral: peripheral)
            return
        }

        if characteristic.isNotifying {
            if MeshFrameworkManager.shared.isMeshProvisionConnecting(){
                print("MeshGattClient, all the Mesh Provisioning Service and Characteristics found and notification are enabled successfully ")
            } else {
                print("MeshGattClient, all the Mesh Proxy Service and Characteristics found and notification are enabled successfully ")
            }

            MeshFrameworkManager.shared.meshClientSetGattMtuSize()
            MeshFrameworkManager.shared.meshClientConnectionStateChanged(connId: mGattEstablishedConnectionCount)
        } else {
            print("error: MeshGattClient, peripheral didUpdateNotificationStateFor characteristic, invalid status of characteristic.isNotifying=\(characteristic.isNotifying)")
            disconnect(peripheral: peripheral)
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_CHARACTERISTICS.filter({characteristic.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didDiscoverDescriptorsFor: characteristic, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        print("MeshGattClient, peripheral didDiscoverDescriptorsFor characteristic=\(characteristic)")
        if let error = error {
            print("error: MeshGattClient, peripheral didDiscoverDescriptorsFor characteristic with \(error)")
            disconnect(peripheral: peripheral)
            return
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_DESCRIPTORS.filter({descriptor.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didUpdateValueFor: descriptor, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        print("MeshGattClient, peripheral didUpdateValueFor descriptor=\(descriptor)")
        if let error = error {
            print("error: MeshGattClient, peripheral didUpdateValueFor descriptor with \(error)")
            disconnect(peripheral: peripheral)
            return
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_DESCRIPTORS.filter({descriptor.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didWriteValueFor: descriptor, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        print("MeshGattClient, peripheral didWriteValueFor descriptor=\(descriptor)")
        if let error = error {
            print("error: MeshGattClient, peripheral didWriteValueFor descriptor with \(error)")
            disconnect(peripheral: peripheral)
            return
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_CHARACTERISTICS.filter({characteristic.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        print("MeshGattClient, peripheral didUpdateValueFor characteristic=\(characteristic)")
        if let error = error {
            print("error: MeshGattClient, peripheral didUpdateValueFor characteristic with \(error)")
            disconnect(peripheral: peripheral)
            return
        }

        guard let service = peripheral.services, let data = characteristic.value else {
            print("error: MeshGattClient, peripheral didUpdateValueFor characteristic, invalid sevice or data is nil")
            return
        }

        if let _ = service.filter({$0.uuid == MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING}).first {
            print("MeshGattClient, peripheral didUpdateValueFor characteristic, sendReceivedProvisionPacketToMeshCore, data=\(data.dumpHexBytes())")
            MeshFrameworkManager.shared.sendReceivedProvisionPacketToMeshCore(data: data)
        }

        if let _ = service.filter({$0.uuid == MeshUUIDConstants.UUID_SERVICE_MESH_PROXY}).first {
            print("MeshGattClient, peripheral didUpdateValueFor characteristic, sendReceivedProxyPacketToMeshCore, data=\(data.dumpHexBytes())")
            MeshFrameworkManager.shared.sendReceivedProxyPacketToMeshCore(data: data)
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_CHARACTERISTICS.filter({characteristic.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        print("MeshGattClient, peripheral didWriteValueFor characteristic=\(characteristic)")
        if let error = error {
            print("error: MeshGattClient, peripheral didWriteValueFor characteristic with \(error)")
            disconnect(peripheral: peripheral)
            return
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        print("MeshGattClient, peripheral didReadRSSI, RSSI=\(RSSI), \(String(describing: error))")
    }

    open func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("MeshGattClient, peripheral didModifyServices, \(peripheral), invalidatedServices=\(invalidatedServices)")
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        print("MeshGattClient, peripheral didDiscoverIncludedServicesFor, \(peripheral), service=\(service), \(String(describing: error))")
    }

    open func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        print("MeshGattClient, peripheralDidUpdateName, \(peripheral)")
    }
}
