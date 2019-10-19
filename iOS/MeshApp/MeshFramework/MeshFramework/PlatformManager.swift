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
    @available(iOS 8.0, *)
    public static var SYSTEM_MTU_SIZE: Int {
        if PlatformManager.m_system_mtu_size > 0 {
            return PlatformManager.m_system_mtu_size;
        }

        let systemVersion = UIDevice.current.systemVersion
        let subVersion = systemVersion.split(separator: ".")
        var mtuSize = 158   // default MTU size for earilier iOS that the version number is below iOS 10.
        var iOSVer = 0

        if subVersion.count > 0 {
            iOSVer = Int(subVersion[0]) ?? 0
        }
        if iOSVer >= 10 {
            mtuSize = 185    // default MTU size is 185 for iOS 10 and later iOS system.
        }
        return mtuSize
    }
}
