/*
 * Copyright Cypress Semiconductor
 */

/** @file
 *
 * This file implements the MeshUtility class which supplies commonly usage functions for this framwork.
 */

import Foundation

open class MeshUtility: NSObject {
    public static func MD5(data: Data) -> Data {
        return MeshNativeHelper.md5(data)
    }

    public static func MD5(string: String) -> String {
        let data = string.data(using: .utf8)!
        let md5Data = MD5(data: data)
        let md5String: NSMutableString = NSMutableString()
        for i in 0 ..< md5Data.count {
            md5String.append(String(format: "%02X", UInt8(md5Data[i])))
        }
        return md5String.description
    }
}

extension Data {
    public func dumpHexBytes() -> String {
        let msg: NSMutableString = NSMutableString()
        if (self.count > 0) {
            // dump firstly byte.
            msg.append(String(format: "%02X", UInt8(self[0])))
            // dump second and continue bytes if exists.
            for i in 1 ..< self.count {
                msg.append(String(format: " %02X", UInt8(self[i])))
            }
            return msg.description
        }
        return ""
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var dict = [Element: Bool]()
        return filter {
            dict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}
