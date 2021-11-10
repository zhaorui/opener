//
//  Extensions.swift
//  opener
//
//  Created by 赵睿 on 2021/11/10.
//

import Foundation

extension Data {
    func string(encoding: String.Encoding) -> String? {
        return String(data: self, encoding: encoding)
    }
    
    func hexEncodedString(separator sep: String = "") -> String {
        return map { String(format: "%02hhx", $0) }.joined(separator: sep)
    }
}

extension String: Error {}
