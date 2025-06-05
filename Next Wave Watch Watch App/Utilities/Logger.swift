import Foundation
import os

enum LogLevel: String {
    case debug = "🔍"
    case info = "ℹ️"
    case warning = "⚠️"
    case error = "❌"
}

class WatchLogger {
    static let shared = WatchLogger()
    private let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.federi.Next-Wave", category: "WatchApp")
    
    private init() {}
    
    func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        let source = "\(filename):\(line) - \(function)"
        
        switch level {
        case .debug:
            logger.debug("[\(source)] \(level.rawValue) \(message)")
        case .info:
            logger.info("[\(source)] \(level.rawValue) \(message)")
        case .warning:
            logger.warning("[\(source)] \(level.rawValue) \(message)")
        case .error:
            logger.error("[\(source)] \(level.rawValue) \(message)")
        }
        #endif
    }
    
    // Convenience methods
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
} 