import Foundation
import AppKit

class TunnelblickMonitor {

    // MARK: - Config
    private let checkInterval: TimeInterval = 2.0
    private let authWaitTimeout: TimeInterval = 60.0
    private let authPollInterval: TimeInterval = 2.0

    private let logDir = "/Library/Application Support/Tunnelblick/Logs"

    // MARK: - State
    private var timer: Timer?
    private var isHandlingAuth = false
    var onStatusChange: ((MonitorStatus) -> Void)?

    // MARK: - Lifecycle

    func start() {
        log("Monitor started. Watching: \(logDir)")
        onStatusChange?(.monitoring)

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkLogs()
        }
        // Run immediately on start too
        checkLogs()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        log("Monitor stopped.")
    }

    // MARK: - Log Checking

    private func checkLogs() {
        // Don't overlap with ongoing auth handling
        guard !isHandlingAuth else { return }

        guard let latestLog = findLatestLog() else { return }

        guard let authURL = findAuthURL(in: latestLog) else { return }

        log("Auth URL detected: \(authURL)")
        isHandlingAuth = true
        onStatusChange?(.authDetected)

        openInBrowser(authURL)
        waitForAuth(authURL)
    }

    // MARK: - Log Discovery

    private func findLatestLog() -> String? {
        let logDirURL = URL(fileURLWithPath: logDir)
        let fileManager = FileManager.default
        
        // Define the properties we want to fetch (name and modification date)
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        
        do {
            let files = try fileManager.contentsOfDirectory(at: logDirURL,
                                                             includingPropertiesForKeys: keys,
                                                             options: .skipsHiddenFiles)
            
            let latestLog = files
                .filter { $0.pathExtension == "log" }
                .compactMap { url -> (URL, Date)? in
                    // Get the modification date for each file
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    if let date = values?.contentModificationDate {
                        return (url, date)
                    }
                    return nil
                }
                .sorted { $0.1 > $1.1 } // Sort by date descending
                .first?
                .0.path
            
            return latestLog
        } catch {
            print("Error searching for logs: \(error)")
            return nil
        }
    }
    
    private func findAuthURL(in logPath: String) -> String? {
        let logURL = URL(fileURLWithPath: logPath)
        
        do {
            // 1. Read the file content
            let content = try String(contentsOf: logURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            
            // 2. Get the last 5 lines (simulating 'tail -n 5')
            let lastLines = lines.suffix(5)
            
            // 3. Find the line containing the auth trigger
            guard let authLine = lastLines.first(where: { $0.contains("Please authorize at") }) else {
                return nil
            }
            
            // 4. Extract the URL using Regex
            // Pattern: https:// followed by any non-whitespace characters
            let pattern = #"https://[^\s]+"#
            if let range = authLine.range(of: pattern, options: .regularExpression) {
                return String(authLine[range])
            }
            
        } catch {
            print("Could not read log file: \(error)")
        }
        
        return nil
    }

    // MARK: - Auth Flow

    private func openInBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }

    private func waitForAuth(_ urlString: String) {
        onStatusChange?(.waitingForAuth)
        log("Waiting for auth to complete (polling \(urlString))")

        let startTime = Date()

        Task { [weak self] in
            guard let self = self else { return }

            while true {
                let elapsed = Date().timeIntervalSince(startTime)
                
                if elapsed >= self.authWaitTimeout {
                    self.log("Auth wait timed out after \(Int(self.authWaitTimeout))s")
                    self.onStatusChange?(.error("Auth timed out"))
                    self.isHandlingAuth = false
                    
                    try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                    self.onStatusChange?(.monitoring)
                    return
                }

                let status = await self.httpStatus(for: urlString)
                self.log("Auth URL HTTP status: \(status ?? "unknown")")

                if status == "404" {
                    self.log("Auth complete (404 received). Clicking OK in Tunnelblick.")
                    self.onStatusChange?(.authComplete)
                    
                    try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                    self.clickOKInTunnelblick()
                    
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    self.isHandlingAuth = false
                    self.onStatusChange?(.monitoring)
                    return
                }

                let nanoseconds = UInt64(self.authPollInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
        }
    }
    
    private func httpStatus(for urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return "\(httpResponse.statusCode)"
            }
        } catch {
            // Log the actual error for debugging, then return nil
            print("Network request failed: \(error.localizedDescription)")
        }
        
        return nil
    }

    // MARK: - Tunnelblick UI Interaction

    private func clickOKInTunnelblick() {
        // Use AppleScript via NSAppleScript to click OK button in Tunnelblick
        let script = """
        tell application "System Events"
            if exists (process "Tunnelblick") then
                tell process "Tunnelblick"
                    set frontmost to true
                    try
                        click button "OK" of front window
                    on error
                        key code 36
                    end try
                end tell
            end if
        end tell
        """
        runAppleScript(script)
    }
    
    //MARK: Helper functions

    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&error)
        if let err = error {
            log("AppleScript error: \(err)")
            return false
        }
        return true
    }

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("[\(formatter.string(from: Date()))] TunnelblickMonitor: \(message)")
    }
}
