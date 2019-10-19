/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * This file implements the PlatformManager class to manage all platform specific functions.
 */

import Foundation

class PlatformManager: NSObject {
    static let shared = PlatformManager()

    private static var m_system_mtu_size: Int = -1   // default not set.
    @available(watchOS 2.0, *)
    public static var SYSTEM_MTU_SIZE: Int {
        if PlatformManager.m_system_mtu_size > 0 {
            return PlatformManager.m_system_mtu_size;
        }

        let systemVersion = WKInterfaceDevice.current().systemVersion
        let subVersion = systemVersion.split(separator: ".")
        var mtuSize = 158
        var watchOSVer = 0

        if subVersion.count > 0 {
            watchOSVer = Int(subVersion[0]) ?? 0
        }
        if watchOSVer >= 4 {
            mtuSize = 185
        }
        return mtuSize
    }
}
