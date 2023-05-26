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
//  ServerMiddlewareStackProtocol.swift
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeOperations
import SmokeAsyncHTTP1Server
import SmokeOperationsHTTP1
import SmokeHTTP1ServerMiddleware
import Logging

internal struct EmptyMiddleware<Input, OutputWriter, Context>: MiddlewareProtocol {
    public func handle(_ input: Input,
                       outputWriter: OutputWriter,
                       context: Context,
                       next: (Input, OutputWriter, Context) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
    }
}

public struct SmokeMiddlewareContext: ContextWithMutableLogger, ContextWithMutableRequestId {
    public var logger: Logging.Logger?
    public var internalRequestId: String?
    
    public init(logger: Logging.Logger? = nil,
                internalRequestId: String? = nil) {
        self.logger = logger
        self.internalRequestId = internalRequestId
    }
}

/**
 Protocol that manages adding handlers for operations using a defined middleware stack.
 */
public protocol ServerMiddlewareStackProtocol {
    associatedtype RouterType: ServerRouterProtocol
    associatedtype ApplicationContextType
    associatedtype VoidResponseWriterType
    
    init(serverName: String,
         serverConfiguration: SmokeServerConfiguration<RouterType.OperationIdentifer>,
         applicationContextProvider:
         @escaping @Sendable (HTTPServerRequestContext<RouterType.OperationIdentifer>) -> ApplicationContextType)
    
    @Sendable func handle(request: HTTPServerRequest, responseWriter: HTTPServerResponseWriter) async
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type
        - transformMiddleware: The middleware to transform the request and response into the operation's input and output types.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (InnerMiddlewareType.OutgoingInput, ApplicationContextType) async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
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
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     The operation has no input or output.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - statusOnSuccess: The response code to send on a successful operation.
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the inner middleware cannot change the input type or the output type of the writer
    InnerMiddlewareType.IncomingInput == Void, InnerMiddlewareType.IncomingOutputWriter.OutputType == Void,
    InnerMiddlewareType.OutgoingInput == Void, InnerMiddlewareType.OutgoingOutputWriter.OutputType == Void,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // the transform will wrap the writer in a `VoidResponseWriter`
    InnerMiddlewareType.IncomingOutputWriter == VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter>
}

public extension ServerMiddlewareStackProtocol {
    /**
     Default implementation
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the inner middleware cannot change the input type or the output type of the writer
    InnerMiddlewareType.IncomingInput == Void, InnerMiddlewareType.IncomingOutputWriter.OutputType == Void,
    InnerMiddlewareType.OutgoingInput == Void, InnerMiddlewareType.OutgoingOutputWriter.OutputType == Void,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // the transform will wrap the writer in a `VoidResponseWriter`
    InnerMiddlewareType.IncomingOutputWriter == VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter> {
        let transformMiddleware = VoidRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                                                 InnerMiddlewareType.IncomingOutputWriter,
                                                                 InnerMiddlewareType.IncomingContext> { wrappedWriter in
            VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
        
        @Sendable func innerOperation(_ input: InnerMiddlewareType.OutgoingInput, context: ApplicationContextType) async throws
        -> InnerMiddlewareType.OutgoingOutputWriter.OutputType {
            return try await operation(context)
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
}

public extension ServerMiddlewareStackProtocol {
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          innerMiddleware: InnerMiddlewareType)
    where
    // the inner middleware cannot change the input type or the output type of the writer
    InnerMiddlewareType.IncomingInput == Void, InnerMiddlewareType.IncomingOutputWriter.OutputType == Void,
    InnerMiddlewareType.OutgoingInput == Void, InnerMiddlewareType.OutgoingOutputWriter.OutputType == Void,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == RouterType.RouterMiddlewareContext,
    // the transform will wrap the writer in a `VoidResponseWriter`
    InnerMiddlewareType.IncomingOutputWriter == VoidResponseWriter<RouterType.OutputWriter> {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws -> (),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          outerMiddleware: OuterMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead {
        let innerMiddleware: EmptyMiddleware<Void, VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter>, OuterMiddlewareType.OutgoingContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod,
                                           operation: operation, allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws -> (),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus) {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        let innerMiddleware: EmptyMiddleware<Void, VoidResponseWriter<RouterType.OutputWriter>, RouterType.RouterMiddlewareContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> InnerMiddlewareType.OutgoingOutputWriter.OutputType),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          innerMiddleware: InnerMiddlewareType)
    where
    // the inner middleware cannot change the input type or the output type of the writer
    InnerMiddlewareType.IncomingInput == Void, InnerMiddlewareType.IncomingOutputWriter.OutputType == Void,
    InnerMiddlewareType.OutgoingInput == Void, InnerMiddlewareType.OutgoingOutputWriter.OutputType == Void,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == RouterType.RouterMiddlewareContext,
    // the transform will wrap the writer in a `VoidResponseWriter`
    InnerMiddlewareType.IncomingOutputWriter == VoidResponseWriter<RouterType.OutputWriter> {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> ()),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          outerMiddleware: OuterMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let innerMiddleware: EmptyMiddleware<Void, VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter>, OuterMiddlewareType.OutgoingContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod,
                                           operation: innerOperation, allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> ()),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus) {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
              
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        let innerMiddleware: EmptyMiddleware<Void, VoidResponseWriter<RouterType.OutputWriter>, RouterType.RouterMiddlewareContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
}
