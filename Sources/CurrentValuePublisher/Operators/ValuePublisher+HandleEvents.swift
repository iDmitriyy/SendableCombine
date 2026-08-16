//
//  ValuePublisher+HandleEvents.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func handleEvents(receiveSubscription: (@Sendable (any Subscription) -> Void)? = nil,
                           receiveOutput: (@Sendable (Self.Output) -> Void)? = nil,
                           receiveCompletion: (@Sendable (Subscribers.Completion<Self.Failure>) -> Void)? = nil,
                           receiveCancel: (@Sendable () -> Void)? = nil,
                           receiveRequest: (@Sendable (Subscribers.Demand) -> Void)? = nil)
  -> AnyCurrentValuePublisher<Output, Failure> {
    let handleEvents = Publishers.HandleEvents(upstream: self,
                                               receiveSubscription: receiveSubscription,
                                               receiveOutput: receiveOutput,
                                               receiveCompletion: receiveCompletion,
                                               receiveCancel: receiveCancel,
                                               receiveRequest: receiveRequest)
    return AnyCurrentValuePublisher<Output, Failure>(manuallyProven_SemiSendable: handleEvents)
  }
}
