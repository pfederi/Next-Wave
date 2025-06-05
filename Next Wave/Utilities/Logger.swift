import Foundation
import os

class iOSLogger {
    static let shared = iOSLogger()
    private let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.federi.Next-Wave", category: "WatchConnectivity")
    
    private init() {}
    
    func debug(_ message: String) {
        #if DEBUG
        logger.debug("📱 \(message)")
        #endif
    }
    
    func error(_ message: String) {
        logger.error("❌ \(message)")
    }
} 