//
//  Helper.swift
//  opener
//
//  Created by 赵睿 on 2021/11/7.
//

import Foundation

/// 开启utun环回接口
/// - Returns: 返回该网络接口的文件描述符和接口名称
func utun_open() -> (fd: Int32, utun: String) {

    for unit in 0...255 {

        var sctl = sockaddr_ctl()
        var ctlInfo = ctl_info()

        memset(&sctl, 0, MemoryLayout.size(ofValue: sctl))
        memset(&ctlInfo, 0, MemoryLayout.size(ofValue: ctlInfo))

        let len = strlcpy(&ctlInfo.ctl_name.0, UTUN_CONTROL_NAME, MemoryLayout.size(ofValue: ctlInfo.ctl_name))
        if len >= MemoryLayout.size(ofValue: ctlInfo.ctl_name) {
            print("UTUN_CONTROL_NAME too long")
            return (-1, "")
        }

        let utunfd = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL)
        if utunfd < 0 {
            print("socket(SYSPROTO_CONTROL)")
            return (-1, "")
        }

        // CTLIOCGINFO = 0xC0644E03
        if ioctl(utunfd, 0xC0644E03, &ctlInfo) == -1 {
            print("ioctl(CTLIOCGINFO)")
            return (-1, "")
        }

        sctl.sc_id = ctlInfo.ctl_id
        sctl.sc_len = u_char(MemoryLayout.size(ofValue: sctl))
        sctl.sc_family = u_char(AF_SYSTEM)
        sctl.ss_sysaddr = UInt16(AF_SYS_CONTROL)
        sctl.sc_unit = UInt32(unit)

        // If the connect is successful, a utunX device will be created, where X
        // is our unit number - 1.
        // let sctlPtr = withUnsafePointer(to: &sctl) { return UnsafePointer<sockaddr>($0)}
        let ptr = withUnsafeBytes(of: &sctl) { $0.baseAddress?.assumingMemoryBound(to: sockaddr.self) }
        if connect(utunfd, ptr, UInt32(MemoryLayout.size(ofValue: sctl))) == -1 {
            continue
        }

        var utunname = [CChar](repeating: 0, count: 20)
        var utunnameLen = UInt32(MemoryLayout.size(ofValue: utunname))
        if getsockopt(utunfd, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, &utunname, &utunnameLen) == -1 {
            print("getsockopt(SYSPROTO_CONTROL)")
        }

        return (utunfd, String(cString: &utunname))

    }

    return (-1, "")
}


/// 打开真实网卡并获取其文件描述符
/// - Parameter interface: 指定的网络接口
/// - Returns: 返回网口文件描述符用于读写数据包
func if_open(interface: String) -> Int32 {
    if (geteuid()) != 0 { print("No root, no service") }

    guard !interface.isEmpty, interface.count < 17 else {
        print("ll open error : No Interface Name Or too long")
        return -1
    }

    let llfd = socket(PF_NDRV, SOCK_RAW, 0)
    if llfd < 0 {
        print("Can not create llfd : \(interface)")
        return -1
    }

    // 初始化Ndrv地址，用于bind socket
    var saNdrv = sockaddr_ndrv()
    memset(&saNdrv, 0, MemoryLayout.size(ofValue: saNdrv))
    withUnsafeMutablePointer(to: &saNdrv.snd_name) { pointer in
        let bound = pointer.withMemoryRebound(to: UInt8.self, capacity: interface.count) { $0 }
        interface.utf8.enumerated().forEach { (bound + $0.offset).pointee = $0.element }
    }
    saNdrv.snd_len = 18
    saNdrv.snd_family = UInt8(PF_NDRV)

    // 获取Ndrv Address指针，并将获取到的指针转换为socketAddress的指针用于传入bind函数
    let saNdrvPtr = withUnsafePointer(to: &saNdrv, { $0 })
    let saPtr = saNdrvPtr.withMemoryRebound(to: sockaddr.self, capacity: 18, { $0 })
    let result = bind(llfd, saPtr, 18)
    if result < 0 {
        print("Bind llfd error : \(interface)")
        return -1
    }

    // Connect
    let result2 = connect(llfd, saPtr, 18)
    if result2 < 0 {
        print("Connect llfd error : \(interface)")
        return -1
    }

    return llfd
}
