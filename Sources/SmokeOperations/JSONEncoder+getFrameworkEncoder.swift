// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// JSONEncoder+getFrameworkEncoder.swift
// SwiftOperations
//

import Foundation
import LoggerAPI

private func createEncoder() -> JSONEncoder {
    let jsonEncoder = JSONEncoder()
    
#if os(iOS)
    if #available(iOS 10.0, *) {
        jsonEncoder.dateDecodingStrategy = .iso8601
    } else {
        // Fallback on earlier versions for iOS
    }
#elseif os(macOS)
    if #available(macOS 10.12, *) {
        jsonEncoder.dateDecodingStrategy = .iso8601
    } else {
        // Fallback on earlier versions for macOS
    }
#else
    // Handle other platforms if needed
#endif

    jsonEncoder.outputFormatting = .prettyPrinted
    
    return jsonEncoder
}

// swiftlint:disable force_try
// If all else fails, an error payload to use.
private let encodedInternalError = try! createEncoder().encode(
    ErrorWithType(type: "InternalError",
                  payload: SmokeOperationsErrorPayload(errorMessage: nil)))
// swiftlint:enable force_try

extension JSONEncoder {
    /// Return a SmokeFramework compatible JSON Encoder
    public static func getFrameworkEncoder() -> JSONEncoder {
        return createEncoder()
    }
    
    /**
     Encodes a payload for use as a response, optionally with a reason.
 
     - Parameters:
        - payload: The payload to encode.
        - reason: Optionally the reason to include in the payload.
     */
    public static func encodePayload<EncodableType: Encodable>(
        payload: EncodableType,
        reason: String? = nil) -> Data {
            let encodedError: Data
            
            do {
                if let reason = reason {
                    let errorWithReason = ErrorWithType(type: reason,
                                                        payload: payload)
                    encodedError = try createEncoder().encode(errorWithReason)
                } else {
                    encodedError = try createEncoder().encode(payload)
                }
            } catch {
                Log.error("Unable to encode error message: \(error)")
                
                encodedError = encodedInternalError
            }
            
            return encodedError
    }
}
