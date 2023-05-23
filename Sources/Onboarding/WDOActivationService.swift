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

public class WDOActivationService {
    
    // MARK: - Public Properties
    
    public var hasActiveProcess: Bool { processId != nil }
    
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
    
    public convenience init(powerAuth: PowerAuthSDK, config: WPNConfig, canRestoreSession: Bool = true) throws {
        try self.init(
            networking: WPNNetworkingService(powerAuth: powerAuth, config: config, serviceName: "WDOActivationNetworking"),
            canRestoreSession: canRestoreSession
        )
    }
    
    public convenience init(networking: WPNNetworkingService, canRestoreSession: Bool = true) throws {
        self.init(api: try .init(networking: networking), canRestoreSession: canRestoreSession)
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
    
    public func status(completion: @escaping (Result<Status, WPNError>) -> Void) {
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard let processId else {
                completion(.failure(.init(reason: .wdo_activation_notRunning)))
                return
            }
            guard verifyCanStartProcess(completion) else {
                return
            }
            api.onboarding.getStatus(processId: processId) { result in
                result.onSuccess {
                    completion(.success($0.onboardingStatus.toServiceStatus()))
                }.onError {
                    completion(.failure($0))
                }
            }
        }
    }
    
    public func start<T: Codable>(
        credentials: T,
        completion: @escaping (Result<Void, WPNError>) -> Void
    ) {
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard processId == nil else {
                completion(.failure(.init(reason: .wdo_activation_inProgress)))
                return
            }
            guard verifyCanStartProcess(completion) else {
                return
            }
            api.onboarding.start(with: credentials) { [weak self] result in
                result.onSuccess {
                    self?.processId = $0.processId
                    completion(.success(()))
                }.onError {
                    completion(.failure($0))
                }
            }
        }
    }
    
    public func cancel(
        forceCancel: Bool = true,
        completion: @escaping (Result<Void, WPNError>) -> Void
    ) {
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard let processId else {
                completion(.failure(.init(reason: .wdo_activation_notRunning)))
                return
            }
            guard verifyCanStartProcess(completion) else {
                return
            }
            api.onboarding.cancel(processId: processId) { [weak self]  result in
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
    
    public func clear() {
        oq.addOperation { [weak self] in
            self?.processId = nil
        }
    }
    
    public func resendOTP(completion: @escaping (Result<Void, WPNError>) -> Void) {
        
        serialized(completion) { [weak self] completion in
            guard let self else {
                completion(.failure(.init(reason: .unknown)))
                return
            }
            guard let processId else {
                completion(.failure(.init(reason: .wdo_activation_notRunning)))
                return
            }
            guard verifyCanStartProcess(completion) else {
                return
            }
            api.onboarding.resendOTP(processId: processId) { result in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
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
            guard let processId else {
                completion(.failure(WPNError(reason: .wdo_activation_notRunning)))
                return
            }
            guard api.networking.powerAuth.canStartActivation() else {
                self.processId = nil
                completion(.failure(WPNError(reason: .wdo_activation_cannotActivate)))
                return
            }
            let data = WDOActivationDataWithOTP(processId: processId, otp: otp)
            do {
                try api.networking.powerAuth.createActivation(data: data, name: activationName) { [weak self] result in
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
    
    public enum Status: CustomStringConvertible {
        case activationInProgress
        case verificationInProgress
        case failed
        case finished
        
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
    /// PowerAuth instance cannot start the activation
    static let wdo_activation_cannotActivate = WPNErrorReason(rawValue: "wdo_activation_cannotActivate")
}

public extension WPNError {
    var onboardingOtpRemainingAttempts: Int? {
        (userInfo["PowerAuthErrorInfoKey_AdditionalInfo"] as? NSDictionary)?["remainingAttempts"] as? Int
    }
    
    var allowOnboardingOtpRetry: Bool {
        if let remainingAttempts = onboardingOtpRemainingAttempts {
            return remainingAttempts > 0
        }
        return false
    }
}

// MARK: - Private helper structs and utils

private extension OnboardingStatus {
    func toServiceStatus() -> WDOActivationService.Status {
        switch self {
        case .activationInProgress: return .activationInProgress
        case .verificationInProgress: return .verificationInProgress
        case .failed: return .failed
        case .finished: return .finished
        }
    }
}

// Internal implementation of the default activation data parameters
private struct WDOActivationDataWithOTP: WDOActivationData {
    /// Process ID retrieved from `start` call.
    let processId: String
    /// OTP received via 3rd party chanel.
    let otp: String
    
    /// Creates activation data for identity onboarding with OTP.
    /// - Parameters:
    ///   - processId: Process ID retrieved from `start` call.
    ///   - otp: OTP received via 3rd party chanel.
    init(processId: String, otp: String) {
        self.processId = processId
        self.otp = otp
    }
    
    func asAttributes() -> [String: String] {
        return ["processId": processId, "otpCode": otp, "credentialsType": "ONBOARDING"]
    }
}
