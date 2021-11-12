//
//  SGIPFormatter.swift
//  opener
//
//  Created by saast on 2021/11/11.
//

import Foundation

class SGIPFormatter: Formatter {
    override func string(for obj: Any?) -> String? {
        guard let ipData = obj as? Data, ipData.count == 4 else { return nil }
        return ipData.decimalEncodedString(separator: ".")
    }
    
    func data(from string: String) -> Data? {
        let decArray = string.components(separatedBy: ".")
        guard decArray.count == 4 else { return nil }
        
        do {
            let bytes = try decArray.reduce(into: [UInt8]()) { partialResult, dec in
                if let byte = UInt8(dec, radix: 10) {
                    partialResult.append(byte)
                } else {
                    throw "not able to convert \(dec) to UInt8!"
                }
            }
            return Data(bytes)
        } catch {
            return nil
        }
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        guard let ipData = data(from: string) else { return false }
        obj?.pointee = ipData as AnyObject
        return true
    }
}
