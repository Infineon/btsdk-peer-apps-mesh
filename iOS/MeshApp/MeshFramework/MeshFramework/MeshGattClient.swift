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
            meshLog("MeshGattClient, mGattEstablishedConnectionCount=\(mGattEstablishedConnectionCount)")
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
            MeshNativeHelper.meshClientLog("[MeshGattClient stopScan] BLE scan started, isOtaScanning: \(OtaManager.shared.isOtaScanning)")
            let serviceUUIDs = OtaManager.shared.isOtaScanning ? nil : [MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING, MeshUUIDConstants.UUID_SERVICE_MESH_PROXY]
            centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
        } else {
            MeshNativeHelper.meshClientLog("[MeshGattClient stopScan] warning: BLE scan not supported, invalid centralManager.state=\(centralManager.state.rawValue), isScanning=\(centralManager.isScanning)")
        }
    }

    open func stopScan() {
        if centralManager.state == .poweredOn {
            centralManager.stopScan()
            MeshNativeHelper.meshClientLog("[MeshGattClient stopScan] BLE scan stopped")
        } else {
            MeshNativeHelper.meshClientLog("[MeshGattClient stopScan] warning: BLE not pwered on, invalid centralManager.state=\(centralManager.state.rawValue), isScanning=\(centralManager.isScanning)")
        }
    }

    open func connect(peripheral: CBPeripheral) {
        MeshNativeHelper.meshClientLog("[MeshGattClient connect] connecting from mesh device, \(peripheral), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
        if centralManager.state == .poweredOn {
            if centralManager.isScanning {
                centralManager.stopScan()   // stop scanning before connecting to make connecting stable and fast in provisioning.
            }
            if peripheral.state == .disconnected {
                centralManager.connect(peripheral, options: nil)
            } else {
                MeshNativeHelper.meshClientLog("[MeshGattClient connect] error: invalid centralManager.state=\(centralManager.state.rawValue),  bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), connection cancelled, please try again later")
                centralManager.cancelPeripheralConnection(peripheral)
            }
        } else {
            MeshNativeHelper.meshClientLog("[MeshGattClient connect] error: invalid centralManager.state=\(centralManager.state.rawValue), \(peripheral), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
        }
    }

    open func disconnect(peripheral: CBPeripheral) {
        MeshNativeHelper.meshClientLog("[MeshGattClient disconnect] disconnecting from mesh device, \(peripheral), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
        if centralManager.state == .poweredOn {
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            MeshNativeHelper.meshClientLog("[MeshGattClient disconnect] warning: invalid centralManager.state=\(centralManager.state.rawValue), \(peripheral), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
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
            MeshNativeHelper.meshClientLog("[MeshGattClient writeData] invalid peripheral service, no valid GATT Service found, \(peripheral), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            return
        }

        var characteristic: CBCharacteristic?
        var characteristicName: String?
        switch serviceUUID {
        case MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING:
            characteristic = service.characteristics?.filter({$0.uuid == MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN}).first
            if let _ = characteristic {
                characteristicName = "PROVISIONING_DATA_IN"
            }
        case MeshUUIDConstants.UUID_SERVICE_MESH_PROXY:
            characteristic = service.characteristics?.filter({$0.uuid == MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN}).first
            if let _ = characteristic {
                characteristicName = "PROXY_DATA_IN"
            }
        default:
            MeshNativeHelper.meshClientLog("[MeshGattClient writeData] error: invalid target characterisitic=\(String(describing: characteristic)), \(peripheral), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            break
        }

        if let targetCharacteristic = characteristic, let targetCharacteristicName = characteristicName {
            serialQueue.sync {
                MeshNativeHelper.meshClientLog("[MeshGattClient writeData] to \(targetCharacteristicName), data: \(data.dumpHexBytes()), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
                peripheral.writeValue(data, for: targetCharacteristic, type: .withoutResponse)
            }
        } else {
            MeshNativeHelper.meshClientLog("[MeshGattClient writeData] invalid peripheral service, no valid Mesh Provisioning or Mesh Proxy Service found, \(peripheral), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
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
            meshLog("MeshGattClient, addUnprovisionedDevice, name:\(name), uuid:\(uuid.uuidString)")
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
                    meshLog("MeshGattClient, removeUnprovisionedDevice, name:\(name), uuid:\(uuid.uuidString)")
                    unprovisionedDeviceList.remove(at: index)
                    return
                }
            }
        }
    }

    open func clearUnprovisionedDeviceList() {
        meshLog("MeshGattClient, clearUnprovisionedDeviceList")
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
            MeshNativeHelper.meshClientLog("[MeshGattClient centralManagerDidUpdateState] central.state=\(central.state.rawValue), .poweredon")
            // Automatcailly connect to the mesh network when the Bluetooth is turned on.
            mGattEstablishedConnectionCount = 0
            MeshNativeHelper.setCurrentConnectedPeripheral(nil)
            if let _ = MeshFrameworkManager.shared.getOpenedMeshNetworkName() {
                MeshFrameworkManager.shared.connectMeshNetwork { (isConnected: Bool, connId: Int, addr: Int, isOverGatt: Bool, error: Int) in
                    MeshNativeHelper.meshClientLog("[MeshGattClient centralManagerDidUpdateState] central.state=\(central.state.rawValue), .poweredon, automatically connectingToMeshNetwork, isConnected:\(isConnected), connId:\(connId), addr:\(addr), isOverGatt:\(isOverGatt), error:\(error)")
                }
            }
            break
        case .poweredOff, .resetting:
            MeshNativeHelper.meshClientLog("[MeshGattClient centralManagerDidUpdateState] central.state=\(central.state.rawValue), .poweredoff")
            // Disconnectted from the mesh network when the Bluetooth is turned off.
            mGattEstablishedConnectionCount = 0
            MeshNativeHelper.setCurrentConnectedPeripheral(nil)
            MeshFrameworkManager.shared.meshClientConnectionStateChanged(connId: mGattEstablishedConnectionCount)
            break
        default:
            MeshNativeHelper.meshClientLog("[MeshGattClient centralManagerDidUpdateState] error: unexpected central.state=\(central.state.rawValue)")
        }
    }

    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if OtaManager.shared.isOtaScanning {
            OtaManager.shared.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        meshLog("MeshGattClient, centralManager didDiscover peripheral, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), rssi=\(RSSI), \(peripheral), advData: \(advertisementData.description)")
        if (!MeshNativeHelper.isMeshAdvertisementData(advertisementData)) {
            return
        }
        MeshFrameworkManager.shared.meshClientAdvertisementDataReport(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MeshNativeHelper.meshClientLog("[MeshGattClient didConnect] \(peripheral), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
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
        peripheral.discoverServices(MeshUUIDConstants.UUID_MESH_SERVICES)
    }

    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MeshNativeHelper.meshClientLog("[MeshGattClient didFailToConnect] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), error:\(String(describing: error))")
        MeshNativeHelper.setCurrentConnectedPeripheral(nil)

        if OtaManager.shared.isOtaUpgrading {
            OtaManager.shared.centralManager(central, didFailToConnect: peripheral, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }
    }

    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MeshNativeHelper.meshClientLog("[MeshGattClient didDisconnectPeripheral] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), error:\(String(describing: error))")
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

        MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverServices] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral)")
        if let error = error {
            MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverServices] error:\(String(describing: error)), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral)")
            disconnect(peripheral: peripheral)
            return
        }
        guard let services = peripheral.services, services.count > 0 else {
            MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverServices] error: No GATT Service Found, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            disconnect(peripheral: peripheral)
            return
        }

        if MeshFrameworkManager.shared.isMeshProvisionConnecting() {
            // Connecting to Mesh Provisioning Sevice
            if let service: CBService = services.filter({$0.uuid == MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING}).first {
                mGattService = service
                MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverServices] found Mesh Provisioning Service, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(service)")

                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverServices] error: No Mesh Provisioning Service found, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
                disconnect(peripheral: peripheral)
            }
        } else {
            // Connecting to Mesh Proxy Service
            if let service: CBService = services.filter({$0.uuid == MeshUUIDConstants.UUID_SERVICE_MESH_PROXY}).first {
                mGattService = service
                MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverServices] found Mesh Proxy Service, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(service)")

                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverServices] error: No Mesh Proxy Service found, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
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

        MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverCharacteristicsFor Service] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), \(service)")
        if let error = error {
            MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverCharacteristicsFor Service] error: \(error), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            disconnect(peripheral: peripheral)
            return
        }

        if let characteristics = service.characteristics {
            let dataIn = MeshFrameworkManager.shared.isMeshProvisionConnecting() ?
                MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_IN :
                MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_IN
            if let characteristic: CBCharacteristic = characteristics.filter({$0.uuid == dataIn}).first {
                mGattDataInCharacteristic = characteristic
                MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverCharacteristicsFor Service] found Mesh Data In characterisitc, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(characteristic)")
            } else {
                MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverCharacteristicsFor Service] error: No Mesh Data In characterisitc found, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
                disconnect(peripheral: peripheral)
                return
            }


            let dataOut = MeshFrameworkManager.shared.isMeshProvisionConnecting() ?
                MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROVISIONING_DATA_OUT :
                MeshUUIDConstants.UUID_CHARACTERISTIC_MESH_PROXY_DATA_OUT
            if let characteristic: CBCharacteristic = characteristics.filter({$0.uuid == dataOut}).first {
                mGattDataOutCharacteristic = characteristic
                MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverCharacteristicsFor Service] found Mesh Data Out characterisitc, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(characteristic)")

                // Must enable the notification for the Mesh Data Out characteristic.
                peripheral.setNotifyValue(true, for: characteristic)
            } else {
                MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverCharacteristicsFor Service] error: No Mesh Data Out characterisitc found, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
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

        MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateNotificationStateFor characteristic] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), \(characteristic)")
        if let error = error {
            MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateNotificationStateFor characteristic] error: \(error), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            disconnect(peripheral: peripheral)
            return
        }

        if characteristic.isNotifying {
            if MeshFrameworkManager.shared.isMeshProvisionConnecting(){
                MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateNotificationStateFor characteristic] all the Mesh Provisioning Service and Characteristics found and notification are enabled successfully, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            } else {
                MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateNotificationStateFor characteristic] all the Mesh Proxy Service and Characteristics found and notification are enabled successfully, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            }

            MeshFrameworkManager.shared.meshClientSetGattMtuSize()
            MeshFrameworkManager.shared.meshClientConnectionStateChanged(connId: mGattEstablishedConnectionCount)
        } else {
            MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateNotificationStateFor characteristic] error: invalid status of characteristic.isNotifying=\(characteristic.isNotifying), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
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

        MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverDescriptorsFor characteristic] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), \(characteristic)")
        if let error = error {
            MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverDescriptorsFor characteristic] error: \(error), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
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

        MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateValueFor descriptor] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), \(descriptor)")
        if let error = error {
            MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateValueFor descriptor] error: \(error), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
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

        MeshNativeHelper.meshClientLog("[MeshGattClient didWriteValueFor descriptor] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), \(descriptor)")
        if let error = error {
            MeshNativeHelper.meshClientLog("[MeshGattClient didWriteValueFor descriptor] error: \(error), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            disconnect(peripheral: peripheral)
            return
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateValueFor characteristic] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), \(characteristic)")
        meshLog("MeshGattClient, peripheral didUpdateValueFor characteristic, OtaManager.shared.isOtaUpgrading=\(OtaManager.shared.isOtaUpgrading)")
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_CHARACTERISTICS.filter({characteristic.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        if let error = error {
            MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateValueFor characteristic] error: \(error), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            disconnect(peripheral: peripheral)
            return
        }

        guard let service = peripheral.services, let data = characteristic.value else {
            MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateValueFor characteristic] error: invalid peripheral service=nil or characteristic.value=nil, bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            return
        }

        if let _ = service.filter({$0.uuid == MeshUUIDConstants.UUID_SERVICE_MESH_PROVISIONING}).first,
            let _ = MeshUUIDConstants.UUID_MESH_PROVISIONING_CHARACTERISTICS_CCCD.filter({characteristic.uuid == $0}).first {
            MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateValueFor characteristic] sendReceivedProvisionPacketToMeshCore, data: \(data.dumpHexBytes()), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            MeshFrameworkManager.shared.sendReceivedProvisionPacketToMeshCore(data: data)
        }

        if let _ = service.filter({$0.uuid == MeshUUIDConstants.UUID_SERVICE_MESH_PROXY}).first,
            let _ = MeshUUIDConstants.UUID_MESH_PROXY_CHARACTERISTICS_CCCD.filter({characteristic.uuid == $0}).first {
            MeshNativeHelper.meshClientLog("[MeshGattClient didUpdateValueFor characteristic] sendReceivedProxyPacketToMeshCore, data: \(data.dumpHexBytes()), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            MeshFrameworkManager.shared.sendReceivedProxyPacketToMeshCore(data: data)
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        MeshNativeHelper.meshClientLog("[MeshGattClient didWriteValueFor characteristic] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), \(characteristic)")
        meshLog("MeshGattClient, peripheral didWriteValueFor characteristic, OtaManager.shared.isOtaUpgrading=\(OtaManager.shared.isOtaUpgrading)")
        if OtaManager.shared.isOtaUpgrading, let _ = OtaConstants.UUID_GATT_OTA_CHARACTERISTICS.filter({characteristic.uuid == $0}).first {
            OtaManager.shared.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
            if OtaManager.shared.shouldBlockingOtherGattProcess {
                return
            }
        }

        if let error = error {
            MeshNativeHelper.meshClientLog("[MeshGattClient didWriteValueFor characteristic] error: \(error), bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes())")
            disconnect(peripheral: peripheral)
            return
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        MeshNativeHelper.meshClientLog("[MeshGattClient didReadRSSI] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), RSSI: \(RSSI), error: \(String(describing: error))")
    }

    open func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        MeshNativeHelper.meshClientLog("[MeshGattClient didModifyServices] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), didModifyServices: \(invalidatedServices)")
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        MeshNativeHelper.meshClientLog("[MeshGattClient didDiscoverIncludedServicesFor service] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral), \(service), error: \(String(describing: error))")
    }

    open func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        MeshNativeHelper.meshClientLog("[MeshGattClient peripheralDidUpdateName] bdAddr: \(MeshNativeHelper.peripheralIdentify(toBdAddr: peripheral).dumpHexBytes()), \(peripheral)")
    }
}
