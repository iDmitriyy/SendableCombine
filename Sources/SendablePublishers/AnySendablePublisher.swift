//
//  AnySendablePublisher.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Self.Output: Sendable {
  @export(implementation)
  public func eraseToAnyPublisher() -> AnySendablePublisher<Output, Failure> {
    AnySendablePublisher(_publisher_: self)
  }
}

extension SendableShell {
  @export(implementation)
  public func eraseToAnyPublisher() -> AnySendablePublisher<Output, Failure> {
    AnySendablePublisher(_unverifiedSendablePublisher_: _base)
  }
}

public struct AnySendablePublisher<Output: Sendable, Failure: Error>: Publisher, @unchecked Sendable,
  CustomStringConvertible {
  @usableFromInline
  internal let anyPublisher: any Publisher<Output, Failure>

  @usableFromInline
  internal let receiveFunc: (any Publisher, any Subscriber<Output, Failure>) -> Void

  @inlinable
  public init<P: Publisher>(_publisher_: P) where P: Sendable, Output == P.Output, Failure == P.Failure {
    anyPublisher = _publisher_

    receiveFunc = { instance, subscriber in
      let casted = instance as! P
      casted.receive(subscriber: subscriber)
    }
  }

  @inlinable
  public init<P: Publisher>(_unverifiedSendablePublisher_: P) where Output == P.Output, Failure == P.Failure {
    anyPublisher = _unverifiedSendablePublisher_

    receiveFunc = { instance, subscriber in
      let casted = instance as! P
      casted.receive(subscriber: subscriber)
    }
  }

  @export(implementation)
  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure {
    receiveFunc(anyPublisher, subscriber)
  }

  public var description: String {
    "AnySendablePublisher<\(Output.self), \(Failure.self)>"
  }
}
