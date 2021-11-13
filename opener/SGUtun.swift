//
//  SGUtun.swift
//  opener
//
//  Created by 赵睿 on 2021/11/9.
//

import Foundation

class SGUtun {
    var fd: Int32 = -1
    var name = ""
    var isOpen = false
    private let gwip = "10.0.0.1"
    private let completionQueue = DispatchQueue(label: "com.utun.read.completion", attributes: .concurrent)
    
    func `open`() -> Result<Void, POSIXError> {
        (fd, name) = utun_open()
        if fd > 0 {
            SGCommand.run("/sbin/ifconfig \(name) \(gwip) \(gwip) netmask 255.255.255.255 mtu 1380 up")
            isOpen = true
            return .success(())
        } else {
            let code = POSIXErrorCode(rawValue: errno)!
            isOpen = false
            return .failure(.init(code))
        }
    }
    
    func `close`() {
        Darwin.close(fd)
        print("\(name) is closed.")
        isOpen = false
    }
    
    func readData(completion: @escaping (Data) -> Void) -> POSIXError? {
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 1)
        let nbytes = read(self.fd, ptr, 4096)
        if nbytes > 0 {
            // packet captured from utun is loopback frame which link layer header is a 4-byte field
            var packet = Data(bytes: ptr, count: nbytes)
            packet.removeSubrange(0..<4)
            completionQueue.async { completion(packet) }
        } else if nbytes == 0 {
            print("Warning: read null bytes from utun!")
            completionQueue.async { completion(Data()) }
        } else {
            let code = POSIXErrorCode(rawValue: errno)!
            let error = POSIXError(code)
            //completionQueue.async { completion(.failure(error)) }
            return error
        }
        return nil
    }
}
