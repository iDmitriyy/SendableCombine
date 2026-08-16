//
//  SideEffects.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func handleEvents(
    receiveSubscription: (@Sendable (any Subscription) -> Void)? = nil,
    receiveOutput: (@Sendable (Output) -> Void)? = nil,
    receiveCompletion: (@Sendable (Subscribers.Completion<Failure>) -> Void)? = nil,
    receiveCancel: (@Sendable () -> Void)? = nil,
    receiveRequest: (@Sendable (Subscribers.Demand) -> Void)? = nil,
  ) -> some Publisher<Output, Failure> & Sendable {
    let handled = Publishers.HandleEvents(upstream: self,
                                          receiveSubscription: receiveSubscription,
                                          receiveOutput: receiveOutput,
                                          receiveCompletion: receiveCompletion,
                                          receiveCancel: receiveCancel,
                                          receiveRequest: receiveRequest)
    return SendableShell<Publishers.HandleEvents<Self>>(_manuallyProven_Sendable__: handled)
  }

  @export(implementation)
  public func sink(receiveCompletion: @Sendable @escaping (Subscribers.Completion<Failure>) -> Void = { _ in },
                   receiveValue: @Sendable @escaping (Output) -> Void) -> AnyCancellable {
    self.Combine::sink(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
  }

  @export(implementation)
  public func assign<Root: Sendable>(to keyPath: ReferenceWritableKeyPath<Root, Output>,
                                     on object: Root) -> AnyCancellable where Failure == Never {
    self.Combine::assign(to: keyPath, on: object)
  }

  @export(implementation)
  public func print(
    _ prefix: String = "",
    to stream: (any TextOutputStream)? = nil,
  ) -> some Publisher<Output, Failure> & Sendable {
    let printed = Publishers.Print(upstream: self, prefix: prefix, to: stream)
    return SendableShell<Publishers.Print<Self>>(_manuallyProven_Sendable__: printed)
  }
}

extension Publisher where Self: Sendable, Output: Sendable, Failure == Never {
  @export(implementation)
  public func sink(receiveValue: @Sendable @escaping (Output) -> Void) -> AnyCancellable {
    self.Combine::sink(receiveValue: receiveValue)
  }
}
