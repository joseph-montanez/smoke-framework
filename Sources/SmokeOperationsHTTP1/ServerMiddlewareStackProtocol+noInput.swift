// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  ServerMiddlewareStackProtocol+noInput.swift
//  SmokeOperationsHTTP1
//

import SwiftMiddleware
import NIOHTTP1
import SmokeOperations
import SmokeAsyncHTTP1Server
import Logging

public extension ServerMiddlewareStackProtocol {
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
    InnerMiddlewareType.IncomingInput == Void,
    InnerMiddlewareType.IncomingInput == InnerMiddlewareType.OutgoingInput,
    // requirements for OuterMiddlewareType -> TransformMiddleware
    TransformMiddlewareType.IncomingInput == OuterMiddlewareType.OutgoingInput,
    TransformMiddlewareType.IncomingOutputWriter == OuterMiddlewareType.OutgoingOutputWriter,
    TransformMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // requirements for TransformMiddleware -> InnerMiddlewareType
    InnerMiddlewareType.IncomingInput == TransformMiddlewareType.OutgoingInput,
    InnerMiddlewareType.IncomingOutputWriter == TransformMiddlewareType.OutgoingOutputWriter,
    InnerMiddlewareType.IncomingContext == TransformMiddlewareType.OutgoingContext,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the outer middleware cannot change the input type
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext {
        @Sendable func innerOperation(_input: Void, context: ApplicationContextType) async throws
        -> InnerMiddlewareType.OutgoingOutputWriter.OutputType {
            return try await operation(context)
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
    
    // No Inner Middleware. With Outer Middleware
    mutating func addHandlerForOperation<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws
          -> TransformMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], outerMiddleware: OuterMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
    TransformMiddlewareType.OutgoingInput == Void,
    // requirements for OuterMiddlewareType -> TransformMiddleware
    TransformMiddlewareType.IncomingInput == OuterMiddlewareType.OutgoingInput,
    TransformMiddlewareType.IncomingOutputWriter == OuterMiddlewareType.OutgoingOutputWriter,
    TransformMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    TransformMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the outer middleware cannot change the input type
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext {
        let innerMiddleware: EmptyMiddleware<Void, TransformMiddlewareType.OutgoingOutputWriter, TransformMiddlewareType.OutgoingContext> = .init()
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
    
    // With Inner Middleware. No Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol,
                                         TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], innerMiddleware: InnerMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
    InnerMiddlewareType.IncomingInput == Void,
    TransformMiddlewareType.IncomingInput == HTTPServerRequest,
    InnerMiddlewareType.IncomingInput == InnerMiddlewareType.OutgoingInput,
    // requirements for TransformMiddleware -> InnerMiddlewareType
    InnerMiddlewareType.IncomingInput == TransformMiddlewareType.OutgoingInput,
    InnerMiddlewareType.IncomingOutputWriter == TransformMiddlewareType.OutgoingOutputWriter,
    InnerMiddlewareType.IncomingContext == TransformMiddlewareType.OutgoingContext,
    // requirements for any added middleware
    TransformMiddlewareType.IncomingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == TransformMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == TransformMiddlewareType.IncomingContext {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
    
    // No Inner Middleware. No Outer Middleware
    mutating func addHandlerForOperation<TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws
          -> TransformMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)],
          transformMiddleware: TransformMiddlewareType)
    where
    TransformMiddlewareType.OutgoingInput == Void,
    TransformMiddlewareType.IncomingInput == HTTPServerRequest,
    // requirements for any added middleware
    TransformMiddlewareType.IncomingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    TransformMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == TransformMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == TransformMiddlewareType.IncomingContext {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        let innerMiddleware: EmptyMiddleware<Void, TransformMiddlewareType.OutgoingOutputWriter, TransformMiddlewareType.OutgoingContext> = .init()
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
    
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                                 TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType),
          allowedErrors: [(ErrorType, Int)], outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
    InnerMiddlewareType.IncomingInput == Void,
    InnerMiddlewareType.IncomingInput == InnerMiddlewareType.OutgoingInput,
    // requirements for OuterMiddlewareType -> TransformMiddleware
    TransformMiddlewareType.IncomingInput == OuterMiddlewareType.OutgoingInput,
    TransformMiddlewareType.IncomingOutputWriter == OuterMiddlewareType.OutgoingOutputWriter,
    TransformMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // requirements for TransformMiddleware -> InnerMiddlewareType
    InnerMiddlewareType.IncomingInput == TransformMiddlewareType.OutgoingInput,
    InnerMiddlewareType.IncomingOutputWriter == TransformMiddlewareType.OutgoingOutputWriter,
    InnerMiddlewareType.IncomingContext == TransformMiddlewareType.OutgoingContext,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the outer middleware cannot change the input type
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext {
        @Sendable func innerOperation(_input: Void, context: ApplicationContextType) async throws
        -> InnerMiddlewareType.OutgoingOutputWriter.OutputType {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
    
    // No Inner Middleware. With Outer Middleware
    mutating func addHandlerForOperationProvider<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                                 TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws
          -> TransformMiddlewareType.OutgoingOutputWriter.OutputType),
          allowedErrors: [(ErrorType, Int)], outerMiddleware: OuterMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
    TransformMiddlewareType.OutgoingInput == Void,
    // requirements for OuterMiddlewareType -> TransformMiddleware
    TransformMiddlewareType.IncomingInput == OuterMiddlewareType.OutgoingInput,
    TransformMiddlewareType.IncomingOutputWriter == OuterMiddlewareType.OutgoingOutputWriter,
    TransformMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    TransformMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the outer middleware cannot change the input type
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext {
        let innerMiddleware: EmptyMiddleware<Void, TransformMiddlewareType.OutgoingOutputWriter, TransformMiddlewareType.OutgoingContext> = .init()
        
        self.addHandlerForOperationProvider(operationIdentifer, httpMethod: httpMethod, operationProvider: operationProvider,
                                            allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                            transformMiddleware: transformMiddleware)
    }
    
    // With Inner Middleware. No Outer Middleware
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: TransformingMiddlewareProtocol,
                                                 TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType),
          allowedErrors: [(ErrorType, Int)], innerMiddleware: InnerMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
    InnerMiddlewareType.IncomingInput == Void,
    TransformMiddlewareType.IncomingInput == HTTPServerRequest,
    InnerMiddlewareType.IncomingInput == InnerMiddlewareType.OutgoingInput,
    // requirements for TransformMiddleware -> InnerMiddlewareType
    InnerMiddlewareType.IncomingInput == TransformMiddlewareType.OutgoingInput,
    InnerMiddlewareType.IncomingOutputWriter == TransformMiddlewareType.OutgoingOutputWriter,
    InnerMiddlewareType.IncomingContext == TransformMiddlewareType.OutgoingContext,
    // requirements for any added middleware
    TransformMiddlewareType.IncomingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == TransformMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == TransformMiddlewareType.IncomingContext {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        
        self.addHandlerForOperationProvider(operationIdentifer, httpMethod: httpMethod, operationProvider: operationProvider,
                                            allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                            transformMiddleware: transformMiddleware)
    }
    
    // No Inner Middleware. No Outer Middleware
    mutating func addHandlerForOperationProvider<TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws
          -> TransformMiddlewareType.OutgoingOutputWriter.OutputType),
          allowedErrors: [(ErrorType, Int)],
          transformMiddleware: TransformMiddlewareType)
    where
    TransformMiddlewareType.OutgoingInput == Void,
    TransformMiddlewareType.IncomingInput == HTTPServerRequest,
    // requirements for any added middleware
    TransformMiddlewareType.IncomingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    TransformMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == TransformMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == TransformMiddlewareType.IncomingContext {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        let innerMiddleware: EmptyMiddleware<Void, TransformMiddlewareType.OutgoingOutputWriter, TransformMiddlewareType.OutgoingContext> = .init()
        
        self.addHandlerForOperationProvider(operationIdentifer, httpMethod: httpMethod, operationProvider: operationProvider,
                                            allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                            transformMiddleware: transformMiddleware)
    }
}
