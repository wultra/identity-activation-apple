//
// Copyright 2023 Wultra s.r.o.
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

/// WDOLogger provides simple logging facility available for DEBUG build of the library.
public class WDOLogger {
    
    /// Defines verbose level for this simple debugging facility.
    public enum VerboseLevel: Int {
        /// Silences all messages.
        case off = 0
        /// Only errors will be printed to the debug console.
        case errors = 1
        /// Errors and warnings will be printed to the debug console.
        case warnings = 2
        /// All messages will be printed to the debug console.
        case all = 3
    }
    
    /// Current verbose level. Note that value is ignored for non-DEBUG builds.
    public static var verboseLevel: VerboseLevel = .warnings
    
    /// Character limit for single log message. Default is 12 000. Unlimited when nil
    public static var characterLimit: Int? = 12_000
    
    /// Prints simple message to the debug console.
    static func print(_ message: @autoclosure () -> String) {
        #if DEBUG || WPN_ENABLE_LOGGING
        if verboseLevel == .all {
            Swift.print("[WPN] \(message().limit(characterLimit))")
        }
        #endif
    }

    /// Prints warning message to the debug console.
    static func warning(_ message: @autoclosure () -> String) {
        #if DEBUG || WPN_ENABLE_LOGGING
        if verboseLevel.rawValue >= VerboseLevel.warnings.rawValue {
            Swift.print("[WPN] WARNING: \(message().limit(characterLimit))")
        }
        #endif
    }
    
    /// Prints error message to the debug console.
    static func error(_ message: @autoclosure () -> String) {
        #if DEBUG || WPN_ENABLE_LOGGING
        if verboseLevel != .off {
            Swift.print("[WPN] ERROR: \(message().limit(characterLimit))")
        }
        #endif
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
