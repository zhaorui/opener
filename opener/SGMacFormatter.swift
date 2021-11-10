//
//  SGMacFormatter.swift
//  opener
//
//  Created by 赵睿 on 2021/11/10.
//

import Foundation


class SGMacFormatter: Formatter {
    override func string(for obj: Any?) -> String? {
        guard let macData = obj as? Data, macData.count == 6 else { return nil }
        return macData.hexEncodedString(separator: ":")
    }
    
    func data(from string: String) -> Data? {
        let hexArray = string.components(separatedBy: ":")
        guard hexArray.count == 6 else { return nil }
        
        do {
            let bytes = try hexArray.reduce(into: [UInt8]()) { partialResult, hex in
                if let byte = UInt8(hex, radix: 16) {
                    partialResult.append(byte)
                } else {
                    throw "not able to convert \(hex) to UInt8!"
                }
            }
            return Data(bytes)
        } catch {
            return nil
        }
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        guard let macData = data(from: string) else { return false }
        obj?.pointee = macData as AnyObject
        return true
    }
}
