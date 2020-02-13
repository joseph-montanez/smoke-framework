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
// SmokeHTTP1Server+startAsOperationServer.swift
// SmokeOperationsHTTP1
//
import Foundation
import SmokeHTTP1
import NIOHTTP1
import SmokeOperations
import Logging
import SmokeInvocation

public extension SmokeHTTP1Server {
    static func startAsOperationServer<ContextType, SelectorType, OperationIdentifer>(
        withHandlerSelector handlerSelector: SelectorType,
        andContext context: ContextType,
        andPort port: Int = ServerDefaults.defaultPort,
        serverName: String = "Server",
        invocationStrategy: InvocationStrategy = GlobalDispatchQueueAsyncInvocationStrategy(),
        defaultLogger: Logger = Logger(label: "com.amazon.SmokeFramework.SmokeHTTP1Server"),
        reportingConfiguration: SmokeServerReportingConfiguration<OperationIdentifer> = SmokeServerReportingConfiguration(),
        eventLoopProvider: SmokeServerEventLoopProvider = .spawnNewThreads,
        shutdownOnSignal: SmokeServerShutdownOnSignal = .sigint) throws -> SmokeHTTP1Server
        where SelectorType: SmokeHTTP1HandlerSelector, SelectorType.ContextType == ContextType,
        HTTPRequestHead == SelectorType.DefaultOperationDelegateType.TraceContextType.RequestHeadType,
        SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
        SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            StandardHTTP1ResponseHandler<SmokeServerInvocationContext<SelectorType.DefaultOperationDelegateType.TraceContextType>>,
        SelectorType.OperationIdentifer == OperationIdentifer {
            let handler = OperationServerHTTP1RequestHandler(
                handlerSelector: handlerSelector,
                context: context, serverName: serverName, reportingConfiguration: reportingConfiguration)
            let server = StandardSmokeHTTP1Server(handler: handler,
                                                  port: port,
                                                  invocationStrategy: invocationStrategy,
                                                  defaultLogger: defaultLogger,
                                                  eventLoopProvider: eventLoopProvider,
                                                  shutdownOnSignal: shutdownOnSignal)
            
            try server.start()
            
            return server
    }
}
