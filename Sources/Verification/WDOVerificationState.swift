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

/// State which should be presented to the user
public enum WDOVerificationState: CustomStringConvertible {
    
    /// Reason why is server processing
    public enum ProcessingItem: CustomStringConvertible {
        /// Reason cannot be specified
        case other
        /// Documents are being uploaded to a internal systems
        case documentUpload
        /// Documents are being verified
        case documentVerification
        /// Documents were accepted and we're waiting for a process change
        case documentAccepted
        /// Uploaded are being cross-checked if the're issues for the same person.
        case documentsCrossVerification
        /// Verifying presence of the user infront of the phone (selfie verification).
        case verifyingPresence
        /// Client data provided are being verified by the system.
        case clientVerification
        /// Client data were accepted and we're waiting for a process change
        case clientAccepted
        
        public var description: String {
            let prefix = "WDOVerificationState.ProcessingItem"
            switch self {
            case .other: return "\(prefix).other"
            case .documentUpload: return "\(prefix).documentUpload"
            case .documentVerification: return "\(prefix).documentVerification"
            case .documentAccepted: return "\(prefix).documentAccepted"
            case .documentsCrossVerification: return "\(prefix).documentsCrossVerification"
            case .clientVerification: return "\(prefix).clientVerification"
            case .clientAccepted: return "\(prefix).clientAccepted"
            case .verifyingPresence: return "\(prefix).verifyingPresence"
                
            }
        }
    }
    
    /// Why the process ended in non-recoverable state
    public enum EndstateReason: CustomStringConvertible {
        /// The verification was rejected
        case rejected
        /// Limit of repeat tries was reached
        case limitReached
        /// Other reason
        case other
        
        public var description: String {
            let prefix = "WDOVerificationState.EndstateReason"
            switch self {
            case .limitReached: return "\(prefix).limitReached"
            case .other: return "\(prefix).other"
            case .rejected: return "\(prefix).rejected"
            }
        }
    }
    /// Show verification introuction screen
    case intro
    /// Show approve/cancel user consent
    case consent(_ html: String)
    /// Show document selection to the user
    case documentsToScanSelect
    /// User should scan documents
    case scanDocument(_ process: WDOVerificationScanProcess)
    /// The system is processing data
    case processing(_ item: ProcessingItem)
    /// User should be presented with a presence check
    case presenceCheck
    /// User should enter OTP
    case otp(_ remainingAttempts: Int?)
    /// Verification failed and can be restarted
    case failed
    /// Verification is canceled and user needs to start again with an activation
    case endstate(_ reason: EndstateReason)
    /// Verification was sucessfully ended
    case success
    
    public var description: String {
        let prefix = "WDOVerificationState"
        switch self {
        case .intro: return "\(prefix).intro"
        case .consent: return "\(prefix).consent"
        case .documentsToScanSelect: return "\(prefix).documentsToScanSelect"
        case .scanDocument: return "\(prefix).scanDocument"
        case .processing(let reason): return "\(prefix).processing:\(reason)"
        case .presenceCheck: return "\(prefix).presenceCheck"
        case .otp: return "\(prefix).otp"
        case .failed: return "\(prefix).failed"
        case .endstate: return "\(prefix).endstate"
        case .success: return "\(prefix).success"
        }
    }
}

extension WDOVerificationState.ProcessingItem {
    static func from(_ reason: VerificationStatus.Reason) -> Self {
        switch reason {
        case .unknown: return .other
        case .documentUpload: return .documentUpload
        case .documentVerification: return .documentVerification
        case .documentAccepted: return .documentAccepted
        case .documentsCrossVerification: return .documentsCrossVerification
        case .clientVerification: return .clientVerification
        case .clientAccepted: return .clientAccepted
        case .verifyingPresence: return .verifyingPresence
        }
    }
}
