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

  @export(implementation)
  internal init<P: Publisher>(_sendablePublisher_ sendablePublisher: P)
    where P: Sendable, P.Output == Output, P.Failure == Failure {
    anyPublisher = sendablePublisher
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
