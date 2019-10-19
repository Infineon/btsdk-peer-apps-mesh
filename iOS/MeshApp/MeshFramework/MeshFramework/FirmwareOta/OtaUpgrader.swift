/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * OTA upgrader process implementation.
 */

import Foundation

public enum OtaCharacteristic {
    case controlPointCharacteristic
    case dataCharacteristic
    case appInfoCharacteristic
}

public enum OtaDfuCommand {
    case NONE
    case DFU_START
    case DFU_APPLY  // only valid in first review DFU process.
    case DFU_STOP
    case DFU_GET_STATUS
}

public enum OtaDfuState {
    case DFU_STATE_IDLE
    case DFU_STATE_UPLOADING
    case DFU_STATE_UPDATING
    case DFU_STATE_COMPLETED
}

public typealias OtaDfuMetadata = (companyId: UInt16, firwmareId: Data,
    productId: UInt16, hardwareVeresionId: UInt16, firmwareVersion: UInt32,
    firmwareVersionMajor: UInt8, firmwareVersionMinor: UInt8, firmwareVersionRevision: UInt16,
    validationData: Data)

public protocol OtaUpgraderProtocol {
    /*
     * The OTA adapter can call this interface prepare for OTA upgrade process, including
     * connect to the OTA device, discover and read all OTA GATT service and characteristics,
     * also try to read the App Info if supported.
     */
    func otaUpgradePrepare(for device: OtaDeviceProtocol) -> Int

    /*
     * The OTA adapter can call this interface start OTA upgrade process.
     */
    func otaUpgradeStart(for device: OtaDeviceProtocol, fwImage: Data?) -> Int

    /*
     * The OTA adapter must call this interface when the connection state to the remote OTA device has changed.
     */
    func didUpdateConnectionState(isConnected: Bool, error: Error?)

    /*
     * The OTA adapter must call this interface when the OTA service and charactieristics discovering has completed.
     * After the OTA service has been discovered, the OTA adapter should save those instacen for later usage.
     */
    func didUpdateOtaServiceCharacteristicState(isDiscovered: Bool, error: Error?)

    /*
     * The OTA adapter must call this interface when the notification states of the OTA service Control Pointer characteristic is udpated,
     */
    func didUpdateNotificationState(isEnabled: Bool, error: Error?)

    /*
     * The OTA adapter must call this interface when any data received from any OTA service characteristic,
     * inlcuding the characterisitic indication/notification data and read value data.
     */
    func didUpdateValueFor(characteristic: OtaCharacteristic, value: Data?, error: Error?)
}

open class OtaUpgrader: OtaUpgraderProtocol {
    public static let shared = OtaUpgrader()
    public static var isDfuStarted = false
    public static var dfuState: OtaDfuState = .DFU_STATE_IDLE
    public static var activeDfuType: Int?
    public static var activeDfuFwImageFileName: String?
    public static var activeDfuFwMetadataFileName: String?

    public class func otaDfuProcessCompleted() {
        OtaUpgrader.isDfuStarted = false
        OtaUpgrader.storeActiveDfuInfo(dfuType: nil, fwImageFileName: nil, fwMetadataFileName: nil)
    }
    public class func storeActiveDfuInfo(dfuType: Int?, fwImageFileName: String?, fwMetadataFileName: String?) {
        OtaUpgrader.activeDfuType = dfuType
        OtaUpgrader.activeDfuFwImageFileName = fwImageFileName
        OtaUpgrader.activeDfuFwMetadataFileName = fwMetadataFileName
    }

    private var otaDevice: OtaDeviceProtocol?
    open var delegate: OtaDeviceProtocol? {
        get {
            return otaDevice
        }
        set {
            otaDevice = delegate
        }
    }

    private var dfuType: Int = MeshDfuType.APP_OTA_TO_DEVICE
    private var dfuMetadata: OtaDfuMetadata?
    private var dfuProxyToDevice: String?

    private var otaCommandTimer: Timer?
    private let lock = NSLock()
    public var isOtaUpgradeRunning: Bool = false
    public var isDeviceConnected: Bool = false
    public var isOtaUpgradePrepareReady: Bool = false
    public var prepareOtaUpgradeOnly: Bool = false

    private var fwImage: Data?
    private var fwImageSize: Int = 0
    private var fwOffset: Int = 0
    private var transferringSize: Int = 0
    private var fwCrc32 = CRC32_INIT_VALUE;
    private var maxOtaPacketSize: Int = 155

    private var state: OtaState = .idle
    private var completeError: OtaError?

    private var isGetComponentInfoRunning: Bool = false

    private var activeDfuCommand = OtaDfuCommand.NONE

    open func otaUpgradeStatusReset() {
        lock.lock()
        isGetComponentInfoRunning = false
        isOtaUpgradeRunning = false
        isDeviceConnected = false
        isOtaUpgradePrepareReady = false
        prepareOtaUpgradeOnly = false
        activeDfuCommand = .NONE
        completeError = nil
        state = .idle
        lock.unlock()
    }

    open func dumpOtaUpgradeStatus() {
        print("dumpOtaUpgradeStatus, otaState:\(state.description), isOtaUpgradeRunning:\(isOtaUpgradeRunning), isDeviceConnected:\(isDeviceConnected), prepareOtaUpgradeOnly:\(prepareOtaUpgradeOnly), isOtaUpgradePrepareReady:\(isOtaUpgradePrepareReady)")
    }

    open func otaUpgradePrepare(for device: OtaDeviceProtocol) -> Int {
        lock.lock()
        if isOtaUpgradeRunning {
            dumpOtaUpgradeStatus()
            print("error: OtaUpgrader, otaUpgradePrepare, ota upgrader has been started, busying")
            lock.unlock()
            return OtaErrorCode.BUSYING
        }
        isGetComponentInfoRunning = false
        isOtaUpgradeRunning = true
        isDeviceConnected = false
        prepareOtaUpgradeOnly = true
        isOtaUpgradePrepareReady = false
        lock.unlock()

        self.state = .idle
        self.otaDevice = device
        self.completeError = nil
        OtaNotificationData.init(otaError: OtaError(state: .idle, code: OtaErrorCode.SUCCESS, desc: "otaUpgradePrepare started")).post()
        DispatchQueue.main.async {
            self.stateMachineProcess()
        }
        return OtaErrorCode.SUCCESS
    }

    open func otaUpgradeStart(for device: OtaDeviceProtocol, fwImage: Data? = nil) -> Int {
        lock.lock()
        if !isOtaUpgradePrepareReady, isOtaUpgradeRunning {
            dumpOtaUpgradeStatus()
            print("error: OtaUpgrader, otaUpgradeStart, ota upgrader has been started, busying")
            lock.unlock()
            return OtaErrorCode.BUSYING
        }
        isOtaUpgradeRunning = true
        lock.unlock()
        if let fwImage = fwImage, fwImage.count > 0 {
            self.fwImage = fwImage
            self.fwImageSize = fwImage.count
        } else {
            if self.dfuType != MeshDfuType.APP_OTA_TO_DEVICE || self.activeDfuCommand != .NONE {
                print("OtaUpgrader, otaUpgradeStart, active DFU command = \(self.activeDfuCommand) or i, fwImage not set, continue")
                self.fwImage = nil
                self.fwImageSize = 0
            } else {
                print("error: OtaUpgrader, otaUpgradeStart, invalid OTA firmware image, nil")
                lock.lock()
                isOtaUpgradeRunning = false
                lock.unlock()
                return OtaErrorCode.INVALID_FW_IMAGE
            }
        }

        if isOtaUpgradePrepareReady, isDeviceConnected,
            let preparedDevice = self.otaDevice, preparedDevice.equal(device),
            preparedDevice.otaDevice != nil, preparedDevice.otaService != nil,
            preparedDevice.otaControlPointCharacteristic != nil, preparedDevice.otaDataCharacteristic != nil {
            if self.prepareOtaUpgradeOnly || self.dfuType == MeshDfuType.APP_OTA_TO_DEVICE {
                self.state = .enableNotification
            } else {
                self.state = .dfuStart
            }
        } else {
            self.otaDevice = device
            self.state = .idle
        }
        prepareOtaUpgradeOnly = false
        isGetComponentInfoRunning = false

        self.fwOffset = 0
        self.transferringSize = 0
        self.fwCrc32 = CRC32_INIT_VALUE
        self.maxOtaPacketSize = OtaUpgrader.getMaxDataTransferSize(deviceType: device.getDeviceType())
        self.completeError = nil

        print("OtaUpgrader, otaUpgradeStart, otaDevice name:\(device.getDeviceName()), type:\(device.getDeviceType())")
        OtaNotificationData.init(otaError: OtaError(state: .idle, code: OtaErrorCode.SUCCESS, desc: "otaUpgradeStart started")).post()
        DispatchQueue.main.async {
            self.stateMachineProcess()
        }

        // Now, OTA upgrade processing has been started, progress status will be updated through OtaConstants.Notification.OTA_COMPLETE_STATUS notificaitons.
        return OtaErrorCode.SUCCESS
    }

    ///
    /// Interfaces for receiving notification or response data from remote device.
    ///

    open func didUpdateConnectionState(isConnected: Bool, error: Error?) {
        guard isOtaUpgradeRunning, state != .idle else {
            return
        }

        /*
         * [Dudley] test purpose.
         * some old device, there no response data for the verify command, and the device will reset itself after about 2 seconds when verify succes,
         * when verify failed, the verify response with failure status will be received immeidately.
         * so, here process the disconnection event as verify success and the upgrade process has been successfully done in firmware side.
         * For new devices, it should be removed if not required.
         */
        if state == .verify,  otaCommandTimer?.isValid ?? false, !isConnected {
            otaVerifyResponse(data: Data(repeating: 0, count: 1), error: nil)
            return
        }

        stopOtaCommandTimer()
        guard error == nil, isConnected else {
            if error != nil {
                print("error: OtaUpgrader, didUpdateConnectionState, unexpected disconnect from or failed to connect to remote OTA device, error:\(error!)")
                let errorDomain = (error! as NSError).domain
                let errorCode = (error! as NSError).code
                if errorCode == CBError.Code.connectionTimeout.rawValue, errorDomain == CBErrorDomain {
                    completeError = OtaError(state: state, code: OtaErrorCode.ERROR_DEVICE_CONNECT, desc: "The connection has timed out unexpectedly.")
                } else {
                    completeError = OtaError(state: state, code: OtaErrorCode.ERROR_DEVICE_CONNECT, desc: "disconnected from remote device or failed to connect to the remote device")
                }
            } else {
                print("error: OtaUpgrader, didUpdateConnectionState, disconnected from remote OTA device")
                completeError = OtaError(state: state, code: OtaErrorCode.ERROR_DEVICE_DISCONNECT, desc: "disconnect from remote device")
            }
            OtaNotificationData(otaError: completeError!).post()
            if state.rawValue > OtaState.enableNotification.rawValue {
                state = .abort
            } else {
                state = .complete
            }
            stateMachineProcess()
            return
        }

        OtaNotificationData(otaState: state, otaError: nil).post()
        if self.prepareOtaUpgradeOnly || self.dfuType == MeshDfuType.APP_OTA_TO_DEVICE {
            state = .otaServiceDiscover
            stateMachineProcess()
        } else {
            state = .dfuStart
            stateMachineProcess()
        }
    }

    /*
     * The OTA adapter must call this interface when the OTA service and charactieristics discovering has completed.
     * After the OTA service has been discovered, the OTA adapter should save those instacen for later usage.
     */
    open func didUpdateOtaServiceCharacteristicState(isDiscovered: Bool, error: Error?) {
        guard isOtaUpgradeRunning, isDeviceConnected, state != .idle else {
            return
        }

        stopOtaCommandTimer()
        guard error == nil, isDiscovered else {
            OtaManager.shared.dumpOtaStatus()
            if error != nil {
                print("error: OtaUpgrader, didUpdateOtaServiceCharacteristicState, failed to discover OTA GATT service, error:\(error!)")
                completeError = OtaError(state: state, code: OtaErrorCode.ERROR_DISCOVER_SERVICE, desc: "discover OTA service with error")
            } else {
                print("error: OtaUpgrader, didUpdateOtaServiceCharacteristicState, no OTA GATT service discovered from remote OTA device")
                completeError = OtaError(state: state, code: OtaErrorCode.ERROR_DEVICE_OTA_NOT_SUPPORTED, desc: "no OTA service discovered")
            }
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        OtaNotificationData(otaState: state, otaError: nil).post()
        if (otaDevice?.otaAppInfoCharacteristic != nil) || (self.otaDevice != nil && self.otaDevice!.getDeviceType() == .mesh) {
            state = .readAppInfo
        } else {
            if prepareOtaUpgradeOnly {
                self.otaReadAppInfoResponse(data: nil, error: nil)
                return
            }

            state = .enableNotification
        }
        stateMachineProcess()
    }

    /*
     * The OTA adapter must call this interface when the notification states of the OTA service Control Pointer characteristic is udpated,
     */
    open func didUpdateNotificationState(isEnabled: Bool, error: Error?) {
        guard isOtaUpgradeRunning, isDeviceConnected, state != .idle else {
            return
        }

        stopOtaCommandTimer()
        guard error == nil, isEnabled else {
            OtaManager.shared.dumpOtaStatus()
            if error != nil {
                print("error: OtaUpgrader, didUpdateNotificationState, failed to enable OTA Control Point characteristic notification, error:\(error!)")
                completeError = OtaError(state: state, code: OtaErrorCode.ERROR_CHARACTERISTIC_NOTIFICATION_UPDATE, desc: "enable notification with error")
            } else {
                print("error: OtaUpgrader, didUpdateOtaServiceCharacteristicState, OTA Control Point characteristic notification not enabled")
                completeError = OtaError(state: state, code: OtaErrorCode.ERROR_CHARACTERISTIC_NOTIFICATION_UPDATE, desc: "notification disabled")
            }
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        OtaNotificationData(otaState: state, otaError: nil).post()
        lock.lock()
        if self.activeDfuCommand == .DFU_APPLY {
            state = .apply      // directly send the apply command to remote device.
        } else {
            state = .prepareForDownload
        }
        lock.unlock()
        stateMachineProcess()
    }

    /*
     * The OTA adapter must call this interface when any data received from any OTA service characteristic,
     * inlcuding the characterisitic indication/notification data and read value data.
     */
    open func didUpdateValueFor(characteristic: OtaCharacteristic, value: Data?, error: Error?) {
        guard isOtaUpgradeRunning, isDeviceConnected, state != .idle else {
            return
        }

        switch state {
        case .readAppInfo:
            otaReadAppInfoResponse(data: value, error: error)
        case .prepareForDownload:
            otaPrepareForDownloadResponse(data: value, error: error)
        case .startDownload:
            otaStartDownloadResponse(data: value, error: error)
        case .dataTransfer:
            otaTransferDataResponse(data: value, error: error)
        case .verify:
            otaVerifyResponse(data: value, error: error)
        case .apply:
            otaApplyResponse(data: value, error: error)
        case .abort:
            otaAbortResponse(data: value, error: error)
        default:
            print("warnning: OtaUpgrader, didUpdateValueFor, state=\(state.description)")
            break
        }
    }

    private func stateMachineProcess() {
        switch self.state {
        case .idle:
            isOtaUpgradeRunning = true
            self.state = .connect
            self.stateMachineProcess()
        case .connect:
            self.otaConnect()
        case .otaServiceDiscover:
            isDeviceConnected = true
            self.discoverOtaServiceCharacteristics()
        case .readAppInfo:
            self.otaReadAppInfo()
        case .enableNotification:
            self.otaEnableNotification()
        case .prepareForDownload:
            self.otaPrepareForDownload()
        case .startDownload:
            self.otaStartDownload()
        case .dataTransfer:
            self.otaTransferData()
        case .verify:
            self.otaVerify()
        case .apply:
            self.otaApply()
        case .dfuStart:
            self.otaStartDfu()
        case .abort:
            self.otaAbort()
        case .complete:
            self.otaCompleted()
            lock.lock()
            if prepareOtaUpgradeOnly {
                // Do not clear the isOtaUpgradeRunning and isDeviceConnected state values
                // when only do prepare for OTA upgrade, because mesh network may change the connection status,
                // so, must keep the isOtaUpgrading to track the changes to avoid any potential incnsistent issue.
            } else {
                isDeviceConnected = false
            }
            prepareOtaUpgradeOnly = false
            isOtaUpgradeRunning = false
            isGetComponentInfoRunning = false
            activeDfuCommand = .NONE
            lock.unlock()
            print("OtaUpgrader, stateMachineProcess, exit")
        }
    }

    private func otaConnect() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaConnect, otaDevice instance is nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        startOtaCommandTimer()
        otaDevice.connect()
    }

    private func discoverOtaServiceCharacteristics() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, discoverOtaServiceCharacteristics, invalid delegate:nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        startOtaCommandTimer()
        otaDevice.discoverOtaServiceCharacteristic()
    }

    private func otaReadAppInfo() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaReadAppInfo, otaDevice instance is nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        if otaDevice.otaAppInfoCharacteristic != nil {
            startOtaCommandTimer()
            otaDevice.readValue(from: .appInfoCharacteristic)
        } else {
            self.otaReadAppInfoResponse(data: nil, error: nil)
        }
    }

    private func otaReadAppInfoResponse(data: Data?, error: Error?) {
        stopOtaCommandTimer()

        // alawys ignore the readAppInfo error status, because many device doesn't support AppInfo characateristic at all.
        if let appInfoData = data {
            if appInfoData.count == 4 {
                let appId  = UInt16(UInt8(appInfoData[0])) + (UInt16(UInt8(appInfoData[1])) << 8)
                let appVerMajor = UInt8(appInfoData[2])
                let appVerMinor = UInt8(appInfoData[3])
                let appInfoString = String(format: "AppId: 0x%04X, AppVersion: %d.%d",
                                           appId, appVerMajor, appVerMinor)
                OtaNotificationData(otaError: OtaError(state: state, code: OtaErrorCode.SUCCESS, desc: appInfoString)).post()
            } else if appInfoData.count == 5 {
                let appId  = UInt16(UInt8(appInfoData[0])) + (UInt16(UInt8(appInfoData[1])) << 8)
                let appVerPrefixNumber = UInt8(appInfoData[2])
                let appVerMajor = UInt8(appInfoData[3])
                let appVerMinor = UInt8(appInfoData[4])
                let appInfoString = String(format: "AppId: 0x%04X, AppVersion: %d.%d.%d",
                                           appId, appVerPrefixNumber, appVerMajor, appVerMinor)
                OtaNotificationData(otaError: OtaError(state: state, code: OtaErrorCode.SUCCESS, desc: appInfoString)).post()
            }
        } else {
            if let otaDevice = self.otaDevice, otaDevice.getDeviceType() == .mesh {
                if self.isGetComponentInfoRunning, self.otaCommandTimer?.isValid ?? false {
                    return  // avoid the getComponentInfo command send multiple times.
                }

                if !MeshFrameworkManager.shared.isMeshNetworkConnected() {
                    if self.prepareOtaUpgradeOnly {
                        self.state = .complete
                    } else {
                        self.state = .enableNotification
                    }
                    self.isOtaUpgradePrepareReady = true
                    self.stateMachineProcess()
                    return
                }

                startOtaCommandTimer()
                self.isGetComponentInfoRunning = true
                MeshFrameworkManager.shared.getMeshComponentInfo(componentName: otaDevice.getDeviceName()) { (componentName: String, componentInfo: String?, error: Int) in
                    self.isGetComponentInfoRunning = false
                    self.stopOtaCommandTimer()
                    if error == MeshErrorCode.MESH_SUCCESS, let componentInfo = componentInfo {
                        OtaNotificationData(otaError: OtaError(state: self.state, code: OtaErrorCode.SUCCESS, desc: componentInfo)).post()
                    }

                    if self.prepareOtaUpgradeOnly {
                        self.state = .complete
                    } else {
                        self.state = .enableNotification
                    }
                    self.isOtaUpgradePrepareReady = true
                    self.stateMachineProcess()
                }
                return
            }
        }

        if prepareOtaUpgradeOnly {
            state = .complete
        } else {
            state = .enableNotification
        }
        isOtaUpgradePrepareReady = true
        stateMachineProcess()
    }

    private func otaEnableNotification() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaEnableNotification, otaDevice instance is nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        startOtaCommandTimer()
        otaDevice.enableOtaNotification(enabled: true)
    }

    private func otaPrepareForDownload() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaPrepareForDownload, otaDevice instance is nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        startOtaCommandTimer()
        var otaCommand = OtaCommandData(command: .prepareDownload)
        if otaDevice.otaVersion == OtaConstants.OTA_VERSION_2, let metadata = self.dfuMetadata {
            otaCommand = OtaCommandData(command: .prepareDownload, companyId: metadata.companyId, firmwareId: metadata.firwmareId)
        }
        print("OtaUpgrader, otaPrepareForDownload, OTA_VERSION_\(otaDevice.otaVersion), otaCommand.value.count=\(otaCommand.value.count)")
        otaDevice.writeValue(to: .controlPointCharacteristic, value: otaCommand.value) { (data, error) in
            guard error == nil else {
                self.otaPrepareForDownloadResponse(data: data, error: error)
                return
            }
        }
    }

    private func otaPrepareForDownloadResponse(data: Data?, error: Error?) {
        stopOtaCommandTimer()
        guard error == nil else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaPrepareForDownload, failed to write Prepare for Download command, error:\(error!)")
            completeError = OtaError(state: state, code: OtaErrorCode.FAILED, desc: "failed to write Prepare for Download command")
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        let status = OtaCommandStatus.parse(from: data)
        if status == .success {
            OtaNotificationData(otaState: state, otaError: nil).post()
            state = .startDownload
        } else {
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_RESPONSE_VALUE, desc: "failed to execute Prepare for Download command, response: \(status.description())")
            OtaNotificationData(otaState: state, otaError: completeError).post()
            state = .complete
        }
        stateMachineProcess()
    }

    private func otaStartDownload() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaStartDownload, otaDevice instance is nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .abort
            stateMachineProcess()
            return
        }

        startOtaCommandTimer()
        let otaCommand = OtaCommandData(command: .startDownload, lParam: UInt32(fwImageSize))
        otaDevice.writeValue(to: .controlPointCharacteristic, value: otaCommand.value) { (data, error) in
            guard error == nil else {
                self.otaStartDownloadResponse(data: data, error: error)
                return
            }
        }
    }

    private func otaStartDownloadResponse(data: Data?, error: Error?) {
        stopOtaCommandTimer()
        guard error == nil else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaStartDownload, failed to write Start Download command, error:\(error!)")
            completeError = OtaError(state: state, code: OtaErrorCode.FAILED, desc: "failed to write Start Download command")
            OtaNotificationData(otaError: completeError!).post()
            state = .abort
            stateMachineProcess()
            return
        }

        let status = OtaCommandStatus.parse(from: data)
        print("OtaUpgrader, otaStartDownloadResponse, status:\(status.description())")
        if status == .success {
            OtaNotificationData(otaState: state, otaError: nil).post()
            state = .dataTransfer
        } else {
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_RESPONSE_VALUE, desc: "ota start download response with failure")
            OtaNotificationData(otaState: state, otaError: completeError).post()
            state = .abort
        }
        stateMachineProcess()
    }

    private func otaTransferData() {
        guard let otaDevice = self.otaDevice, let fwImage = self.fwImage else {
            OtaManager.shared.dumpOtaStatus()
            if self.otaDevice == nil {
                print("error: OtaUpgrader, otaTransferData, otaDevice instance is nil")
                completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            } else {
                print("error: OtaUpgrader, otaTransferData, invalid fwImage nil")
                completeError = OtaError(state: state, code: OtaErrorCode.INVALID_FW_IMAGE, desc: "fw image data is nil")
            }
            OtaNotificationData(otaError: completeError!, fwImageSize: fwImageSize, transferredImageSize: fwOffset).post()
            state = .abort
            stateMachineProcess()
            return
        }

        if fwOffset == 0 {
            // send notifcation that indicate tranferring started.
            OtaNotificationData(otaState: state, otaError: nil, fwImageSize: fwImageSize, transferredImageSize: fwOffset).post()
        }

        let transferSize = fwImageSize - fwOffset
        transferringSize = (transferSize > maxOtaPacketSize) ? maxOtaPacketSize : transferSize
        if transferringSize > 0 {
            let range: Range = fwOffset..<(fwOffset + transferringSize)
            let transferData = fwImage.subdata(in: range)
            fwCrc32 = OtaUpgrader.calculateCrc32(crc32: fwCrc32, data: transferData)
            if (fwOffset + transferringSize) >= fwImageSize {
                fwCrc32 ^= CRC32_INIT_VALUE     // this is the last packet, get final calculated fw image CRC value.
            }
            print("OtaUpgrader, otaTransferData, fwImageSize:\(fwImageSize), write at offset:\(fwOffset), size:\(transferringSize)")
            startOtaCommandTimer()
            otaDevice.writeValue(to: .dataCharacteristic, value: transferData, completion: self.otaTransferDataResponse)
        } else {
            print("warnning: OtaUpgrader, otaTransferData, no more data for transferring, fwImageSize:\(fwImageSize), offset:\(fwOffset)")
            stopOtaCommandTimer()
            fwOffset = fwImageSize
            OtaNotificationData(otaState: state, otaError: nil, fwImageSize: self.fwImageSize, transferredImageSize: fwOffset).post()

            state = .verify
            stateMachineProcess()
        }
    }

    private func otaTransferDataResponse(data: Data?, error: Error?) {
        stopOtaCommandTimer()
        guard error == nil else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaTransferData, failed to write transfer data, error:\(error!)")
            completeError = OtaError(state: state, code: OtaErrorCode.FAILED, desc: "failed to write transfer data")
            OtaNotificationData(otaError: completeError!, fwImageSize: fwImageSize, transferredImageSize: fwOffset).post()
            state = .abort
            stateMachineProcess()
            return
        }

        fwOffset += transferringSize
        OtaNotificationData(otaState: state, otaError: nil, fwImageSize: self.fwImageSize, transferredImageSize: fwOffset).post()

        if fwOffset >= fwImageSize {
            print("OtaUpgrader, otaTransferData, fwImageSize:\(fwImageSize), totally transferred size:\(fwOffset), done")
            state = .verify
        }
        stateMachineProcess()
    }

    private func otaVerify() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaVerify, otaDevice instance is nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .abort
            stateMachineProcess()
            return
        }

        startOtaCommandTimer()
        let otaCommand = OtaCommandData(command: .verify, lParam: UInt32(fwCrc32))
        print("OtaUpgrader, otaVerify, CRC32=\(String.init(format: "0x%X", fwCrc32))")
        otaDevice.writeValue(to: .controlPointCharacteristic, value: otaCommand.value) { (data, error) in
            guard error == nil else {
                self.otaVerifyResponse(data: data, error: error)
                return
            }
        }
    }

    private func otaVerifyResponse(data: Data?, error: Error?) {
        stopOtaCommandTimer()
        guard error == nil else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaVerify, failed to write Verify command, error:\(error!)")
            completeError = OtaError(state: state, code: OtaErrorCode.FAILED, desc: "failed to write Verify command")
            OtaNotificationData(otaError: completeError!).post()
            state = .abort
            stateMachineProcess()
            return
        }

        let status = OtaCommandStatus.parse(from: data)
        print("OtaUpgrader, otaVerifyResponse, status:\(status.description())")
        if status == .success {
            OtaNotificationData(otaState: state, otaError: nil).post()
            state = .apply
        } else {
            completeError = OtaError(state: state, code: OtaErrorCode.ERROR_OTA_VERIFICATION_FAILED, desc: "firmware downloaded image CRC32 verification failed")
            OtaNotificationData(otaState: state, otaError: completeError).post()
            state = .abort
        }
        stateMachineProcess()
    }

    private func otaApply() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaApply, otaDevice instance is nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .abort
            stateMachineProcess()
            return
        }

        // The apply command only supported in OTA_VERSION_2 DFU OTA.
        guard otaDevice.otaVersion == OtaConstants.OTA_VERSION_2 else {
            state = .complete
            stateMachineProcess()
            return
        }

        // The Apply command should be sent immediately after download completed only when the DFU method is APP_TO_DEVICE DFU.
        // For other DFU methods, the DFU Apply command should be sent after user manually click the DFU Apply button.
        guard self.dfuType == MeshDfuType.APP_OTA_TO_DEVICE || self.activeDfuCommand == .DFU_APPLY else {
            state = .dfuStart
            stateMachineProcess()
            return
        }

        // Send the Apply command to Proxy device.
        startOtaCommandTimer()
        let otaCommand = OtaCommandData(command: .apply)
        otaDevice.writeValue(to: .controlPointCharacteristic, value: otaCommand.value) { (data, error) in
            guard error == nil else {
                self.otaApplyResponse(data: data, error: error)
                return
            }
        }
    }

    private func otaApplyResponse(data: Data?, error: Error?) {
        stopOtaCommandTimer()
        guard error == nil else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaApply, failed to write apply command, error:\(error!)")
            completeError = OtaError(state: state,
                                     code: OtaErrorCode.ERROR_CHARACTERISTIC_WRITE_VALUE,
                                     desc: "failed to write apply command")
            OtaNotificationData(otaError: completeError!).post()
            state = .abort
            stateMachineProcess()
            return
        }

        let status = OtaCommandStatus.parse(from: data)
        print("OtaUpgrader, otaApplyResponse, status:\(status.description())")
        if status == .success {
            OtaNotificationData(otaState: state, otaError: nil).post()
            state = .dfuStart
        } else {
            completeError = OtaError(state: state, code: OtaErrorCode.ERROR_OTA_V2_APPLY, desc: "firmware Apply failed")
            OtaNotificationData(otaState: state, otaError: completeError).post()
            state = .abort
        }
        stateMachineProcess()
    }

    private func otaStartDfu() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaStartDfu, otaDevice instance is nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }
        let dfuStartDeviceName = otaDevice.getDeviceName()

        if self.activeDfuCommand == .DFU_GET_STATUS {
            let error = MeshFrameworkManager.shared.meshClientDfuGetStatus(componentName: dfuStartDeviceName)
            if error != MeshErrorCode.MESH_SUCCESS {
                print("error: OtaUpgrader, otaStartDfu, failed to exectue meshClientDfuGetStatus, error:\(error)")
                completeError = OtaError(state: state, code: OtaErrorCode.FAILED, desc: "failed to exectue meshClientDfuGetStatus. Error Code: \(error)")
                OtaNotificationData(otaState: state, otaError: completeError!).post()
            }
            state = .complete
            stateMachineProcess()
            print("OtaUpgrader, otaStartDfu, meshClientDfuGetStatus return success")
            return
        }

        // The APP_OTA_TO_DEVICE method does not require send DFU start command to proxy device after OTA image downloaded successfully.
        // When user manually requests to Apply the downloaded image to the Proxy device, the DFU start is not required.
        if self.dfuType == MeshDfuType.APP_OTA_TO_DEVICE || self.activeDfuCommand != .DFU_START {
            state = .complete
            stateMachineProcess()
            return
        }

        guard let metadata = self.dfuMetadata else {
            print("error: OtaUpgrader, otaStartDfu, invalid metadata, nil")
            completeError = OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "firmware metadata is nil")
            OtaNotificationData(otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        // Send DFU start command.
        print("OtaUpgrader, otaStartDfu, dfuType: \(dfuType), dfuStartDeviceName: \(dfuStartDeviceName), companyId: \(metadata.companyId), firmwareId: \(metadata.firwmareId.dumpHexBytes())")
        let error = Int(MeshNativeHelper.meshClientDfuStart(Int32(dfuType), componentName: dfuStartDeviceName, firmwareId: metadata.firwmareId, validationData: metadata.validationData))
        guard error == MeshErrorCode.MESH_SUCCESS else {
            print("error: OtaUpgrader, otaStartDfu, failed to exectue DFU start command, error:\(error)")
            completeError = OtaError(state: state, code: OtaErrorCode.FAILED, desc: "failed to exectue DFU start command. Error Code: \(error)")
            OtaNotificationData(otaState: state, otaError: completeError!).post()
            state = .complete
            stateMachineProcess()
            return
        }

        OtaUpgrader.isDfuStarted = true
        OtaNotificationData(otaState: state, otaError: nil).post()
        state = .complete
        stateMachineProcess()
        print("OtaUpgrader, otaStartDfu, DFU start command finished success")
    }

    private func otaAbort() {
        guard let otaDevice = self.otaDevice else {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaAbort, otaDevice instance is nil")
            //OtaNotificationData(otaError: OtaError(state: state, code: OtaErrorCode.INVALID_PARAMETERS, desc: "otaDevice instance is nil")).post()
            state = .complete
            stateMachineProcess()
            return
        }

        startOtaCommandTimer()
        let otaCommand = OtaCommandData(command: .abort, lParam: UInt32(fwImageSize))
        otaDevice.writeValue(to: .controlPointCharacteristic, value: otaCommand.value) { (data, error) in
            guard error == nil else {
                self.otaAbortResponse(data: data, error: error)
                return
            }
        }
    }

    private func otaAbortResponse(data: Data?, error: Error?) {
        stopOtaCommandTimer()

        // Stop DFU process.
        if self.dfuType != MeshDfuType.APP_OTA_TO_DEVICE {
            let error = MeshFrameworkManager.shared.meshClientDfuStop()
            if error == MeshErrorCode.MESH_SUCCESS {
                OtaUpgrader.isDfuStarted = false
                print("warning: OtaUpgrader, otaAbortResponse, DFU process stopped manually, error=\(error)")
            } else {
                print("error: OtaUpgrader, otaAbortResponse, failed to send DFU stop command, error=\(error)")
            }
            print("OtaUpgrader, otaAbortResponse, DFU stopped for \(String(describing: MeshDfuType.getDfuTypeText(type: self.dfuType)))")
            return
        }

        var abortError: OtaError?
        if let error = error {
            OtaManager.shared.dumpOtaStatus()
            print("error: OtaUpgrader, otaAbortResponse, failed to write Abort command, error:\(error)")
            abortError = OtaError(state: state, code: OtaErrorCode.FAILED, desc: "failed to write Abort command")
        } else {
            let status = OtaCommandStatus.parse(from: data)
            print("OtaUpgrader, otaAbortResponse, response status:\(status.description())")
            if status == .success {
                abortError = OtaError(state: state, code: OtaErrorCode.ERROR_OTA_ABORTED, desc: "OTA processed has been aborted")
            } else {
                abortError = OtaError(state: state, code: OtaErrorCode.INVALID_RESPONSE_VALUE, desc: "failed abort OTA process, status: \(status.description())")
            }
        }
        completeError = completeError ?? abortError
        OtaNotificationData(otaState: state, otaError: nil).post()

        state = .complete
        stateMachineProcess()
    }

    private func otaCompleted() {
        stopOtaCommandTimer()
        OtaManager.shared.dumpOtaStatus()
        if completeError == nil {
            if self.activeDfuCommand != .NONE {
                print("OtaUpgrader, otaCompleted, active DFU command=\(self.activeDfuCommand) started with success ")
            } else {
                print("OtaUpgrader, otaCompleted, done with success ")
            }
        } else {
            if self.activeDfuCommand != .NONE {
                print("error: OtaUpgrader, otaCompleted, failed to start active DFU command=\(self.activeDfuCommand), error: (\(completeError!.code), \(completeError!.description))")
            } else {
                print("error: OtaUpgrader, otaCompleted, done with error: (\(completeError!.code), \(completeError!.description))")
            }
        }

        if self.activeDfuCommand == .DFU_APPLY, completeError == nil {
            OtaNotificationData(otaState: .complete, otaError: OtaError(state: .apply, code: MeshErrorCode.MESH_SUCCESS, desc: "success")).post()
        } else {
            OtaNotificationData(otaState: .complete, otaError: completeError).post()
        }
    }

    /// DFU OTA only supported OTA_VERSION_2 in devices.
    open func otaDfuStart(for device: OtaDeviceProtocol, dfuType: Int, fwImage: Data, metadata: OtaDfuMetadata, proxyToDevice: String? = nil) -> Int {
        self.dfuType = dfuType
        self.dfuMetadata = metadata
        self.dfuProxyToDevice = proxyToDevice
        self.activeDfuCommand = .DFU_START
        return self.otaUpgradeStart(for: device, fwImage: fwImage)
    }

    open func otaDfuStop() -> Int {
        if self.dfuType == MeshDfuType.APP_OTA_TO_DEVICE ||
            (self.state.rawValue >= OtaState.enableNotification.rawValue && self.state.rawValue <= OtaState.verify.rawValue) {
            self.otaAbort()
        } else {
            let error = MeshFrameworkManager.shared.meshClientDfuStop()
            if error == MeshErrorCode.MESH_SUCCESS {
                OtaUpgrader.isDfuStarted = false
                print("warning: OtaUpgrader, otaDfuStop, DFU process stopped manually, error=\(error)")
            } else {
                print("error: OtaUpgrader, otaDfuStop, failed to send DFU stop command, error=\(error)")
            }
        }
        return MeshErrorCode.MESH_SUCCESS
    }

    open func otaDfuApply(for device: OtaDeviceProtocol) -> Int {
        self.activeDfuCommand = .DFU_APPLY
        return MeshErrorCode.MESH_SUCCESS; // Do nothing for DFU apply, currently.

        /* Support first DFU revision.
        OtaNotificationData(otaState: .complete, otaError: OtaError(state: .apply, code: MeshErrorCode.MESH_SUCCESS, desc: "DFU Applied success")).post()
        return MeshErrorCode.MESH_SUCCESS; // for new DFU process, no operation is required for this process.

        lock.lock()
        if self.activeDfuCommand != .NONE {
            lock.unlock()
            print("error: OtaUpgrader, otaDfuApply has been called, busying")
            OtaNotificationData(otaState: .complete, otaError: OtaError(state: .apply, code: MeshErrorCode.MESH_ERROR_API_IS_BUSYING, desc: "DFU Apply has been called, busying")).post()
            return MeshErrorCode.MESH_ERROR_API_IS_BUSYING
        }
        self.activeDfuCommand == .DFU_APPLY
        lock.unlock()
        return self.otaUpgradeStart(for: device)
         */
    }

    open func otaGetDfuStatus(for device: OtaDeviceProtocol) -> Int {
        guard let dfuType = OtaUpgrader.activeDfuType, dfuType != MeshDfuType.APP_OTA_TO_DEVICE else {
            print("APP_OTA_TO_DEVICE does not support get DFU status")
            return MeshErrorCode.MESH_ERROR_INVALID_STATE
        }

        if OtaUpgrader.isDfuStarted, dfuType == MeshDfuType.APP_DFU_TO_ALL {   // The component device should have been connected whent he DFU process has been started.
            let error = MeshFrameworkManager.shared.meshClientDfuGetStatus(componentName: device.getDeviceName())
            if error != MeshErrorCode.MESH_SUCCESS {
                print("error: OtaUpgrader, otaGetDfuStatus, failed to exectue meshClientDfuGetStatus, error:\(error)")
            }
            return error
        }

        self.dfuType = dfuType
        self.activeDfuCommand = .DFU_GET_STATUS
        return self.otaUpgradeStart(for: device)
    }
}

extension OtaUpgrader {
    public enum OtaState: Int {
        case idle = 0
        case connect = 1
        case otaServiceDiscover = 2
        case readAppInfo = 3
        case enableNotification = 4
        case prepareForDownload = 5
        case startDownload = 6
        case dataTransfer = 7
        case verify = 8
        case apply = 9      // supported in version_2 ota process.
        case dfuStart = 10  // supported in version_2 ota process.
        case abort = 11
        case complete = 12

        public var description: String {
            switch self {
            case .idle:
                return "idle"
            case .connect:
                return "connect"
            case .otaServiceDiscover:
                return "otaServiceDiscover"
            case .readAppInfo:
                return "readAppInfo"
            case .enableNotification:
                return "enableNotification"
            case .prepareForDownload:
                return "prepareForDownload"
            case .startDownload:
                return "startDownload"
            case .dataTransfer:
                return "dataTransfer"
            case .verify:
                return "verify"
            case .apply:
                return "apply"
            case .dfuStart:
                return "dfuStart"
            case .abort:
                return "abort"
            case .complete:
                return "complete"
            }
        }
    }

    private enum OtaCommand: Int {
        case prepareDownload = 1
        case startDownload = 2
        case verify = 3
        case finish = 4
        case getStatus = 5      // not currently used
        case clearStatus = 6    // not currently used
        case abort = 7
        case apply = 8
    }

    private struct OtaCommandData {
        // dataSize: 4 bytes; command: 1 byte; parameters: max 4 bytes
        private var bytes: [UInt8]
        var value: Data {
            return Data(bytes)
        }
        var count: Int {
            return bytes.count
        }

        init(command: OtaCommand) {
            let dataSize = 1
            bytes = [UInt8](repeating: 0, count: dataSize)
            bytes[0] = UInt8(command.rawValue)
        }

        // The fwID data must be DFU_FW_ID_LENGTH (8) bytes long.
        init(command: OtaCommand, companyId: UInt16, firmwareId: Data) {
            let dataSize = 1 + 2 + firmwareId.count
            bytes = [UInt8](repeating: 0, count: dataSize)
            bytes[0] = UInt8(command.rawValue)
            bytes[1] = UInt8((companyId >> 8) & 0xFF)
            bytes[2] = UInt8(companyId & 0xFF)
            for i in 0..<firmwareId.count {
                bytes[3 + i] = UInt8(firmwareId[i])
            }
        }

        init(command: OtaCommand, sParam: UInt16) {
            let dataSize = 3
            bytes = [UInt8](repeating: 0, count: dataSize)
            bytes[0] = UInt8(command.rawValue)
            bytes[1] = UInt8(sParam & 0xFF)
            bytes[2] = UInt8((sParam >> 8) & 0xFF)
        }

        init(command: OtaCommand, lParam: UInt32) {
            let dataSize = 5
            bytes = [UInt8](repeating: 0, count: dataSize)
            bytes[0] = UInt8(command.rawValue)
            bytes[1] = UInt8(lParam & 0xFF)
            bytes[2] = UInt8((lParam >> 8) & 0xFF)
            bytes[3] = UInt8((lParam >> 16) & 0xFF)
            bytes[4] = UInt8((lParam >> 24) & 0xFF)
        }
    }

    // OTA Command Response status.
    private enum OtaCommandStatus: UInt8 {
        case success = 0
        case unsupported = 1
        case illegal = 2
        case verificationFailed = 3
        case invalidImage = 4
        case invalidImageSize = 5
        case moreData = 6
        case invalidAppId = 7
        case invalidVersion = 8
        case continueStatus = 9
        case invalidParameters = 10
        case sendCommandFailed = 11
        case timeout = 12
        case commandResponseError = 13

        static func parse(from data: Data?) -> OtaCommandStatus {
            var status: OtaCommandStatus = .unsupported
            if let respData = data, respData.count > 0 {
                status = OtaCommandStatus.init(rawValue: UInt8(respData[0])) ?? .unsupported
            }
            return status
        }

        func description() -> String {
            switch self {
            case .success:
                return "success"
            case .unsupported:
                return "unsupported command"
            case .illegal:
                return "illegal state"
            case .verificationFailed:
                return "image varification failed"
            case .invalidAppId:
                return "invalid App Id"
            case .invalidImage:
                return "invalid image"
            case .invalidImageSize:
                return "invalid image size"
            case .invalidVersion:
                return "invalid version"
            case .moreData:
                return "more data"
            case .continueStatus:
                return "continue"
            case .sendCommandFailed:
                return "failed to write command or data"
            case .invalidParameters:
                return "invalid parameters or invalid objects"
            case .timeout:
                return "timeout"
            case .commandResponseError:
                return "commandResponseError"
            }
        }
    }
}

extension OtaUpgrader {
    private func startOtaCommandTimer() {
        stopOtaCommandTimer()

        var interval: TimeInterval = 10
        if state == .connect {
            interval += TimeInterval(exactly: MeshConstants.MESH_DEFAULT_SCAN_DURATION) ?? 30.0
        } else if state == .otaServiceDiscover || state == .verify {
            interval = 30
        }

        if #available(iOS 10.0, *) {
            otaCommandTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: { (Timer) in
                self.onOtaCommandTimeout()
            })
        } else {
            otaCommandTimer = Timer.scheduledTimer(timeInterval: interval, target: self,
                                                selector: #selector(self.onOtaCommandTimeout),
                                                userInfo: nil, repeats: false)
        }
    }

    private func stopOtaCommandTimer() {
        otaCommandTimer?.invalidate()
        otaCommandTimer = nil
    }

    @objc private func onOtaCommandTimeout() {
        if state == .readAppInfo {
            // AppInfo read are not supported on some devices, so bypass the error if it happen.
            otaReadAppInfoResponse(data: nil, error: nil)
            return
        }

        if completeError == nil {
            var error_msg = "execute ota command or write ota data timeout error"
            if !isOtaUpgradePrepareReady {
                if self.activeDfuCommand != .NONE {
                    error_msg = "DFU command=\(self.activeDfuCommand) timeout error"
                } else {
                    error_msg = "OTA service discovering timeout error"
                }
            }
            completeError = OtaError(state: state, code: OtaErrorCode.TIMEOUT, desc: error_msg)
        }
        OtaNotificationData.init(otaError: completeError!).post()

        if state == .idle || state == .connect || state == .otaServiceDiscover || state == .abort {
            state = .complete
        } else {
            if state == .verify {
                self.isGetComponentInfoRunning = false
            }
            state = .abort
        }
        stateMachineProcess()
    }
}

extension OtaUpgrader {
    /* The max MTU size is 158 on iOS version < 10, and is 185 when iOS version >= 10. */
    static func getMaxDataTransferSize(deviceType: OtaDeviceType) -> Int {
        let mtuSize = PlatformManager.SYSTEM_MTU_SIZE
        if deviceType == .homeKit {
            return 255  // Max 255 without any error, 2 data packets with 1 ack response.
        } else if deviceType == .mesh {
            return (mtuSize - 3 - 17)   // 3 link layer header bytes, exter 17 Mesh encryption bytes
        }
        return (mtuSize - 3)    // 3 link layer header bytes
    }

    /*
     * Help function to calculate CRC32 checksum for specific data.
     *
     * @param crc32     CRC32 value for calculating.
     *                  The initalize CRC value must be CRC32_INIT_VALUE.
     * @param data      Data required to calculate CRC32 checksum.
     *
     * @return          Calculated CRC32 checksum value.
     *
     * Note, after the latest data has been calculated, the final CRC32 checksum value must be calculuated as below as last step:
     *      crc32 ^= CRC32_INIT_VALUE
     */
    static func calculateCrc32(crc32: UInt32, data: Data) -> UInt32 {
        return MeshNativeHelper.updateCrc32(crc32, data:data)
    }

    // The input @path can be a full path or a relative path under the App's "Documents" directory.
    public static func readParseFirmwareImage(at path: String) -> Data? {
        let filePath: String = path.starts(with: "/") ? path : (NSHomeDirectory() + "/Documents/" + path)
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue, let fwImageData = FileManager.default.contents(atPath: filePath), fwImageData.count > 0 else {
            print("error: OtaUpgrader, readParseFirmwareImage, failed to read and parse firmware image: \(filePath)")
            MeshNativeHelper.meshClientSetDfuFilePath(nil);
            return nil
        }
        MeshNativeHelper.meshClientSetDfuFilePath(filePath);
        return fwImageData
    }

    // The input @path can be a full path or a relative path under the App's "Documents" directory.
    public static func readParseMetadataImage(at path: String) -> OtaDfuMetadata? {
        var cid: UInt16?
        var fwId: Data?     // Firmware ID, 8 bytes.
        var pid: UInt16?    // Product ID, 2 bytes.
        var hwid: UInt16?   // HW Version ID, 2 bytes.
        var fwVer: UInt32?   // FW Version: 4 bytes.
        var fwVerMaj: UInt8?
        var fwVerMin: UInt8?
        var fwVerRev: UInt16?
        var validationData: Data?
        var is_old_image_info_format = false
        do {
            let documentsPath: URL? = path.starts(with: "/") ? nil : URL(fileURLWithPath: NSHomeDirectory() + "/Documents", isDirectory: true)
            let urlPath = URL(fileURLWithPath: path, isDirectory: false, relativeTo: documentsPath)
            let data = try String(contentsOf: urlPath, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            for oneline in lines {
                let line = oneline.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("CID=0x"), line.count >= 10 {
                    is_old_image_info_format = true
                    let index = line.index(line.startIndex, offsetBy: 6)
                    if let value = Int(line[index...], radix: 16) {
                        cid = UInt16(value)
                    }
                } else if line.hasPrefix("FWID=0x"), line.count >= 23 {
                    is_old_image_info_format = true
                    let index = line.index(line.startIndex, offsetBy: 7)
                    let hexString = String(line[index...])
                    fwId = hexString.dataFromHexadecimalString()  // the data stored in big-endian.
                    if let fwIdData = fwId {
                        pid = UInt16((UInt16(fwIdData[0]) << 8) | UInt16(fwIdData[1]))
                        hwid = UInt16((UInt16(fwIdData[2]) << 8) | UInt16(fwIdData[3]))
                        fwVer = UInt32((UInt32(fwIdData[4]) << 24) | (UInt32(fwIdData[5]) << 16) | (UInt32(fwIdData[6]) << 8) | UInt32(fwIdData[7]))
                        fwVerMaj = UInt8(fwIdData[4])
                        fwVerMin = UInt8(fwIdData[5])
                        fwVerRev = UInt16((UInt16(fwIdData[6]) << 8) | UInt16(fwIdData[7]))
                    }
                } else if line.hasPrefix("Firmware ID = 0x"), line.count >= 36 {
                    let index = line.index(line.startIndex, offsetBy: 16)
                    let hexString = String(line[index...])
                    fwId = hexString.dataFromHexadecimalString()  // the data stored in big-endian.
                    if let fwIdData = fwId {
                        cid = UInt16((UInt16(fwIdData[0]) << 8) | UInt16(fwIdData[1]))
                        pid = UInt16((UInt16(fwIdData[2]) << 8) | UInt16(fwIdData[3]))
                        hwid = UInt16((UInt16(fwIdData[4]) << 8) | UInt16(fwIdData[5]))
                        fwVer = UInt32((UInt32(fwIdData[6]) << 24) | (UInt32(fwIdData[7]) << 16) | (UInt32(fwIdData[8]) << 8) | UInt32(fwIdData[9]))
                        fwVerMaj = UInt8(fwIdData[6])
                        fwVerMin = UInt8(fwIdData[7])
                        fwVerRev = UInt16((UInt16(fwIdData[8]) << 8) | UInt16(fwIdData[9]))
                    }
                } else if line.hasPrefix("Validation Data = 0x"), line.count >= 28 {
                    let index = line.index(line.startIndex, offsetBy: 20)
                    let hexString = String(line[index...])
                    validationData = hexString.dataFromHexadecimalString()  // the data stored in big-endian.
                }
            }

            guard let cid = cid, let fwId = fwId, let pid = pid, let hwid = hwid, let fwVer = fwVer,
                let fwVerMaj = fwVerMaj, let fwVerMin = fwVerMin, let fwVerRev = fwVerRev else {
                    print("error: OtaUpgrader, readFwMetadataImageFile, invalid content of the matadata image. \(lines)")
                    MeshNativeHelper.meshClientClearDfuFwMetadata()
                    return nil
            }
            if is_old_image_info_format {
                validationData = Data()
                MeshNativeHelper.meshClientSetDfuFwMetadata(fwId, validationData: validationData!)
                return (cid, fwId, pid, hwid, fwVer, fwVerMaj, fwVerMin, fwVerRev, validationData!)
            }

            guard let validationData = validationData else {
                print("error: OtaUpgrader, readFwMetadataImageFile, invalid content of the matadata image, no validation data. \(lines)")
                MeshNativeHelper.meshClientClearDfuFwMetadata()
                return nil
            }
            // Always update the siglone DFU FW metadata when new firmware image read successfully.
            MeshNativeHelper.meshClientSetDfuFwMetadata(fwId, validationData: validationData)
            return (cid, fwId, pid, hwid, fwVer, fwVerMaj, fwVerMin, fwVerRev, validationData)
        } catch {
            print("error: OtaUpgrader, readFwMetadataImageFile, failed to read \"\(path)\". \(error)")
        }
        MeshNativeHelper.meshClientClearDfuFwMetadata()
        return nil
    }
}

extension String {
    // The hexadecimal string must be no whitespace characters between the string.
    func dataFromHexadecimalString() -> Data? {
        var hexData: Data = Data()
        var hexString = self.trimmingCharacters(in: .whitespaces)
        if (self.hasPrefix("0x") || self.hasPrefix("0X")) {
            let hexIndex = self.index(self.startIndex, offsetBy: 2)
            hexString = String(self[hexIndex...])
        }
        if (hexString.count % 2) != 0 {
            hexString = "0" + hexString
        }

        for i in stride(from: 0, to: hexString.count, by: 2) {
            let startIndex = hexString.index(hexString.startIndex, offsetBy: i)
            let endIndex = hexString.index(hexString.startIndex, offsetBy: (i+1))
            let hexByteStr = hexString[startIndex...endIndex]
            if let byteValue = UInt8(hexByteStr, radix: 16) {
                hexData.append(byteValue)
            }
        }
        return (hexData.count == 0) ? nil : Data(hexData)
    }
}
