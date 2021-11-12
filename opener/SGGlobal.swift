//
//  SGGlobal.swift
//  opener
//
//  Created by saast on 2021/11/12.
//

import Foundation

class SGPacketsBuffer {
    static let shared = SGPacketsBuffer()
    var packetQueue = [Data]()
    var lock = os_unfair_lock()
    
    func appendPacket(_ data: Data) {
        os_unfair_lock_lock(&lock)
        packetQueue.append(data)
        os_unfair_lock_unlock(&lock)
    }
    
    func removeFirstPacket() -> Data {
        os_unfair_lock_lock(&lock)
        let packet = packetQueue.removeFirst()
        os_unfair_lock_unlock(&lock)
        return packet
    }
}

let SGAtomicQueue = DispatchQueue(label: "com.opener.app.atomic")
