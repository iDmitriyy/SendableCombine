//
//  SideEffects.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendableShell {
  @export(implementation)
  public func handleEvents(
    receiveSubscription: (@Sendable (any Subscription) -> Void)? = nil,
    receiveOutput: (@Sendable (Output) -> Void)? = nil,
    receiveCompletion: (@Sendable (Subscribers.Completion<Failure>) -> Void)? = nil,
    receiveCancel: (@Sendable () -> Void)? = nil,
    receiveRequest: (@Sendable (Subscribers.Demand) -> Void)? = nil
  ) -> SendableShell<Publishers.HandleEvents<Upstream>> {
    let handled = Publishers.HandleEvents(upstream: self._base,
                                          receiveSubscription: receiveSubscription,
                                          receiveOutput: receiveOutput,
                                          receiveCompletion: receiveCompletion,
                                          receiveCancel: receiveCancel,
                                          receiveRequest: receiveRequest)
    return SendableShell<Publishers.HandleEvents<Upstream>>(_unverified_SendablePublisher__: handled)
  }
}

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func sink(receiveCompletion: @Sendable @escaping (Subscribers.Completion<Failure>) -> Void = { _ in },
                   receiveValue: @Sendable @escaping (Output) -> Void) -> AnyCancellable {
    self.Combine::sink(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
  }
}

extension Publisher where Self: Sendable, Output: Sendable, Failure == Never {
  @export(implementation)
  public func sink(receiveValue: @Sendable @escaping (Output) -> Void) -> AnyCancellable {
    self.Combine::sink(receiveValue: receiveValue)
  }
}

extension SendableShell {
  @export(implementation)
  public func assign<Root: Sendable>(to keyPath: ReferenceWritableKeyPath<Root, Output>,
                                     on object: Root) -> AnyCancellable where Failure == Never {
    _base.assign(to: keyPath, on: object)
  }
  
  @export(implementation)
  public func print(
    _ prefix: String = "",
    to stream: (any TextOutputStream)? = nil
  ) -> SendableShell<Publishers.Print<Upstream>> {
    let printed = Publishers.Print(upstream: self._base, prefix: prefix, to: stream)
    return SendableShell<Publishers.Print<Upstream>>(_unverified_SendablePublisher__: printed)
  }
}
