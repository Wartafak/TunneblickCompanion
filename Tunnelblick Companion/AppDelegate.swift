import Cocoa
import ApplicationServices // for AXIsProcessTrusted

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var monitor: TunnelblickMonitor!
    var statusMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (belt-and-suspenders alongside Info.plist)
        NSApp.setActivationPolicy(.accessory)
        
            requestAccessibilityPermission()
            requestAutomationPermission()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.verifyPermissionsAndContinue()
            }
    }
    
    func verifyPermissionsAndContinue() {
        let hasAccessibility = checkAccessibilityPermission()
        let hasAutomation = checkAutomationPermission()

        guard hasAccessibility && hasAutomation else {
            showPermissionRequiredAlert()
            return
        }

        setupMenuBar()
        monitor = TunnelblickMonitor()
        monitor.onStatusChange = { [weak self] status in
            DispatchQueue.main.async {
                self?.updateStatus(status)
            }
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    // MARK: - Menu Bar Setup

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Tunnelblick Auth Monitor")
            button.image?.isTemplate = true // Adapts to dark/light menu bar
        }

        buildMenu(status: "Monitoring...")
    }

    func buildMenu(status: String) {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Tunnelblick Companion", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        statusMenuItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func updateStatus(_ status: MonitorStatus) {
        if let button = statusItem.button {
            switch status {
            case .monitoring:
                button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Monitoring")
                button.image?.isTemplate = true
            case .authDetected:
                button.image = NSImage(systemSymbolName: "lock.open.fill", accessibilityDescription: "Auth Required")
                button.image?.isTemplate = false
                button.image = tintedImage(named: "lock.open.fill", color: .systemOrange)
            case .waitingForAuth:
                button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Waiting")
                button.image?.isTemplate = false
                button.image = tintedImage(named: "clock.fill", color: .systemYellow)
            case .authComplete:
                button.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Auth Complete")
                button.image?.isTemplate = false
                button.image = tintedImage(named: "lock.fill", color: .systemGreen)
            case .error(let msg):
                button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")
                button.image?.isTemplate = false
                button.image = tintedImage(named: "exclamationmark.triangle.fill", color: .systemRed)
                statusMenuItem?.title = "Error: \(msg)"
                return
            }
        }

        statusMenuItem?.title = status.description
    }

    // Helper to tint SF Symbols
    func tintedImage(named: String, color: NSColor) -> NSImage? {
        guard let image = NSImage(systemSymbolName: named, accessibilityDescription: nil) else { return nil }
        let tinted = image.copy() as! NSImage
        tinted.lockFocus()
        color.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
    
    func requestSystemEventsPermission() {
        let script = NSAppleScript(source: """
                tell application "System Events"
                    return name of first process
                end tell
            """)
            
            var error: NSDictionary?
            let result = script?.executeAndReturnError(&error)
            
            if let error = error {
                print("Error: \(error)")
            } else {
                print("Success: \(result?.stringValue ?? "")")
            }
    }
    
    
    // MARK: - Permission Checking

    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func checkAutomationPermission() -> Bool {
        // The only reliable way to check automation permission is to attempt it
        // and catch the error (-1743 = not authorized)
        let script = NSAppleScript(source: """
            tell application "System Events"
                return name of first process
            end tell
        """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        
        if let error = error {
            let errorCode = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            return errorCode != -1743
        }
        return true
    }
    
    // MARK: - Permission Request

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }

    func requestAutomationPermission() {
        // Attempting to run the script will trigger the automation dialog
        let script = NSAppleScript(source: """
            tell application "System Events"
                return name of first process
            end tell
        """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
    }

    
    
    // MARK: - Missing Permissions Alert

    func showPermissionRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Tunnelblick Companion - Permissions Required"
        alert.informativeText = """
            This app requires Accessibility and Automation permissions to function.

            Please enable them in:
            System Settings → Privacy & Security → Accessibility
            System Settings → Privacy & Security → Automation

            Find this app in each list and enable the toggle, then restart the app.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restart App")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            restartApp()
        } else {
            exit(0)
        }
    }

    func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .absoluteString

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [url]
        task.launch()

        exit(0)
    }
}
