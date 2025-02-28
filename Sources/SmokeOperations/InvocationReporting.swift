// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  InvocationReporting.swift
//  SmokeOperations
//

import Foundation
import Logging
import Tracing

/**
 A protocol that can report on an invocation.
 */
public protocol InvocationReporting {
    var logger: Logger { get }
    var internalRequestId: String { get }
    var span: Span? { get }
}

public extension InvocationReporting {
    // Add span property while remaining backwards compatible
    var span: Span? {
        return nil
    }
}
