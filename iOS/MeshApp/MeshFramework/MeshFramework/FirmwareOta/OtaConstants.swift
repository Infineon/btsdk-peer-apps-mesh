/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * Constant definitions for OTA functions.
 */

import Foundation


public struct OtaConstants {
    public static let DFU_DISTRIBUTION_STATUS_TIMEOUT   = 10     // unit: seconds.
    public static let DFU_FW_ID_LENGTH = 8   // bytes.

    public static let OTA_VERSION_1: Int = 1    // used in default OTA process.
    public static let OTA_VERSION_2: Int = 2    // used in mesh DFU upgrade process.

    public struct BLE {
        public static let UUID_SERVICE_UPGRADE                 = CBUUID(string: "ae5d1e47-5c13-43a0-8635-82ad38a1381f")
        public static let UUID_SERVICE_SECURE_UPGRADE          = CBUUID(string: "c7261110-f425-447a-a1bd-9d7246768bd8")
        public static let UUID_CHARACTERISTIC_CONTROL_POINT    = CBUUID(string: "a3dd50bf-f7a7-4e99-838e-570a086c661b")
        public static let UUID_CHARACTERISTIC_DATA             = CBUUID(string: "a2e86c7a-d961-4091-b74f-2409e72efe26")
        public static let UUID_CHARACTERISTIC_APP_INFO         = CBUUID(string: "a47f7608-2e2d-47eb-913b-75d4edc4de4b")
        public static let UUID_DESCRIPTOR_CCCD                 = CBUUID(string: "2902")
    }

    public struct BLE_V2 {
        public static let UUID_SERVICE_UPGRADE                 = CBUUID(string: "10022922-ccf5-11e8-b680-025041000001")
        public static let UUID_SERVICE_SECURE_UPGRADE          = CBUUID(string: "10270b52-ccf5-11e8-8c28-025041000001")
        public static let UUID_CHARACTERISTIC_CONTROL_POINT    = CBUUID(string: "1058fcfc-ccf5-11e8-b112-025041000001")
        public static let UUID_CHARACTERISTIC_DATA             = CBUUID(string: "107163c8-ccf5-11e8-9b81-025041000001")
        public static let UUID_CHARACTERISTIC_APP_INFO         = CBUUID(string: "10a51326-ccf5-11e8-ab31-025041000001")
        public static let UUID_DESCRIPTOR_CCCD                 = CBUUID(string: "2902")
    }

    public struct HomeKit {
        public static let UUID_SERVICE_UPGRADE                 = CBUUID(string: "b0733e83-8434-4c00-a344-25d1c982a0ef")
        public static let UUID_CHARACTERISTIC_CONTROL_POINT    = CBUUID(string: "b176bd7f-4148-47bd-a6c6-9d0796e96183")
        public static let UUID_CHARACTERISTIC_DATA             = CBUUID(string: "b2fd7f2d-ead3-4f17-b16c-202ec758c697")
        public static let UUID_CHARACTERISTIC_APP_INFO         = CBUUID(string: "b31259a5-9acc-45c2-838a-956f57825196")
    }

    public struct Notification {
        public static let OTA_STATUS_UPDATED                        = "otaStatusUpdated"
        public static let USER_INFO_KEY_OTA_STATE                   = "userInfoOtaState"                // value type: Int, see enum OtaUpgrade.OtaState.
        public static let USER_INFO_KEY_OTA_SUBSTATE                = "userInfoOtaSubState"                // value type: Int, see enum OtaUpgrade.OtaState.
        public static let USER_INFO_KEY_OTA_ERROR_CODE              = "userInfoOtaErrorCode"            // value type: Int, see OtaErrorCode.
        public static let USER_INFO_KEY_OTA_ERROR_DESCRIPTION       = "userInfoOtaErrorDescription"     // value type: String, error description based on error code.
        public static let USER_INFO_KEY_OTA_FW_IMAGE_SIZE           = "userInfoOtaFwImageSize"          // value type: String, fw image size for OTA.
        public static let USER_INFO_KEY_OTA_FW_TRANSFERRED_SIZE     = "userInfoOtaFwTransferredSize"    // value type: String, transfered fw image size during OTA.

        public static func getOtaNotificationData(userInfo: [AnyHashable: Any]) -> OtaNotificationData? {
            guard let userInfo = userInfo as? [String: Any] else {
                return nil
            }
            return OtaNotificationData(userInfo: userInfo)
        }
    }

    public static let UUID_GATT_OTA_SERVICES: [CBUUID] = [OtaConstants.BLE.UUID_SERVICE_UPGRADE,
                                                          OtaConstants.BLE.UUID_SERVICE_SECURE_UPGRADE,
                                                          OtaConstants.BLE_V2.UUID_SERVICE_UPGRADE,
                                                          OtaConstants.BLE_V2.UUID_SERVICE_SECURE_UPGRADE]
    public static let UUID_GATT_OTA_CHARACTERISTICS: [CBUUID] = [OtaConstants.BLE.UUID_CHARACTERISTIC_CONTROL_POINT,
                                                                 OtaConstants.BLE.UUID_CHARACTERISTIC_DATA,
                                                                 OtaConstants.BLE.UUID_CHARACTERISTIC_APP_INFO,
                                                                 OtaConstants.BLE_V2.UUID_CHARACTERISTIC_CONTROL_POINT,
                                                                 OtaConstants.BLE_V2.UUID_CHARACTERISTIC_DATA,
                                                                 OtaConstants.BLE_V2.UUID_CHARACTERISTIC_APP_INFO]
    public static let UUID_GATT_OTA_DESCRIPTORS: [CBUUID] = [OtaConstants.BLE.UUID_DESCRIPTOR_CCCD,
                                                             OtaConstants.BLE_V2.UUID_DESCRIPTOR_CCCD]

    // Mesh FW Distribution Status Code
    public static let MESH_DFU_FW_DISTR_PHASE_IDLE                  = 0x00  /* Distribution is not active. */
    public static let MESH_DFU_FW_DISTR_PHASE_TRANSFER_ACTIVE       = 0x01  /* Firmware transfer in progress. */
    public static let MESH_DFU_FW_DISTR_PHASE_TRANSFER_SUCCESS      = 0x02  /* Firmware transfer is complete and updating nodes verified the firmware success. */
    public static let MESH_DFU_FW_DISTR_PHASE_APPLY_ACTIVE          = 0x03  /* Firmware applying in progress. */
    public static let MESH_DFU_FW_DISTR_PHASE_COMPLETED             = 0x04  /* At least one updating node was updated success. */
    public static let MESH_DFU_FW_DISTR_PHASE_FAILED                = 0x05  /* No updating nodes were updated success. */
}

public struct OtaErrorCode {
    public static let SUCCESS: Int = 0
    public static let PENDING: Int = 1
    public static let BUSYING: Int = 2
    public static let FAILED: Int = 3
    public static let TIMEOUT: Int = 4

    public static let INVALID_PARAMETERS: Int = 3
    public static let INVALID_DATA_NIL: Int = 4
    public static let INVALID_DATA_COUNT: Int = 5
    public static let INVALID_OBJECT_INSTANCES: Int = 6
    public static let INVALID_RESPONSE_VALUE: Int = 7
    public static let INVALID_FW_IMAGE: Int = 8
    public static let INVALID_DEVICE_TYPE_STATE: Int = 9

    public static let INVALID_CBPERIPHERAL_OBJECT: Int = 10
    public static let INVALID_CBSERVICE_OBJECT: Int = 11
    public static let INVALID_CBCHARACTERISTIC_OBJECT: Int = 12
    public static let INVALID_CBDESCRIPTOR_OBJECT: Int = 13

    public static let INVALID_HMACCESSORY_OBJECT: Int = 20
    public static let INVALID_HMSERVICE_OBJECT: Int = 21
    public static let INVALID_HMCHARACTERISTIC_OBJECT: Int = 22

    public static let ERROR_DISCOVER_SERVICE: Int = 30
    public static let ERROR_DISCOVER_CHARACTERISTICS: Int = 31
    public static let ERROR_DISCOVER_DISCRIPTORS: Int = 32
    public static let ERROR_READ_APP_INFO: Int = 33

    public static let ERROR_CHARACTERISTIC_VALUE_UPDATE: Int = 34
    public static let ERROR_CHARACTERISTIC_NOTIFICATION_UPDATE: Int = 35
    public static let ERROR_CHARACTERISTIC_WRITE_VALUE: Int = 36
    public static let ERROR_DISCRIPTOR_VALUE_UPDATE: Int = 37
    public static let ERROR_DISCRIPTOR_WRITE_VALUE: Int = 38

    public static let ERROR_DEVICE_CONNECT: Int = 40
    public static let ERROR_DEVICE_DISCONNECT: Int = 41
    public static let ERROR_DEVICE_OTA_NOT_SUPPORTED: Int = 42

    public static let ERROR_DATA_ENCRYPTION: Int = 50
    public static let ERROR_DATA_DECRYPTION: Int = 51
    public static let ERROR_GET_RESPONSE_VALUE: Int = 52
    public static let ERROR_OTA_ABORTED: Int = 52
    public static let ERROR_OTA_VERIFICATION_FAILED: Int = 54
    public static let ERROR_OTA_V2_APPLY: Int = 55
}


public struct OtaNotificationData {
    public var otaState: Int = OtaUpgrader.OtaState.idle.rawValue
    public var otaSubState: Int = OtaUpgrader.OtaState.idle.rawValue    // used to record the sub-status, set to error state.
    public var errorCode: Int = OtaErrorCode.SUCCESS
    public var description: String = OtaError.DEFAULT_ERROR_DESC
    public var fwImageSize: Int = 0             // valid only when the value of otaState is OtaUpgrader.OtaState.dataTransfer
    public var transferredImageSize: Int = 0    // valid only when the value of otaState is OtaUpgrader.OtaState.dataTransfer

    init(otaState: OtaUpgrader.OtaState, otaError: OtaError?, fwImageSize: Int = 0, transferredImageSize: Int = 0) {
        self.otaState = otaState.rawValue
        self.otaSubState = otaError?.state.rawValue ?? otaState.rawValue
        self.errorCode = otaError?.code ?? OtaErrorCode.SUCCESS
        self.description = otaError?.description ?? OtaError.DEFAULT_ERROR_DESC
        self.fwImageSize = fwImageSize
        self.transferredImageSize = transferredImageSize
    }

    init(otaError: OtaError, fwImageSize: Int = 0, transferredImageSize: Int = 0) {
        self.otaState = otaError.state.rawValue
        self.otaSubState = otaError.state.rawValue
        self.errorCode = otaError.code
        self.description = otaError.description
        self.fwImageSize = fwImageSize
        self.transferredImageSize = transferredImageSize
    }

    init(userInfo: [String: Any]) {
        for (key, value) in userInfo {
            if key == OtaConstants.Notification.USER_INFO_KEY_OTA_STATE, value is Int, let value = value as? Int {
                otaState = value
            } else if key == OtaConstants.Notification.USER_INFO_KEY_OTA_SUBSTATE, value is Int, let value = value as? Int {
                otaSubState = value
            } else if key == OtaConstants.Notification.USER_INFO_KEY_OTA_ERROR_CODE, value is Int, let value = value as? Int {
                errorCode = value
            } else if key == OtaConstants.Notification.USER_INFO_KEY_OTA_ERROR_DESCRIPTION, value is String, let value = value as? String {
                description = value
            } else if key == OtaConstants.Notification.USER_INFO_KEY_OTA_FW_IMAGE_SIZE, value is Int, let value = value as? Int {
                fwImageSize = value
            } else if key == OtaConstants.Notification.USER_INFO_KEY_OTA_FW_TRANSFERRED_SIZE, value is Int, let value = value as? Int {
                transferredImageSize = value
            }
        }
    }

    public var userInfoData: [String: Any] {
        return [OtaConstants.Notification.USER_INFO_KEY_OTA_STATE: otaState,
                OtaConstants.Notification.USER_INFO_KEY_OTA_SUBSTATE: otaSubState,
                OtaConstants.Notification.USER_INFO_KEY_OTA_ERROR_CODE: errorCode,
                OtaConstants.Notification.USER_INFO_KEY_OTA_ERROR_DESCRIPTION: description,
                OtaConstants.Notification.USER_INFO_KEY_OTA_FW_IMAGE_SIZE: fwImageSize,
                OtaConstants.Notification.USER_INFO_KEY_OTA_FW_TRANSFERRED_SIZE: transferredImageSize]
    }

    func post() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: OtaConstants.Notification.OTA_STATUS_UPDATED),
                                        object: nil,
                                        userInfo: userInfoData)
    }
}

public struct OtaError: Error {
    public static let DEFAULT_ERROR_DESC = "success"

    private var otaState: OtaUpgrader.OtaState = .idle
    private var errorCode: Int = OtaErrorCode.SUCCESS
    private var errorDesc: String = DEFAULT_ERROR_DESC

    public var state: OtaUpgrader.OtaState {
        return otaState
    }
    public var code: Int {
        return errorCode
    }
    public var description: String {
        return errorDesc
    }

    public var localizedDescription: String {
        return "OTA Error, state:\(otaState.description), code:\(errorCode), description:\(errorDesc)"
    }

    public init(state: OtaUpgrader.OtaState, code: Int?, desc: String?) {
        self.otaState = state
        guard let code = code else {
            return  // use default initialized values.
        }
        self.errorCode = code
        self.errorDesc = desc ?? OtaError.DEFAULT_ERROR_DESC
    }

    // normal OtaError, not in OTA processing state.
    public init(code: Int, desc: String) {
        self.errorCode = code
        self.errorDesc = desc
    }
}

public struct MeshDfuType {
    static public let PROXY_DFU_TO_ALL = 0
    static public let APP_DFU_TO_ALL = 1
    static public let APP_OTA_TO_DEVICE = 2
    static public let DFU_TYPE_TEXT_MAP: [Int: String] = [MeshDfuType.PROXY_DFU_TO_ALL: "Proxy DFU to All",
                                                          MeshDfuType.APP_DFU_TO_ALL: "App DFU to All",
                                                          MeshDfuType.APP_OTA_TO_DEVICE: "App OTA to Device"]
    static public var DFU_TYPE_TEXT_LIST: [String] {
        return [MeshDfuType.DFU_TYPE_TEXT_MAP[MeshDfuType.PROXY_DFU_TO_ALL]!,
                MeshDfuType.DFU_TYPE_TEXT_MAP[MeshDfuType.APP_DFU_TO_ALL]!,
                MeshDfuType.DFU_TYPE_TEXT_MAP[MeshDfuType.APP_OTA_TO_DEVICE]!]
    }

    public static func getDfuType(by typeText: String) -> Int? {
        for (type, text) in MeshDfuType.DFU_TYPE_TEXT_MAP {
            if text == typeText {
                return type
            }
        }
        return nil
    }

    public static func getDfuTypeText(type: Int) -> String? {
        for (typeValue, text) in MeshDfuType.DFU_TYPE_TEXT_MAP {
            if typeValue == type {
                return text
            }
        }
        return nil
    }
}

public struct MeshDfuEvent {
    static public let DFU_EVENT_START_OTA = 1
}
