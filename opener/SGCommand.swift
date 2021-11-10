//
//  SGCommand.swift
//  opener
//
//  Created by 赵睿 on 2021/11/7.
//

import Foundation

struct SGCommand {
    let cmdData: Data
    var stdoutData: Data?
    var stderrData: Data?
    
    var result: String {
        guard let data = stdoutData else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    var error: String {
        guard let data = stderrData else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private mutating func execute() {
        let process = Process()
        let pipe = Pipe()
        
        process.launchPath = "/bin/bash"
        pipe.fileHandleForWriting.write(cmdData)
        pipe.fileHandleForWriting.closeFile()
        process.standardInput = pipe
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.launch()
        process.waitUntilExit()
        
        let stdout = (process.standardOutput as! Pipe).fileHandleForReading
        let stderr = (process.standardError as! Pipe).fileHandleForReading
        
        self.stdoutData = stdout.readDataToEndOfFile()
        self.stderrData = stderr.readDataToEndOfFile()
    }
    
    @discardableResult
    static func run(_ command: String) -> SGCommand {
        var command = SGCommand(cmdData: command.data(using: .utf8)!)
        command.execute()
        return command
    }
}
