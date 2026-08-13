//
//  AnySendablePublisher.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

public struct AnySendablePublisher<Output: Sendable, Failure: Error>: Publisher, @unchecked Sendable,
  CustomStringConvertible {
  @usableFromInline
  internal let anyPublisher: any Publisher<Output, Failure>

  @inlinable
  internal init<P: Publisher>(_sendablePublisher_ sendablePublisher: P)
    where P: Sendable, Output == P.Output, Failure == P.Failure {
    anyPublisher = sendablePublisher
  }

  @inlinable
  public init<P: Publisher>(_unverifiedSendablePublisher_: P) where Output == P.Output, Failure == P.Failure {
    anyPublisher = _unverifiedSendablePublisher_
  }

  @export(implementation)
  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure {
      anyPublisher.receive(subscriber: subscriber)
  }

  public var description: String {
    "AnySendablePublisher<\(Output.self), \(Failure.self)>"
  }
}

// MARK: - Publisher + eraseToAnyPublisher()

extension Publisher where Self: Sendable, Self.Output: Sendable {
  @export(implementation)
  public func eraseToAnyPublisher() -> AnySendablePublisher<Output, Failure> {
    AnySendablePublisher(_sendablePublisher_: self)
  }
}

extension SendableShell {
  @export(implementation)
  public func eraseToAnyPublisher() -> AnySendablePublisher<Output, Failure> {
    AnySendablePublisher(_unverifiedSendablePublisher_: _base)
  }
}
