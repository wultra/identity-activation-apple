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

/// Activation data used in PowerAuth activation process (createActivation method).
public protocol WDOActivationData {
    /// Process ID retrieved from `start` call.
    var processId: String { get }
    /// Attributes needed for the PowerAuth activation.
    func asAttributes() -> [String: String]
}

public extension PowerAuthSDK {
    
    /// Creates powerauth activation based on the data in the WDOActivationData object.
    /// - Parameters:
    ///   - data: Custom activation data
    ///   - name: Name of the activation
    ///   - callback: Result callback
    /// - Throws: Error when activation data cannot be constructed
    /// - Returns: operation task
    @discardableResult
    func createActivation(data: WDOActivationData, name: String, callback: @escaping (Result<PowerAuthActivationResult, Error>) -> Void) throws -> PowerAuthOperationTask? {
        let activation = try PowerAuthActivation(identityAttributes: data.asAttributes(), name: name)
        return createActivation(activation) { result, error in
            if let result = result {
                callback(.success(result))
            } else {
                callback(.failure(error ?? WDOError(message: "Activation failed without result and error.")))
            }
        }
    }
}
