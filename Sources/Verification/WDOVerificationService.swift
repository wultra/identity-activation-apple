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
import PowerAuth2
import WultraPowerAuthNetworking

/// Digital Onboarding Verification Service
///
/// Service that can activate PowerAuthSDK verify instance that was activated but not fully verified.
///
/// This service operations against `enrollment-onboarding-server` and you need to configure networking service with URL of this service.
public class WDOVerificationService {
    
    // MARK: Public Properties
    
    public weak var delegate: WDOVerificationServiceDelegate?
    
    /// Accept language for the outgoing requests headers.
    /// Default value is "en".
    ///
    /// Standard RFC "Accept-Language" https://tools.ietf.org/html/rfc7231#section-5.3.5
    /// Response texts are based on this setting. For example when "de" is set, server
    /// will return error texts and other in german (if available).
    public var acceptLanguage: String {
        get {
            return api.networking.acceptLanguage
        }
        set {
            api.networking.acceptLanguage = newValue
        }
    }
    
    /// Time in seconds that user needs to wait between OTP resend calls
    public var otpResendPeriodInSeconds: Int? {
        guard let period = lastStatus?.config.otpResendPeriod else {
            return nil
        }
        guard let components = ISO8601DurationFormatter().dateComponents(from: period) else {
            return nil
        }
        // we're counting time only
        return (components.second ?? 0) + (60 * (components.minute ?? 0)) + (3600 * (components.hour ?? 0))
    }
    
    // MARK: - Private properties
    
    private let api: Networking
    private let keychainKey: String
    private var cachedProcess: WDOVerificationScanProcess? {
        get {
            if let data = KeychainWrapper.standard.string(forKey: keychainKey) {
                return WDOVerificationScanProcess(cacheData: data)
            } else {
                return nil
            }
        }
        set {
            if let newValue {
                KeychainWrapper.standard.set(newValue.dataForCache(), forKey: keychainKey)
            } else {
                KeychainWrapper.standard.removeObject(forKey: keychainKey)
            }
        }
    }
    
    private var lastStatus: IdentityStatusResponse?
    
    // MARK: - Public initializers
    
    /// Creates service instance
    /// - Parameters:
    ///   - powerAuth: Configured PowerAuthSDK instance. This instance needs to be with valid activation otherwise you'll get errors.
    ///   - config: Configuration of the networking service
    public convenience init(powerAuth: PowerAuthSDK, wpnConfig: WPNConfig) throws {
        try self.init(networking: .init(powerAuth: powerAuth, config: wpnConfig, serviceName: "WDOVerificationNetworking"))
    }
    
    /// Creates service instance
    /// - Parameters:
    ///   - networking: Networking service for the onboarding server with configured PowerAuthSDK instance that needs to be with valid activation otherwise you'll get errors.
    public convenience init(networking: WPNNetworkingService) throws {
        self.init(api: try .init(networking: networking))
        if networking.powerAuth.hasValidActivation() == false {
            cachedProcess = nil
        }
    }
    
    // MARK: - Private initializers
    
    init(api: Networking) {
        self.api = api
        self.keychainKey = "wdocp_\(api.networking.powerAuth.configuration.instanceId)"
    }
    
    // MARK: - Public API
    
    /// Status of the verification.
    /// - Parameter completion: Callback with the result.
    public func status(completion: @escaping (Result<WDOVerificationState, Fail>) -> Void) {
        
        api.identityVerification.getStatus { [weak self] result in
            
            guard let self else {
                return
            }
            
            switch result {
            case .success(let response):
                
                switch response.status {
                case .failed, .rejected, .notInitialized, .accepted:
                    self.cachedProcess = nil
                default:
                    break
                }
                self.lastStatus = response
                
                D.print("Verification status handling. Status \(response.status.rawValue), phase \(response.phase?.rawValue ?? "nil").")
                switch VerificationStatus.from(status: response) {
                case .intro:
                    self.markCompleted(.success(.intro), completion)
                case .documentScan:
                    self.api.identityVerification.documentsStatus(processId: response.processId) { [weak self] docsResult in
                        guard let self else {
                            return
                        }
                        switch docsResult {
                        case .success(let docsResponse):
                            
                            let documents = docsResponse.documents
                            
                            if let cachedProcess = self.cachedProcess {
    
                                cachedProcess.feed(docsResponse.documents)
                                if documents.contains(where: { $0.action == .error }) || documents.contains(where: { $0.errors != nil && !$0.errors!.isEmpty }) {
                                    self.markCompleted(.success(.scanDocument(cachedProcess)), completion)
                                } else if documents.allSatisfy({ $0.action == .proceed }) {
                                    self.markCompleted(.success(.scanDocument(cachedProcess)), completion)
                                } else if documents.contains(where: { $0.action == .wait }) {
                                    // TODO: really verification?
                                    self.markCompleted(.success(.processing(.documentVerification)), completion)
                                } else if documents.isEmpty {
                                    self.markCompleted(.success(.scanDocument(cachedProcess)), completion)
                                } else {
                                    // TODO: is this ok?
                                    self.markCompleted(.success(.failed), completion)
                                }
                            } else {
                                if documents.isEmpty {
                                    self.markCompleted(.success(.documentsToScanSelect), completion)
                                } else {
                                    self.markCompleted(.success(.failed), completion)
                                }
                            }
                            
                        case .failure(let error):
                            self.markCompleted(error, completion)
                        }
                    }
                case .presenceCheck:
                    self.markCompleted(.success(.presenceCheck), completion)
                case .statusCheck(let reason):
                    self.markCompleted(.success(.processing(.from(reason))), completion)
                case .otp:
                    self.markCompleted(.success(.otp(nil)), completion)
                case .failed:
                    self.markCompleted(.success(.failed), completion)
                case .rejected:
                    self.markCompleted(.success(.endstate(.rejected)), completion)
                case .success:
                    self.markCompleted(.success(.success), completion)
                }
            case .failure(let error):
                self.lastStatus = nil
                self.markCompleted(error, completion)
            }
        }
    }
    
    /// Returns consent text for user to approve.
    /// - Parameter completion: Callback with the result.
    public func consentGet(completion: @escaping (Result<Success, Fail>) -> Void) {
        guard let processId = guardProcessId(completion) else {
            return
        }
        api.identityVerification.getConsentText(processId: processId) { [weak self] result in
            guard let self = self else {
                return
            }
            result.onSuccess {
                self.markCompleted(.success(.consent($0)), completion)
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Approves the consent for this process and starts the activation.
    /// - Parameter completion: Callback with the result.
    public func consentApprove(completion: @escaping (Result<Success, Fail>) -> Void) {
        guard let processId = guardProcessId(completion) else {
            return
        }
        api.identityVerification.resolveConsent(processId: processId, approved: true) { [weak self] result in
            guard let self = self else {
                return
            }
            result.onSuccess {
                self.api.identityVerification.start(processId: processId) { [weak self] startResult in
                    guard let self = self else {
                        return
                    }
                    startResult.onSuccess {
                        self.markCompleted(.success(.documentsToScanSelect), completion)
                    }.onError {
                        self.markCompleted($0, completion)
                    }
                }
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Returns a token for the document scanning SDK, when needed.
    /// - Parameters:
    ///   - challenge: SDK generated challenge for the server.
    ///   - completion: Callback with the token for the SDK.
    public func documentsInitSDK(challenge: String, completion: @escaping (Result<String, Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.initScanSDK(processId: processId, challenge: challenge) { [weak self] result in
            guard let self = self else {
                return
            }
            result.onSuccess {
                self.markCompleted(.success($0), completion)
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Set document types to scan.
    /// - Parameters:
    ///   - types: Types of documents to scan.
    ///   - completion: Callback with the result.
    public func documentsSetSelectedTypes(types: [WDODocumentType], completion: @escaping (Result<Success, Fail>) -> Void) {
        // TODO: We should verify that we're in the expected state here
        let process = WDOVerificationScanProcess(types: types)
        cachedProcess = process
        markCompleted(.success(.scanDocument(process)), completion)
    }
    
    /// Upload document files to the server.
    /// - Parameters:
    ///   - files: Document files.
    ///   - progressCallback: Upload progress callback.
    ///   - completion: Callback with the result.
    public func documentsSubmit(files: [WDODocumentFile], progressCallback: @escaping (Double) -> Void, completion: @escaping (Result<Success, Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try DocumentPayloadBuilder.build(processId: processId, files: files)
                self.api.identityVerification.submitDocuments(data: data, progressCallback: progressCallback) { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    result.onSuccess {
                        self.markCompleted(.success(.processing(.documentUpload)), completion)
                    }.onError {
                        self.markCompleted($0, completion)
                    }
                }
            } catch {
                self.markCompleted(.wrap(.unknown, error), completion)
            }
        }
    }
    
    /// Starts presence check. This returns attributes that are needed to start presence check SDK.
    /// - Parameter completion: Callback with the result.
    public func presenceCheckInit(completion: @escaping (Result<[String: Any], Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.presenceCheckInit(processId: processId) { [weak self] result in
            guard let self = self else {
                return
            }
            result.onSuccess {
                self.markCompleted(.success($0.attributes), completion)
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Marks that presence check was performed.
    /// - Parameter completion: Callback with the result.
    public func presenceCheckSubmit(completion: @escaping (Result<Success, Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.presenceCheckSubmit(processId: processId) { [weak self] result in
            guard let self = self else {
                return
            }
            result.onSuccess {
                self.markCompleted(.success(.processing(.verifyingPresence)), completion)
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Restarts verification. When sucessfully called, intro screen should be presented.
    /// - Parameter completion: Callback with the result.
    public func restartVerification(completion: @escaping (Result<Success, Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.cleanup(processId: processId) { [weak self] result in
            guard let self = self else {
                return
            }
            result.onSuccess {
                self.markCompleted(.success(.intro), completion)
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Cancels the whole activation/verification. After this it's no longer call any API endpoint and PowerAuth activation should be removed.
    /// - Parameter completion: Callback with the result.
    public func cancelWholeProcess(completion: @escaping (Result<Void, Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.onboarding.cancel(processId: processId) { [weak self] result in
            guard let self = self else {
                return
            }
            result.onSuccess {
                self.markCompleted(.success(()), completion)
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Verify OTP that user entered as a last step of the verification.
    /// - Parameters:
    ///   - otp: User entered OTP.
    ///   - completion: Callback with the result.
    public func verifyOTP(otp: String, completion: @escaping (Result<Success, Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.verifyOTP(processId: processId, otp: otp) { [weak self] result in
            
            guard let self = self else {
                return
            }
            
            result.onSuccess { data in
                if data.verified {
                    self.markCompleted(.success(.processing(.other)), completion)
                } else {
                    if data.remainingAttempts > 0 && data.expired == false {
                        self.markCompleted(.success(.otp(data.remainingAttempts)), completion)
                    } else {
                        self.markCompleted(.failure(.init(.init(reason: .wdo_verification_otpFailed))), completion)
                    }
                }
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Requests OTP resend.
    /// - Parameter completion: Callback with the result.
    public func resendOTP(completion: @escaping (Result<Void, Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.resendOTP(processId: processId) { result in
            result.onSuccess {
                self.markCompleted(.success(()), completion)
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    
    #if ENABLE_ONBOARDING_DEMO
    /// Demo endpoint available only in Wultra Demo systems.
    /// - Parameter completion: Callback with the result.
    public func getOTP(completion: @escaping (Result<String, Fail>) -> Void) {
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.onboarding.getOTP(processId: processId, type: .userVerification) { result in
            result.onSuccess {
                self.markCompleted(.success($0), completion)
            }.onError {
                self.markCompleted($0, completion)
            }
        }
    }
    #endif
    
    // MARK: Public Helper Classes
    
    /// Success result with next state that should be presented
    public class Success {
        
        init(_ state: WDOVerificationState) {
            self.state = state
        }
        
        /// State of the verification for app to display
        public let state: WDOVerificationState
    }
    
    /// Error result with cause of the error and state that should be presented (optional).
    ///
    /// Note that state will be filled only when the error indicates state change.
    public class Fail: Error {
        
        /// Cause of the error.
        public let cause: WPNError
        /// State of the verification for app to display
        public let state: WDOVerificationState?
        
        init(_ cause: WPNError) {
            self.cause = cause
            switch cause.restApiError?.errorCode {
            case .onboardingFailed:
                state = .endstate(.other)
            case .identityVerificationFailed:
                state = .failed
            case .onboardingLimitReached:
                state = .endstate(.limitReached)
            case .presenceCheckLimitEached, .identityVerificationLimitReached:
                state = .failed
            default:
                state = nil
            }
        }
    }
    
    // MARK: - Private helper methods
    
    private func guardProcessId<T>(_ completion: (Result<T, Fail>) -> Void) -> String? {
        guard let processId = lastStatus?.processId else {
            markCompleted(.failure(.init(.init(reason: .wdo_verification_missingStatus))), completion)
            return nil
        }
        return processId
    }
    
    private func markCompleted<T>(_ error: WPNError, _ completion: @escaping (Result<T, Fail>) -> Void) {
        if error.networkIsNotReachable == false || error.restApiError?.errorCode == .authenticationFailure {
            api.networking.powerAuth.fetchActivationStatus { [weak self] status, _ in
                
                guard let self else {
                    return
                }
                
                if let status, status.state != .active {
                    self.delegate?.powerAuthActivationStatusChanged(self, status: status)
                    self.markCompleted(.failure(.init(.init(reason: .wdo_verification_activationNotActive, error: error))), completion)
                } else {
                    self.markCompleted(.failure(.init(error)), completion)
                }
            }
        } else {
            markCompleted(.failure(.init(error)), completion)
        }
    }
    
    private func markCompleted<T>(_ result: Result<T, Fail>, _ completion: (Result<T, Fail>) -> Void) {
        if let state = (result.success as? Success)?.state ?? result.error?.state {
            delegate?.verificationStatusChanged(self, status: state)
        }
        completion(result)
    }
}

// MARK: - Other public APIs

/// Delegate of the Onboarding Verification Service that can listen on Verification Status and PowerAuth Status changes.
public protocol WDOVerificationServiceDelegate: AnyObject {
    /// Called when PowerAuth activation status changed.
    ///
    /// Note that this happens only when error is returned in some of the Verification endpoints and this error indicates PowerAuth status change.
    func powerAuthActivationStatusChanged(_ sender: WDOVerificationService, status: PowerAuthActivationStatus)
    
    /// Called when state of the verification has changed.
    func verificationStatusChanged(_ sender: WDOVerificationService, status: WDOVerificationState)
}

public extension WPNErrorReason {
    /// Powerauth instance is not active.
    static let wdo_verification_activationNotActive = WPNErrorReason(rawValue: "wdo_verification_activationNotActive")
    /// Wultra Digital Onboarding verificaiton status is unknown. Please make sure that the status was sucessfully fetched before calling any other method
    static let wdo_verification_missingStatus = WPNErrorReason(rawValue: "wdo_verification_missingStatus")
    /// Wultra Digital Onboarding OTP failed to verify.
    static let wdo_verification_otpFailed = WPNErrorReason(rawValue: "wdo_verification_otpFailed")
}

// MARK: - Private extensions and other

private extension Result where Success == WDOVerificationService.Success, Failure == WDOVerificationService.Fail {
    static func success(_ nextStep: WDOVerificationState) -> Self {
        return .success(WDOVerificationService.Success(nextStep))
    }
}

// Internal status that works as a translation layer between server API and SDK API
enum VerificationStatus {
    
    enum Reason {
        case unknown
        case documentUpload
        case documentVerification
        case documentAccepted
        case documentsCrossVerification
        case clientVerification
        case clientAccepted
        case verifyingPresence
    }
    
    case intro
    case documentScan
    case statusCheck(_ reason: Reason)
    case presenceCheck
    case otp
    case failed
    case rejected
    case success
    
    static func from(status response: IdentityStatusResponse) -> VerificationStatus {
        switch (response.phase, response.status) {
        case (nil, .notInitialized):                    return .intro
        case (nil, .failed):                            return .failed
        case (.documentUpload, .inProgress):            return .documentScan
        case (.documentUpload, .verificationPending):   return .statusCheck(.documentVerification)
        case (.documentUpload, .failed):                return .failed
        case (.documentVerification, .accepted):        return .statusCheck(.documentAccepted)
        case (.documentVerification, .inProgress):      return .statusCheck(.documentVerification)
        case (.documentVerification, .failed):          return .failed
        case (.documentVerification, .rejected):        return .rejected
        case (.documentVerificationFinal, .accepted):   return .statusCheck(.documentsCrossVerification)
        case (.documentVerificationFinal, .inProgress): return .statusCheck(.documentsCrossVerification)
        case (.documentVerificationFinal, .failed):     return .failed
        case (.documentVerificationFinal, .rejected):   return .rejected
        case (.clientEvaluation, .inProgress):          return .statusCheck(.clientVerification)
        case (.clientEvaluation, .accepted):            return .statusCheck(.clientAccepted)
        case (.clientEvaluation, .rejected):            return .rejected
        case (.clientEvaluation, .failed):              return .failed
        case (.presenceCheck, .notInitialized):         return .presenceCheck
        case (.presenceCheck, .inProgress):             return .presenceCheck
        case (.presenceCheck, .verificationPending):    return .statusCheck(.verifyingPresence)
        case (.presenceCheck, .failed):                 return .failed
        case (.presenceCheck, .rejected):               return .rejected
        case (.otp, .verificationPending):              return .otp
        case (.completed, .accepted):                   return .success
        case (.completed, .failed):                     return .failed
        case (.completed, .rejected):                   return .rejected
        default: D.fatalError("Unknown phase/status combo: \(response.phase?.rawValue ?? "nil"), \(response.status.rawValue)")
        }
    }
}
