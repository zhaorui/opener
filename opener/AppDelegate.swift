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
    private let rules = ###"""
    
    # Rules Added by OPENER
    set skip on utun8
    pass out on en0 route-to utun8 inet all no state
    
    """###
    
    private var isCapturing: Bool {
        get {
            UserDefaults.standard.bool(forKey: "capturing")
        }
    }
    
    @IBOutlet var window: NSWindow!
    @IBOutlet var utun_label: NSTextField!
    @IBOutlet var pf_text_view: NSTextView!
    @IBOutlet var capture_switch: NSSwitch!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        precondition(getuid() == 0, "must run as root!")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // Mark: Privates
    private func capture() {
        captureQueue.async { [weak self] in
            while self?.isCapturing == true {
                self?.utun.readData { result in
                    switch result {
                    case .success(let data):
                        self?.ether.writeData(data)
                    case .failure(let error):
                        print("read error:", error)
                    }
                }
            }
        }
    }
    
    // Mark: Actions
    @IBAction func toggleUtun(sender: NSSwitch) {
        if sender.state == .on {
            // open utun
            var result = utun.open()
            switch result {
            case .success(_):
                print("\(self.utun.name) is open.")
                utun_label.stringValue = self.utun.name + ":"
            case .failure(let error):
                print("failed to open utun, \(error.code)")
                sender.state = .off
                return
            }
            
            // open en0
            result = ether.open()
            switch result {
            case .success(_):
                print("en0 is open")
            case .failure(let error):
                print("failed to open en0, \(error.code)")
                sender.state = .off
                return
            }
            
            // enable PF rules
            do {
                var confData = try Data(contentsOf: confURL)
                confData.append(rules.data(using: .utf8)!)
                try confData.write(to: confURL)
                SGCommand.run("pfctl -evf /etc/pf.conf")
            } catch {
                print("failed to enable PF, \(error)")
            }
            
            capture()
        } else {
            // disable PF rules
            do {
                SGCommand.run("pfctl -d")
                let confData = try Data(contentsOf: confURL)
                let conf = String(data: confData, encoding: .utf8)
                let conf2 = conf?.replacingOccurrences(of: rules, with: "")
                try conf2?.write(to: confURL, atomically: true, encoding: .utf8)
            } catch {
                print("pf isn't disabled.")
            }
            
            close(utun.fd)
            print("\(utun.name) is closed.")
            close(ether.fd)
            print("\(ether.name) is closed.")
            utun_label.stringValue = "utunN:"
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

