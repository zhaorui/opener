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
    private let gwip = "10.0.0.1"
    
    func `open`() -> Result<Void, POSIXError> {
        (fd, name) = utun_open()
        if fd > 0 {
            SGCommand.run("/sbin/ifconfig \(name) \(gwip) \(gwip) netmask 255.255.255.255 mtu 1380 up")
            return .success(())
        } else {
            let code = POSIXErrorCode(rawValue: errno)!
            return .failure(.init(code))
        }
    }
    
    func readData(completion: (Result<Data, Error>) -> Void) {
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 1)
        let nbytes = read(self.fd, ptr, 4096)
        if nbytes > 0 {
            // packet captured from utun is loopback frame which link layer header is a 4-byte field
            let packet = Data(bytes: ptr, count: nbytes).dropFirst(4)
            completion(.success(packet))
        } else if nbytes == 0 {
            completion(.success(Data()))
        } else {
            let code = POSIXErrorCode(rawValue: errno)!
            let error = POSIXError(code)
            completion(.failure(error))
        }
    }
}
