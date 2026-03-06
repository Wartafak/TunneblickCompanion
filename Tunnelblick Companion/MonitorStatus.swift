import Foundation

enum MonitorStatus {
    case monitoring
    case authDetected
    case waitingForAuth
    case authComplete
    case error(String)

    var description: String {
        switch self {
        case .monitoring:       return "⬤  Monitoring Tunnelblick logs..."
        case .authDetected:     return "⬤  Auth URL detected — opening browser"
        case .waitingForAuth:   return "⬤  Waiting for authorization..."
        case .authComplete:     return "⬤  Auth complete — clicking OK"
        case .error(let msg):   return "⬤  Error: \(msg)"
        }
    }
}
