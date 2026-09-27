//
//  AnySendablePublisher.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

// FIXME: - may be obsoleted as now it is simply typealias = any Publisher<Output, Failure> & Sendable

public struct AnySendablePublisher<Output: Sendable, Failure: Error>: Publisher, Sendable, CustomStringConvertible {
  @usableFromInline
  package let anyPublisher: any Publisher<Output, Failure> & Sendable

  @export(implementation)
  public init<P: Publisher>(_sendablePublisher_ sendablePublisher: P)
    where P: Sendable, P.Output == Output, P.Failure == Failure {
    anyPublisher = sendablePublisher
  }

@export(implementation)
  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure {
    anyPublisher.receive(subscriber: subscriber)
  }

  @export(implementation)
  public var publisher: any Publisher<Output, Failure> {
    anyPublisher
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
