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

public class WDOVerificationScanProcess {
    
    public let documents: [WDOScannedDocument]
    
    public var documentToScan: WDOScannedDocument? { documents.first(where: { $0.serverResult == nil || $0.serverResult!.contains(where: { sr in sr.errors != nil && !sr.errors!.isEmpty }) }) }
    
    init(types: [WDODocumentType]) {
        self.documents = types.map { .init($0) }
    }
    
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
                document.serverResult = group.value
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

public class WDOScannedDocument {
    
    public let type: WDODocumentType
    public var resubmit: Bool { serverResult != nil }
    fileprivate var serverResult: [Document]?
    public var uploadedSides: [UploadedSide] {
        return serverResult?.map { UploadedSide(side: .from(apiType: $0.side), serverId: $0.id)} ?? []
    }
    
    fileprivate init(_ type: WDODocumentType) {
        self.type = type
    }
    
    public struct UploadedSide {
        public let side: WDODocumentSide
        public let serverId: String
    }
}
