//
//  ValuePublisher+HandleEvents.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

public import Combine

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func handleEvents(receiveSubscription: ((any Subscription) -> Void)? = nil,
                           receiveOutput: ((Self.Output) -> Void)? = nil,
                           receiveCompletion: ((Subscribers.Completion<Self.Failure>) -> Void)? = nil,
                           receiveCancel: (() -> Void)? = nil,
                           receiveRequest: ((Subscribers.Demand) -> Void)? = nil)
  -> AnyCurrentValuePublisher<Output, Failure> {
    let handleEvents = Publishers.HandleEvents(upstream: self,
                                               receiveSubscription: receiveSubscription,
                                               receiveOutput: receiveOutput,
                                               receiveCompletion: receiveCompletion,
                                               receiveCancel: receiveCancel,
                                               receiveRequest: receiveRequest)
    return AnyCurrentValuePublisher<Output, Failure>(retained_unverifiedValuePublisher: handleEvents)
  }
}
