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
