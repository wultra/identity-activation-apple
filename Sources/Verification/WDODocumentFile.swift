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

/// Image that can be send to the backend for Identity Verification
public class WDODocumentFile {
    /// Image to be uploaded.
    public var data: Data
    /// Image signature.
    public var dataSignature: String?
    /// Type of the document
    public let type: WDODocumentType
    /// Side of the document (nil if the document is one-sided or only one side is expected)
    public let side: WDODocumentSide
    /// In case of reupload
    public let originalDocumentId: String?
    
    /// Image that can be send to the backend for Identity Verification
    /// - Parameters:
    ///   - scannedDocument: Document which we're uploading
    ///   - data: Image raw data
    ///   - dataSignature: Signature of the image data. Optinal, `nil` by default
    ///   - side: Side of the document which the image captures
    public convenience init(scannedDocument: WDOScannedDocument, data: Data, dataSignature: String? = nil, side: WDODocumentSide) {
        let originalDocumentId = scannedDocument.serverResult?.first { $0.side == side.apiType }?.id
        self.init(data: data, dataSignature: dataSignature, type: scannedDocument.type, side: side, originalDocumentId: originalDocumentId)
    }
    
    /// Image that can be send to the backend for Identity Verification
    /// - Parameters:
    ///   - data: Image data to be uploaded.
    ///   - dataSignature: Image signature
    ///   - type: Type of the document
    ///   - side: Side of the document (nil if the document is one-sided or only one side is expected)
    ///   - originalDocumentId: Original document ID In case of a reupload
    init(data: Data, dataSignature: String? = nil, type: WDODocumentType, side: WDODocumentSide, originalDocumentId: String? = nil) {
        self.data = data
        self.dataSignature = dataSignature
        self.type = type
        self.side = side
        self.originalDocumentId = originalDocumentId
    }
}

public extension WDOScannedDocument {
    
    /// Creates image that can be send to the backend for Identity Verification
    /// - Parameters:
    ///   - side: Side of the document which the image captures
    ///   - data: Image raw data
    ///   - dataSignature: Signature of the image data. Optinal, `nil` by default
    /// - Returns: Document file for upload
    func createFileForUpload(side: WDODocumentSide, data: Data, dataSignature: String? = nil) -> WDODocumentFile {
        return WDODocumentFile(scannedDocument: self, data: data, dataSignature: dataSignature, side: side)
    }
}

/// Type of the document
public enum WDODocumentType: String {
    /// National ID card
    case idCard
    /// Passport
    case passport
    // Driving license
    case driversLicense
    
    /// Available sides of the document
    public var sides: [WDODocumentSide] {
        switch self {
        case .idCard: return [.front, .back]
        case .passport: return [.front]
        case .driversLicense: return [.front]
        }
    }
}

/// Side of the document
public enum WDODocumentSide: String {
    /// Front side of an document. Usually the one with the picture.
    case front
    /// Back side of an document
    case back
}
