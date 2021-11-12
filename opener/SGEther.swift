//
//  SGEther.swift
//  opener
//
//  Created by 赵睿 on 2021/11/9.
//

import Foundation

enum EtherType {
    static let ipv4 = Data([0x08, 0x00])
    static let ipv6 = Data([0x86, 0xdd])
    static let arp = Data([0x08, 0x06])
}

/// A network service which able to send raw packets on link-layer
class SGEther {
    var fd: Int32 = -1
    var name: String
    var ip: String
    var ipData: Data
    var mac: String
    var router_mac: String
    private var servid: String
    private let header: Data
    
    init() {
        self.name = SGCommand
            .run("echo 'show State:/Network/Global/IPv4' | scutil | grep PrimaryInterface | cut -d: -f 2 | xargs")
            .stdoutData?.string(encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        self.servid = SGCommand
            .run("echo 'show State:/Network/Global/IPv4' | scutil | grep PrimaryService | cut -d: -f 2 | xargs")
            .stdoutData?.string(encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        self.ip = SGCommand.run("ifconfig \(name) | grep 'inet ' | cut -d' ' -f 2")
            .stdoutData?.string(encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let ipfmt = SGIPFormatter()
        self.ipData = ipfmt.data(from: ip) ?? Data()
        
        self.mac = SGCommand.run("ifconfig \(name) | grep ether | cut -d' ' -f 2")
            .stdoutData?.string(encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        self.router_mac = SGCommand
            .run("echo 'show State:/Network/Service/\(servid)/IPv4' | scutil | grep ARPResolvedHardwareAddress | awk '{print $3}'")
            .stdoutData?.string(encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let formatter = SGMACFormatter()
        let dst = formatter.data(from: router_mac) ?? Data()
        let src = formatter.data(from: mac) ?? Data()
        self.header = dst + src + EtherType.ipv4
    }
    
    /// open a NDRV raw socket by which ethernet frames  would be sent
    /// - Returns: result of opening a NDRV raw socket
    func `open`() -> Result<Void, POSIXError> {
        // size of EtherII frame header should be 14 (6 bytes dst + 6 bytes src + 2 bytes type)
        guard self.header.count == 14 else { return .failure(.init(.ENOTSUP)) }
        
        fd = if_open(interface: name)
        if fd > 0 {
            return .success(())
        } else {
            let code = POSIXErrorCode(rawValue: errno)!
            return .failure(.init(code))
        }
    }
    
    func close() {
        Darwin.close(fd)
        print("\(name) is closed.")
    }
    
    /// Assemble data from network layer with etherII frame header then send it to NDRV raw socket
    /// - Parameter data: data from network layer
    func writeData(_ data: Data) {
        let srcIP = data[12...15]
        guard srcIP == ipData else { return } // only redirect out packet
        
        let frame = header + data
        var written = 0
        while written < data.count {
            let nbytes = write(fd, (frame.withUnsafeBytes { $0 }).baseAddress, frame.count)
            if nbytes >= 0 {
                written += nbytes
            } else if errno == EAGAIN {
                print("tun write with error code \(EAGAIN), so try again...")
            } else {
                let reason = String(cString: strerror(errno))
                print("tun write with error code \(errno) on fd \(fd), \(reason)")
                break
            }
        }
    }
}
