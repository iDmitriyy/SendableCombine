//
//  SideEffects.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 29.09.2026.
//

extension AnyCurrentValuePublisher {
  // MARK: - handleEvents
  
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
  
  // MARK: - sink
  
  @export(implementation)
  public func sink(receiveCompletion: @Sendable @escaping (Subscribers.Completion<Failure>) -> Void = { _ in },
                   receiveValue: @Sendable @escaping (Output) -> Void) -> AnyCancellable {
    self.Combine::sink(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
  }
  
  // MARK: - assign

  @export(implementation)
  public func assign<Root: Sendable>(to keyPath: ReferenceWritableKeyPath<Root, Output>,
                                     on object: Root) -> AnyCancellable where Failure == Never {
    self.Combine::assign(to: keyPath, on: object)
  }
  
  // MARK: - breakpoint
  
  @export(implementation)
  public func breakpoint(receiveSubscription: (@Sendable (any Subscription) -> Bool)? = nil,
                         receiveOutput: (@Sendable (Self.Output) -> Bool)? = nil,
                         receiveCompletion: (@Sendable (Subscribers.Completion<Self.Failure>) -> Bool)? = nil) -> Self {
    AnyCurrentValuePublisher(manuallyProven_SemiSendable: self.Combine::breakpoint(receiveSubscription: receiveSubscription,
                                                                                   receiveOutput: receiveOutput,
                                                                                   receiveCompletion: receiveCompletion))
  }
  
  // MARK: - print
  
  @export(implementation)
  public func print(
    _ prefix: String = "",
    to stream: (any TextOutputStream)? = nil,
  ) -> Self {
    let printed = Publishers.Print(upstream: self, prefix: prefix, to: stream)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: printed)
  }
}

extension AnyCurrentValuePublisher where Failure == Never {
  @export(implementation)
  public func sink(receiveValue: @Sendable @escaping (Output) -> Void) -> AnyCancellable {
    self.Combine::sink(receiveValue: receiveValue)
  }
}
