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

/// Class that provides all functionality for both Identity Onboarding and Identity Verification.
/// Both features are separated into `onboarding` and `identityVerification` properties.
class Networking {
    
    /// Errors during init
    enum InitError: Error {
        /// Provided URL is invalid (see `url` associated value)
        case invalidBaseURL(url: String)
    }
    
    /// All necessary communication for Identity Onboarding (PowerAuth activation via user information such as client id and birthdate).
    let onboarding: Onboarding
    /// All necessary communication for Identity Verification (After PowerAuth was enrolled with verification pending)
    let identityVerification: IdentityVerification
    /// Networking service for HTTP communication and request signing.
    let networking: WPNNetworkingService
    
    /// Creates the service instance.
    /// - Parameters:
    ///   - powerAuth: Valid powerauth instance.
    ///   - config: Configuration of the service. Default values are used when not specified (see config init documentation).
    convenience init(powerAuth: PowerAuthSDK, config: WPNConfig) throws {
        self.init(networking: WPNNetworkingService(powerAuth: powerAuth, config: config, serviceName: "WDOServiceNet"))
    }
    
    /// Creates the service instance.
    /// - Parameter networking: Networking service for HTTP communication and request signing.
    init(networking: WPNNetworkingService) {
        self.networking = networking
        self.onboarding = Onboarding(networking: networking)
        self.identityVerification = IdentityVerification(networking: networking)
    }
    
    /// Class that provides all necessary communication for Identity Onboarding (PowerAuth activation via user information such as client id and birthdate).
    class Onboarding {
        
        fileprivate let powerAuth: PowerAuthSDK
        fileprivate let networking: WPNNetworkingService
        
        init(networking: WPNNetworkingService) {
            self.powerAuth = networking.powerAuth
            self.networking = networking
        }
        
        /// Starts the Identity Onboarding process.
        ///
        /// Encrypted with the ECIES application scope.
        /// - Parameters:
        ///   - credentials: Custom credentials object for user authentication.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe
        @discardableResult
        func start<TCreds: Codable>(with credentials: TCreds, completion: @escaping (Result<ProcessResponse, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Onboarding.Start<TCreds>
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(identification: credentials)),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if let data = result?.responseObject {
                        completion(.success(data))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Cancel the Identity Onboarding process.
        ///
        /// Encrypted with the ECIES application scope.
        /// - Parameters:
        ///   - processId: ID of the Identity Onboarding process
        ///   - completion: Result completion.
        /// - Returns: Operation to observe
        @discardableResult
        func cancel(processId: String, completion: @escaping (Result<Void, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Onboarding.Cancel
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                to: Endpoint.endpoint,
                completion: { (result: WPNResponseBase?, error: WPNError?) in
                    assert(Thread.isMainThread)
                    if result?.status == .Ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Retrieves status of the Identity Onboarding.
        ///
        /// Encrypted with the ECIES application scope.
        /// - Parameters:
        ///   - processId: ID of the Identity Onboarding process
        ///   - completion: Result completion.
        /// - Returns: Operation to observe
        @discardableResult
        func getStatus(processId: String, completion: @escaping (Result<ProcessResponse, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Onboarding.GetStatus
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if let data = result?.responseObject {
                        completion(.success(data))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Resends the OTP for users convenience (for example when SMS was not received by the user).
        ///
        /// Note that there will be some frequency limit implemented by the server. Default is 30 seconds
        /// but we advise to consult this with the backend developers.
        ///
        /// Encrypted with the ECIES application scope.
        ///
        /// - Parameters:
        ///   - processId: ID of the Identity Onboarding process
        ///   - completion: Result completion.
        /// - Returns: Operation to observe
        @discardableResult
        func resendOTP(processId: String, completion: @escaping (Result<Void, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Onboarding.ResendOTP
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                to: Endpoint.endpoint,
                completion: { (result: WPNResponseBase?, error: WPNError?) in
                    assert(Thread.isMainThread)
                    if result?.status == .Ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
    }
    
    /// Class for all necessary communication for Identity Verification (After PowerAuth was enrolled with verification pending)
    class IdentityVerification {
        
        private let powerAuth: PowerAuthSDK
        private let networking: WPNNetworkingService
        
        init(networking: WPNNetworkingService) {
            self.powerAuth = networking.powerAuth
            self.networking = networking
        }
        
        /// Retrieves status of the Identity Verification status.
        ///
        /// - Parameter completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func getStatus(completion: @escaping (Result<IdentityStatusResponse, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.GetStatus
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init()),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if let data = result?.responseObject {
                        completion(.success(data))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Starts Identity Verification process.
        ///
        /// - Parameters:
        ///   - processId: ID of the process
        ///   - completion: Result completion.
        /// - Returns: Operation to observe
        @discardableResult
        func start(processId: String, completion: @escaping (Result<Void, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.Init
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { (result: WPNResponseBase?, error: WPNError?) in
                    assert(Thread.isMainThread)
                    if result?.status == .Ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Cancel and clean the current verification process. Acts as a "reset".
        ///
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe
        @discardableResult
        func cleanup(processId: String, completion: @escaping (Result<Void, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.Cancel
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if result?.status == .Ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Retrieves a consent text (usually HTML) for user to approve/reject.
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func getConsentText(processId: String, completion: @escaping (Result<String, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.ConsentText
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if let data = result?.responseObject {
                        completion(.success(data.consentText))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Approves or rejects privacy consent.
        ///
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - approved: If the user approved the consent.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func resolveConsent(processId: String, approved: Bool, completion: @escaping (Result<Void, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.ConsentApprove
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId, approved: approved)),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if result?.status == .Ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Provides necessary data to init scan SDK (like ZenID).
        ///
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - challenge: Challenge that the SDK provided.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func initScanSDK(processId: String, challenge: String, completion: @escaping (Result<String, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.DocumentScanSdkInit
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId, attributes: .init(challengeToken: challenge))),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { (result: WPNResponse<SDKInitResponse>?, error: WPNError?) in
                    assert(Thread.isMainThread)
                    if let token = result?.responseObject?.attributes.responseToken {
                        completion(.success(token))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Submits documents necessary for identity verification (like photos of ID or passport).
        ///
        /// Encrypted with the ECIES activation scope.
        /// - Parameters:
        ///   - data: Data to be send.
        ///           You can use `WDODocumentPayloadBuilder.build` for easier use.
        ///   - progressCallback: Progress callback during upload.
        ///   - completion: Result completion..
        /// - Returns: Operation to observe.
        @discardableResult
        func submitDocuments(data: DocumentSubmitRequest, progressCallback: ((Double) -> Void)? = nil, completion: @escaping (Result<Void, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.SubmitDocuments
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(data),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                timeoutInterval: 180,
                progressCallback: progressCallback,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if result?.status == .Ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Asks for status of already uploaded documents.
        ///
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func documentsStatus(processId: String, completion: @escaping (Result<DocumentStatusResponse, WPNError>) -> Void) -> Operation? {

            typealias Endpoint = Endpoints.Identification.DocumentsStatus

            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                timeoutInterval: 120,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if let data = result?.responseObject {
                        completion(.success(data))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Starts presence check process (that user is actually physically present).
        ///
        /// Encrypted with the ECIES activation scope.
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func presenceCheckInit(processId: String, completion: @escaping (Result<PresenceCheckInitResponse, WPNError>) -> Void) -> Operation? {

            typealias Endpoint = Endpoints.Identification.PresenceCheckInit
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if let data = result?.responseObject {
                        completion(.success(data))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// Confirms presence check is done on the device.
        ///
        /// Signed with PowerAuth possession factor.
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func presenceCheckSubmit(processId: String, completion: @escaping (Result<Void, WPNError>) -> Void) -> Operation? {

            typealias Endpoint = Endpoints.Identification.PresenceCheckSubmit
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if result?.status == .Ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// OTP resend  in case that the user didn't received it.
        ///
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func resendOTP(processId: String, completion: @escaping (Result<Void, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.ResendOTP
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId)),
                signedWith: .possession(),
                to: Endpoint.endpoint,
                completion: { (result: WPNResponseBase?, error: WPNError?) in
                    assert(Thread.isMainThread)
                    if result?.status == .Ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
        
        /// OTP verification during identification of the user.
        ///
        /// - Parameters:
        ///   - processId: ID of the process.
        ///   - otp: OTP that user received.
        ///   - completion: Result completion.
        /// - Returns: Operation to observe.
        @discardableResult
        func verifyOTP(processId: String, otp: String, completion: @escaping (Result<VerifyOTPResponse, WPNError>) -> Void) -> Operation? {
            
            typealias Endpoint = Endpoints.Identification.VerifyOTP
            
            return networking.post(
                data: Endpoint.EndpointType.RequestData(.init(processId: processId, otpCode: otp)),
                to: Endpoint.endpoint,
                completion: { result, error in
                    assert(Thread.isMainThread)
                    if let data = result?.responseObject {
                        completion(.success(data))
                    } else {
                        completion(.failure(error ?? WPNError(reason: .unknown)))
                    }
                }
            )
        }
    }
}

#if ENABLE_ONBOARDING_DEMO
extension Networking.Onboarding {
    
    /// Retrieves OTP needed for Onboarding Process.
    ///
    /// Note that this method is available only in demo Wultra implementation.
    /// Encrypted with the ECIES activation scope.
    /// - Parameters:
    ///   - processId: ID of the onboarding process
    ///   - completion: Result completion.
    /// - Returns: Operation to observe
    @discardableResult
    func getOTP(processId: String, type: OTPDetailType, completion: @escaping (Result<String, WPNError>) -> Void) -> Operation? {
        
        typealias Endpoint = Endpoints.GetOTP
        
        return networking.post(
            data: Endpoint.EndpointType.RequestData(.init(processId: processId, otpType: type)),
            to: Endpoint.endpoint,
            completion: { result, error in
                assert(Thread.isMainThread)
                if let data = result?.responseObject {
                    completion(.success(data.otpCode))
                } else {
                    completion(.failure(error ?? WPNError(reason: .unknown)))
                }
            }
        )
    }
}
#endif
