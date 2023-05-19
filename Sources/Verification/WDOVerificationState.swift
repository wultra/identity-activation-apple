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

public enum WDOVerificationState: CustomStringConvertible {
    
    public enum AskLaterReason: CustomStringConvertible {
        case unknown
        case documentUpload
        case documentVerification
        case documentAccepted
        case documentsCrossVerification
        case clientVerification
        case clientAccepted
        case verifyingPresence
        
        public var description: String {
            switch self {
            case .unknown: return "unknown"
            case .documentUpload: return "documentUpload"
            case .documentVerification: return "documentVerification"
            case .documentAccepted: return "documentAccepted"
            case .documentsCrossVerification: return "documentsCrossVerification"
            case .clientVerification: return "clientVerification"
            case .clientAccepted: return "clientAccepted"
            case .verifyingPresence: return "verifyingPresence"
                
            }
        }
    }
    
    public enum EndstateReason: CustomStringConvertible {
        case rejected
        case limitReached
        case other
        
        public var description: String {
            switch self {
            case .limitReached: return "limitReached"
            case .other: return "other"
            case .rejected: return "rejected"
            }
        }
    }
    
    case intro
    case consent(_ html: String)
    case documentsToScanSelect
    case scanDocument(_ process: WDOVerificationScanProcess)
    case askLater(_ reason: AskLaterReason)
    case presenceCheck
    case otp
    case failed
    case endstate(_ reason: EndstateReason)
    case success
    
    public var description: String {
        switch self {
        case .intro: return "intro"
        case .consent: return "consent"
        case .documentsToScanSelect: return "documentsToScanSelect"
        case .scanDocument: return "scanDocument"
        case .askLater(let reason): return "askLater:\(reason)"
        case .presenceCheck: return "presenceCheck"
        case .otp: return "otp"
        case .failed: return "failed"
        case .endstate: return "endstate"
        case .success: return "success"
        }
    }
}

extension WDOVerificationState.AskLaterReason {
    static func from(_ reason: VerificationStatus.Reason) -> Self {
        switch reason {
        case .unknown: return .unknown
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
