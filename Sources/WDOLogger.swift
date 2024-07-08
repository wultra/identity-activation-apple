//
// Copyright 2020 Wultra s.r.o.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions
// and limitations under the License.
//

import Foundation

/// WDOLogger provides simple logging facility.
///
/// Note that HTTP logs are managed by the underlying Networking library (via `WPNLogger` class).
public class WDOLogger {
    
    /// Verbose level of the logger.
    public enum VerboseLevel: Int {
        /// Silences all messages.
        case off = 0
        /// Only errors will be logged.
        case errors = 1
        /// Errors and warnings will be logged.
        case warnings = 2
        /// Error, warning and info messages will be logged.
        case info = 3
        /// All messages will logged - including debug messages
        case debug = 4
    }
    
    /// Logger delegate
    public static weak var delegate: WDOLoggerDelegate?
    
    /// Current verbose level. `warnings` by default
    public static var verboseLevel: VerboseLevel = .warnings
    
    /// Character limit for single log message. Default is `12 000`. Unlimited when nil
    public static var characterLimit: Int? = 12_000
    
    /// Prints simple message to the system console.
    static func debug(_ message: @autoclosure () -> String) {
        log(message(), level: .debug)
    }
    
    /// Prints simple message to the system console.
    static func info(_ message: @autoclosure () -> String) {
        log(message(), level: .info)
    }

    /// Prints warning message to the system console.
    static func warning(_ message: @autoclosure () -> String) {
        log(message(), level: .warning)
    }
    
    /// Prints error message to the system console.
    static func error(_ message: @autoclosure () -> String) {
        log(message(), level: .error)
    }
    
    /// Prints error message to the system console.
    static func error(_ e: Error) {
        log(e.localizedDescription, level: .error)
    }
    
    private static func log(_ message: @autoclosure () -> String, level: WDOLogLevel) {
        let levelAllowed = level.minVerboseLevel.rawValue <= verboseLevel.rawValue
        let forceReport = delegate?.wdoFollowVerboseLevel == false
        guard levelAllowed || forceReport else {
            // not logging
            return
        }
        
        let msg = message().limit(characterLimit)
        
        if levelAllowed {
            print("[WDO:\(level.logName)] \(msg)")
        }
        if levelAllowed || forceReport {
            delegate?.wdoLog(message: msg, logLevel: level)
        }
    }
    
    #if DEBUG
    /// Unconditionally prints a given message and stops execution
    ///
    /// - Parameters:
    ///   - message: The string to print. The default is an empty string.
    ///   - file: The file name to print with message. The default is file path where fatalError is called for DEBUG configuration, empty string for other
    ///   - line: The line number to print along with message. The default is the line number where fatalError is called.
    static func fatalError(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) -> Never {
        Swift.fatalError(message(), file: file, line: line)
    }
    #else
    /// Unconditionally prints a given message and stops execution
    ///
    /// - Parameters:
    ///   - message: The string to print. The default is an empty string.
    ///   - file: The file name to print with message. The default is file path where fatalError is called for DEBUG configuration, empty string for other
    ///   - line: The line number to print along with message. The default is the line number where fatalError is called.
    static func fatalError(_ message: @autoclosure () -> String = "", file: StaticString = "", line: UInt = #line) -> Never {
        Swift.fatalError(message(), file: file, line: line)
    }
    #endif
    
    private init() { } // we don't want to provide constructor
}

/// Delegate that can further process logs from the library
public protocol WDOLoggerDelegate: AnyObject {
    
    /// If the delegate should follow selected verbosity level.
    ///
    /// When set to true, then (for example) if `errors` is selected as a `verboseLevel`, only `error` logLevel will be called.
    /// When set to false, all methods might be called no matter the selected `verboseLevel`.
    var wdoFollowVerboseLevel: Bool { get }
    
    /// Log was recorded
    /// - Parameters:
    ///   - message: Message of the log
    ///   - logLevel: Log level
    func wdoLog(message: String, logLevel: WDOLogLevel)
}

/// Level of the log
public enum WDOLogLevel {
    /// Debug logs. Might contain sensitive data like body of the request etc.
    /// You should only use this level during development.
    case debug
    /// Regular library logic logs
    case info
    /// Non-critical warning
    case warning
    /// Error happened
    case error
    
    fileprivate var minVerboseLevel: WDOLogger.VerboseLevel {
        return switch self {
        case .debug: .debug
        case .info: .info
        case .warning: .warnings
        case .error: .errors
        }
    }
    
    fileprivate var logName: String {
        return switch self {
        case .debug: "DEBUG"
        case .info: "INFO"
        case .warning: "WARNING"
        case .error: "ERROR"
        }
    }
}

private extension String {
    func limit(_ characterLimit: Int?) -> String {
        guard let cl = characterLimit else {
            return self
        }
        return String(prefix(cl))
    }
}

internal typealias D = WDOLogger
