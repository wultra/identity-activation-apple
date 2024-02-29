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
import UIKit
import PowerAuth2
import WultraPowerAuthNetworking

/// Service that can activate PowerAuthSDK instance by user weak credentials (like his email, phone number or client ID) + SMS OTP.
///
/// When the PowerAuthSDK is activated with this service, `PowerAuthActivationStatus.needVerification` will be `true`
/// and you will need to verify the PowerAuthSDK instance via `WDOVerificationService`.
///
/// This service operates against Wultra Onboarding server (usually ending with `/enrollment-onboarding-server`) and you need to configure networking service with the right URL.
public class WDOActivationService {
    
    // MARK: - Public Properties
    
    /// If the activation process is in progress.
    ///
    /// Note that even if this property is `true` it can be already discontinued on the server.
    /// Calling `status(completion:)` for example after the app is launched in this case is recommended.
    public var hasActiveProcess: Bool { processId != nil }
    
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
    
    // MARK: - Private properties
    
    private var processId: String? {
        get {
            return KeychainWrapper.standard.string(forKey: keychainKey)
        }
        set {
            if let newValue {
                KeychainWrapper.standard.set(newValue, forKey: keychainKey)
            } else {
                KeychainWrapper.standard.removeObject(forKey: keychainKey)
            }
        }
    }
    
    // MARK: - Dependencies and constants
    
    private let api: Networking
    private let keychainKey: String
    private let oq: OperationQueue = {
        let q = OperationQueue()
        q.name = "WDOOnboardingQueue"
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    // MARK: - Public initializers
    
    /// Creates service instance
    /// - Parameters:
    ///   - powerAuth: Configured PowerAuthSDK instance. This instance needs to be without valid activation.
    ///   - config: Configuration for the networking.
    ///   - canRestoreSession: If the activation session can be restored (when app restarts). `true` by default.
    public convenience init(powerAuth: PowerAuthSDK, config: WPNConfig, canRestoreSession: Bool = true) {
        self.init(
            networking: WPNNetworkingService(powerAuth: powerAuth, config: config, serviceName: "WDOActivationNetworking"),
            canRestoreSession: canRestoreSession
        )
    }
    
    /// Creates service instance
    /// - Parameters:
    ///   - networking: Networking service for the onboarding server with configured PowerAuthSDK instance that needs to be without valid activation.
    ///   - canRestoreSession: If the activation session can be restored (when app restarts). `true` by default.
    public convenience init(networking: WPNNetworkingService, canRestoreSession: Bool = true) {
        self.init(api: .init(networking: networking), canRestoreSession: canRestoreSession)
    }
    
    // MARK: - Internal initializers
    
    init(api: Networking, canRestoreSession: Bool) {
        self.api = api
        self.keychainKey = "wdopid_\(api.networking.powerAuth.configuration.instanceId)"
        if canRestoreSession == false {
            processId = nil
        }
    }
    
    // MARK: - Public API
    
    /// Retrieves status of the onboarding activation.
    ///
    /// - Parameter completion: Callback with the result.
    public func status(completion: @escaping (Result<Status, WPNError>) -> Void) {
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard let processId = self.processId else {
                completion(.failure(.init(reason: .wdo_activation_notRunning)))
                return
            }
            guard self.verifyCanStartProcess(completion) else {
                return
            }
            self.api.onboarding.getStatus(processId: processId) { result in
                result.onSuccess {
                    let status: Status = switch $0.onboardingStatus {
                    case .activationInProgress: .activationInProgress
                    case .verificationInProgress: .verificationInProgress
                    case .failed: .failed
                    case .finished: .finished
                    }
                    completion(.success(status))
                }.onError {
                    completion(.failure($0))
                }
            }
        }
    }
    
    /// Start onboarding activation with user credentials.
    ///
    /// For example, when you require email and birth date, your struct would look like this:
    /// ```
    /// struct Credentials: Codable {
    ///     let email: String
    ///     let birthdate: String
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - credentials: Codable object with credentials. Which credentials are needed should be provided by a system/backend provider.
    ///   - completion: Callback with the result.
    public func start<T: Codable>(
        credentials: T,
        completion: @escaping (Result<Void, WPNError>) -> Void
    ) {
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard self.processId == nil else {
                completion(.failure(.init(reason: .wdo_activation_inProgress)))
                return
            }
            guard self.verifyCanStartProcess(completion) else {
                return
            }
            self.api.onboarding.start(with: credentials) { [weak self] result in
                result.onSuccess {
                    self?.processId = $0.processId
                    completion(.success(()))
                }.onError {
                    completion(.failure($0))
                }
            }
        }
    }
    
    /// Cancel the activation process.
    ///
    /// - Parameters:
    ///   - forceCancel: When true, the process will be canceled in the SDK even when fails on backend. `true` by default.
    ///   - completion: Callback with the result.
    public func cancel(
        forceCancel: Bool = true,
        completion: @escaping (Result<Void, WPNError>) -> Void
    ) {
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard let processId = self.processId else {
                completion(.failure(.init(reason: .wdo_activation_notRunning)))
                return
            }
            guard self.verifyCanStartProcess(completion) else {
                return
            }
            self.api.onboarding.cancel(processId: processId) { [weak self]  result in
                result.onSuccess {
                    self?.processId = nil
                    completion(.success(()))
                }.onError { error in
                    if forceCancel {
                        self?.processId = nil
                        completion(.success(()))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// Clear the stored data (without networking call).
    public func clear() {
        oq.addOperation { [weak self] in
            self?.processId = nil
        }
    }
    
    /// OTP resend request.
    ///
    /// This is intended to be displayed for the user to use in case of the OTP is not recieved.
    /// For example, when the user does not recieve SMS after some time, there should be a button to "send again".
    ///
    /// - Parameter completion: Callback with the result.
    public func resendOTP(completion: @escaping (Result<Void, WPNError>) -> Void) {
        
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard let processId = self.processId else {
                completion(.failure(.init(reason: .wdo_activation_notRunning)))
                return
            }
            guard self.verifyCanStartProcess(completion) else {
                return
            }
            self.api.onboarding.resendOTP(processId: processId) { result in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Activate the PowerAuthSDK instance that was passed in the initializer.
    ///
    /// - Parameters:
    ///   - otp: OTP provided by user.
    ///   - activationName: Name of the activation. Device name by default (usually something like John's iPhone or similar).
    ///   - completion: Callback with the result.
    public func activate(
        otp: String,
        activationName: String = UIDevice.current.name,
        completion: @escaping (Result<PowerAuthActivationResult, WPNError>) -> Void
    ) {
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard let processId = self.processId else {
                completion(.failure(WPNError(reason: .wdo_activation_notRunning)))
                return
            }
            guard self.api.networking.powerAuth.canStartActivation() else {
                self.processId = nil
                completion(.failure(WPNError(reason: .wdo_activation_cannotActivate)))
                return
            }
            let data = WDOActivationDataWithOTP(processId: processId, otp: otp)
            do {
                try self.api.networking.powerAuth.createActivation(data: data, name: activationName) { [weak self] result in
                    result.onSuccess {
                        self?.processId = nil
                        completion(.success($0))
                    }.onError {
                        let error = WPNError(reason: .unknown, error: $0)
                        // when no longer possible to retry activation and the error is not "connection" issue
                        // reset the processID, because we cannot recover
                        if error.allowOnboardingOtpRetry == false && error.networkIsNotReachable == false {
                            self?.processId = nil
                        }
                        completion(.failure(error))
                    }
                }
            } catch let e {
                completion(.failure(.wrap(.unknown, e)))
            }
        }
    }
    
    #if ENABLE_ONBOARDING_DEMO
    /// Demo endpoint available only in Wultra Demo systems
    ///
    /// If the app is running against our demo server, you can retrieve the OTP without needing to send SMS or emails.
    ///
    /// - Parameter completion: Callback with the result.
    public func getOTP(completion: @escaping (Result<String, WPNError>) -> Void) {
        guard let processId else {
            completion(.failure(WPNError(reason: .wdo_activation_notRunning)))
            return
        }
        api.onboarding.getOTP(processId: processId, type: .activation) { result in
            switch result {
            case .success(let otp):
                completion(.success(otp))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    #endif
    
    private func serialized<T, E: Error>(_ originalCompletion: @escaping (Result<T, E>) -> Void, block: @escaping (_ completion: @escaping (Result<T, E>) -> Void) -> Void) {
        oq.addAsyncOperation(.main) { _, markFinished in
            block { result in
                markFinished {
                    originalCompletion(result)
                }
            }
        }
    }
    
    private func verifyCanStartProcess<T>(_ completion: @escaping (Result<T, WPNError>) -> Void) -> Bool {
            
        guard api.networking.powerAuth.canStartActivation() else {
            self.processId = nil
            completion(.failure(.wrap(.wdo_activation_cannotActivate)))
            return false
        }
        return true
    }
    
    // MARK: - Status Enum
    
    /// Status of the Onboarding Activation
    public enum Status: CustomStringConvertible {
        /// Activation is in progress. Continue with the `activate()`.
        case activationInProgress
        /// Activation was already finished, now waiting for the user verification. Use `WDOVerificationService` to fully activate the PowerAuthSDK instance.
        case verificationInProgress
        /// Activation failed, start over.
        case failed
        /// Both activation and verification were finished and the user was fully activated.
        case finished
        
        /// Description of the status.
        public var description: String {
            let prefix = "WDOOnboardingService.Status"
            switch self {
            case .activationInProgress: return "\(prefix).activationInProgress"
            case .verificationInProgress: return "\(prefix).verificationInProgress"
            case .failed: return "\(prefix).failed"
            case .finished: return "\(prefix).finished"
            }
        }
    }
}

// MARK: - Public extensions for customer usage

public extension WPNErrorReason {
    /// Wultra Digital Onboarding activation is already in progress.
    static let wdo_activation_inProgress = WPNErrorReason(rawValue: "wdo_activation_inProgress")
    /// Wultra Digital Onboarding activation was not started.
    static let wdo_activation_notRunning = WPNErrorReason(rawValue: "wdo_activation_notRunning")
    /// PowerAuth instance cannot start the activation (probably already activated).
    static let wdo_activation_cannotActivate = WPNErrorReason(rawValue: "wdo_activation_cannotActivate")
}

public extension WPNError {
    
    /// When users enters wrong OTP during Onboarding Activation process, the error contains additional remaining attempts.
    var onboardingOtpRemainingAttempts: Int? {
        (userInfo["PowerAuthErrorInfoKey_AdditionalInfo"] as? NSDictionary)?["remainingAttempts"] as? Int
    }
    
    /// If user should be allowed to repeat Onboarding Activation OTP step.
    ///
    /// There are limited amount of OTPs that user can try. After that, the process should be canceled and started again.
    var allowOnboardingOtpRetry: Bool {
        if let remainingAttempts = onboardingOtpRemainingAttempts {
            return remainingAttempts > 0
        }
        return false
    }
}

// MARK: - Private helper structs and utils

// Internal implementation of the default activation data parameters
private struct WDOActivationDataWithOTP: WDOActivationData {
    /// Process ID retrieved from `start` call.
    let processId: String
    /// OTP received via 3rd party chanel.
    let otp: String
    
    func asAttributes() -> [String: String] {
        return ["processId": processId, "otpCode": otp, "credentialsType": "ONBOARDING"]
    }
}

struct UserData: Codable {
    let userID: String
    let birthDate: String
}
