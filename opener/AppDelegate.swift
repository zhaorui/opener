//
//  AppDelegate.swift
//  opener
//
//  Created by 赵睿 on 2021/11/7.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let utun = SGUtun()
    private let ether = SGEther()
    private let captureQueue = DispatchQueue(label: "com.opener.app.capture")
    private let confURL = URL(fileURLWithPath: "/etc/pf.conf")
    
    @objc private var rules = NSAttributedString(string: "")
    
    private var isCapturing: Bool {
        get {
            var value = false
            SGAtomicQueue.sync {
                value = UserDefaults.standard.bool(forKey: "capturing")
            }
            return value
        }
        
        set {
            SGAtomicQueue.sync {
                UserDefaults.standard.setValue(newValue, forKey: "capturing")
            }
        }
    }
    
    @IBOutlet var window: NSWindow!
    @IBOutlet var pf_text_view: NSTextView!
    @IBOutlet var capture_switch: NSSwitch!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        precondition(getuid() == 0, "must run as root!")
        
        // open utun & ether interface
        guard openUtunAndEther() else { return }
        
        // setup pf rules
        let defaultRules = NSAttributedString(string: """
        
        # Rules Added by OPENER
        set skip on \(utun.name)
        pass out on \(ether.name) route-to \(utun.name) inet all no state
        pass in  on \(ether.name) dup-to \(utun.name) inet all no state
        
        """, attributes: [.foregroundColor: NSColor.textColor])
        
        rules = defaultRules
        pf_text_view.textStorage?.setAttributedString(defaultRules)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if isCapturing {
            disable()
        }
        isCapturing = false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Privates
    private func openUtunAndEther() -> Bool {
        var result: Result<Void, POSIXError>?
        // open utun
        if !utun.isOpen {
            result = utun.open()
            switch result! {
            case .success(_):
                print("\(self.utun.name) is open.")
            case .failure(let error):
                print("failed to open utun, \(error.code)")
                capture_switch.isEnabled = false
                return false
            }
        }
        
        // open en0
        if !ether.isOpen {
            result = ether.open()
            switch result! {
            case .success(_):
                print("\(ether.name) is open")
            case .failure(let error):
                print("failed to open \(ether.name), \(error.code)")
                utun.close()
                capture_switch.isEnabled = false
                return false
            }
        }
        
        return true
    }
    
    private func capture() {
        captureQueue.async { [weak self] in
            var error: POSIXError?
            while self?.isCapturing == true, (error == nil || error!.code == .EAGAIN )  {
                error = self?.utun.readData(completion: { data in
                    self?.ether.writeData(data)
                })
            }
        }
    }
    
    private func showAlert(title: String, info: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.beginSheetModal(for: self.window) { response in
            print(response)
        }
    }
    
    /// parse pf statements in /etc/pf.conf
    /// - Returns: parse result
    private func parse() -> Bool {
        do {
            let origin = try Data(contentsOf: confURL)
            var confData = origin
            confData.append(rules.string.data(using: .utf8)!)
            try confData.write(to: confURL)
            let cmd = SGCommand.run("pfctl -n -f /etc/pf.conf")
            
            if !cmd.succeeded {
                let reason = cmd.stderrData?.string(encoding: .utf8)
                showAlert(title: "PF rules invalid", info: reason ?? "unknown")
                try origin.write(to: confURL, options: .atomic)
                return false
            }
        } catch  {
            return false
        }
        
        return true
    }
    
    private func enable() throws {
        guard openUtunAndEther() else { throw "failed to open interface while enabling" }
        
        if parse() {
            // enable PF rules
            SGCommand.run("pfctl -evf /etc/pf.conf")
        } else {
            // PF rules invalid
            utun.close()
            ether.close()
            capture_switch.state = .off
            throw "failed to enable as pf rules are invalid"
        }
        
        capture()
    }
    
    private func disable() {
        // disable PF rules
        do {
            SGCommand.run("pfctl -d")
            SGCommand.run("pfctl -F rules")
            let confData = try Data(contentsOf: confURL)
            let conf = String(data: confData, encoding: .utf8)
            let conf2 = conf?.replacingOccurrences(of: rules.string, with: "")
            try conf2?.write(to: confURL, atomically: true, encoding: .utf8)
        } catch {
            print("ERROR: pf isn't disabled!")
            return
        }
        
        if utun.isOpen {
            utun.close()
        }
        
        if ether.isOpen {
            ether.close()
        }
    }
    
    // MARK: - Actions
    @IBAction func toggleUtun(sender: NSSwitch) {
        do {
            if sender.state == .on {
                try enable()
            } else {
                disable()
            }
        } catch {
            print(error)
        }
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "opener")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving and Undo support

    @IBAction func saveAction(_ sender: AnyObject?) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        let context = persistentContainer.viewContext

        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Customize this code block to include application-specific recovery steps.
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return persistentContainer.viewContext.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !context.hasChanges {
            return .terminateNow
        }
        
        do {
            try context.save()
        } catch {
            let nserror = error as NSError

            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if (result) {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }

}

