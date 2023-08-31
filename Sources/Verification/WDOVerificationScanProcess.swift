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

import UIKit

/// Verification Scan Process that describes which documents needs to be scanned and uploaded
public class WDOVerificationScanProcess {
    
    /// Documents that needs to be scanned
    public let documents: [WDOScannedDocument]
    
    /// Which document should be scanned next. `nil` when all documents are uploaded and accepted
    public var nextDocumentToScan: WDOScannedDocument? { documents.first { $0.uploadState != .accepted }}
    
    // internal init
    internal init(types: [WDODocumentType]) {
        self.documents = types.map { .init($0) }
    }
}

/// Document that needs to be scanned during process
public class WDOScannedDocument {
    
    /// State of the document on the server
    public enum UploadState {
        /// Document was not uploaded yet
        case notUploaded
        /// Document was accepted
        case accepted
        /// Document was rejected and needs to be reuploaded
        case rejected
    }
    
    /// Side of an uploaded document
    public struct Side {
        /// Type of the side
        public let type: WDODocumentSide
        /// ID on the server. Use this ID in case of an reupload
        public let serverId: String
        /// Upload state of the document
        public let uploadState: UploadState
    }
    
    /// Type of the document
    public let type: WDODocumentType
    
    /// Upload state
    public var uploadState: UploadState {
        // if there are no sides, consider the document not uploaded
        guard !sides.isEmpty else {
            return .notUploaded
        }
        // if any side is rejected, consider whole document rejected
        return sides.contains { $0.uploadState == .rejected } ? .rejected : .accepted
    }
    
    /// Sides of the document that was uploaded on the server
    public private(set) var sides: [Side] = []
    
    fileprivate init(_ type: WDODocumentType) {
        self.type = type
    }
    
    fileprivate func processServerData(documents: [Document]) {
        sides = documents.map { .init(type: .from(apiType: $0.side), serverId: $0.id, uploadState: $0.errors?.isEmpty == false ? .rejected : .accepted )}
    }
}

// MARK: - Internal/Private

extension WDOVerificationScanProcess {
    
    convenience init?(cacheData: String) {
        let split = cacheData.split(separator: ":").map { String($0) }
        guard split.count == 2 else {
            D.error("Cannot create scan process from cache - unknown cache format")
            return nil
        }
        
        guard let version = CacheVersion(rawValue: split[0]), version == .v1 else {
            D.error("Cannot create scan process from cache - unknown cache version")
            return nil
        }
        
        let types = split[1].split(separator: ",").compactMap { WDODocumentType(rawValue: String($0)) }
        
        // TODO: removed for now
//        guard types.count == numberOfRequiredDocuments else {
//            D.error("Cannot create scan process from cache - wrong number of documents")
//            return nil
//        }
        
        self.init(types: types)
    }
    
    func feed(_ serverData: [Document]) {
        for group in Dictionary(grouping: serverData, by: { $0.type }) {
            if let document = documents.first(where: { $0.type.apiType == group.key }) {
                document.processServerData(documents: group.value)
            }
        }
    }
    
    private enum CacheVersion: String {
        case v1
    }
    
    func dataForCache() -> String {
        return "\(CacheVersion.v1.rawValue):\(documents.map { $0.type.rawValue }.joined(separator: ","))"
    }
}
