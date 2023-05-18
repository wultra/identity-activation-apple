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

/// Request builder of the `submitDocuments` API call.
class DocumentPayloadBuilder {
    
    /// Builds the request for the `submitDocuments` call.
    /// - Parameters:
    ///   - processId: ID of the process
    ///   - files: Documents to upload
    /// - Returns: Request
    /// - Throws: Various errors during the document processing.
     static func build(processId: String, files: [WDODocumentFile]) throws -> DocumentSubmitRequest {
        
        // create temporary folder that will be zipped
        let folderName = UUID().uuidString
        let tmpd = FileManager.default.temporaryDirectory.appendingPathComponent(folderName)
        
        defer {
            // remove the folder after finished
            try? FileManager.default.removeItem(at: tmpd)
        }
        
        do {
            try FileManager.default.createDirectory(at: tmpd, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw WDOError(message: "Failed to create temporary directory.")
        }
        
        // store each image as binary data to the temp folder
        for file in files {
            try file.data.write(to: tmpd.appendingPathComponent(file.filename))
        }
        
        var error: NSError? // error of the zip process
        var zipData: Data? // zipped data
        
        // zip temporary folder. This will result in a zip with the folder. Zipping just the contents of the
        // folder is not supported in the iOS SDK and we would need to bring in dependency or write it from scratch.
        NSFileCoordinator().coordinate(readingItemAt: tmpd, options: [.forUploading], error: &error) { zipUrl in
            // store zip data (after the closure is finished, zip file on the path is removed)
            zipData = FileManager.default.contents(atPath: zipUrl.path)
        }
        
        guard let zipData = zipData else {
            throw WDOError(message: "Failed to create zip file: \(error?.localizedDescription ?? "unknown error").")
        }
        
        D.print("Created zip file of size \(round((Double(zipData.count)/1024.0/1024.0) * 100) / 100)mb.")
        
        return DocumentSubmitRequest(
            processId: processId,
            data: zipData.base64EncodedString(), // be aware this can create huge base64 data
            resubmit: files.contains { $0.originalDocumentId != nil },
            documents: files.map { $0.getMetaData(inFolder: folderName) }
        )
    }
}

extension WDODocumentFile: Hashable {
    
    fileprivate func getMetaData(inFolder folder: String) -> DocumentSubmitFile {
        return DocumentSubmitFile(filename: "\(folder)/\(filename)", type: type.apiType, side: side.apiType, originalDocumentId: originalDocumentId)
    }
    
    /// We expect only one document per type(+side) in the final payload
    /// so the name is result of such setup.
    fileprivate var filename: String { "\(type.rawValue.lowercased())_\(side.rawValue.lowercased()).jpg" }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(filename)
    }
    
    public static func == (lhs: WDODocumentFile, rhs: WDODocumentFile) -> Bool {
        return lhs.filename == rhs.filename
    }
}

extension WDODocumentType {
    var apiType: DocumentSubmitFileType {
        switch self {
        case .idCard: return .idCard
        case .passport: return .passport
        case .driversLicense: return .driversLicense
        }
    }
}

extension WDODocumentSide {
    var apiType: DocumentSubmitFileSide {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
    
    static func from(apiType: DocumentSubmitFileSide) -> Self {
        switch apiType {
        case .front: return .front
        case .back: return .back
        }
    }
}
