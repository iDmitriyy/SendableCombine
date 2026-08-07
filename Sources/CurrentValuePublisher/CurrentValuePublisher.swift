//
//  CurrentValuePublisher.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

import Foundation
public import Combine

/// A publisher that wraps a `CurrentValueSubject` and guarantees
/// the current value is emitted immediately upon subscription.
///
/// Unlike `CurrentValueSubject`, `CurrentValuePublisher` ensures the
/// subscriber receives the current value as the first event, regardless
/// of scheduling.
public struct CurrentValuePublisher<Output: Sendable, Failure: Error>: Publisher, Sendable {
  public let initialValue: Output

  private let subject: SendableCurrentValueSubject<Output, Failure>

  public init(initialValue: Output) where Failure == Never {
    self.initialValue = initialValue
    self.subject = SendableCurrentValueSubject(initialValue)
  }

  public init(initialValue: Output) where Failure == any Error {
    self.initialValue = initialValue
    self.subject = SendableCurrentValueSubject(initialValue)
  }

  public func receive<S: Subscriber>(
    subscriber: S
  ) where Output == S.Input, Failure == S.Failure {
    subject.receive(subscriber: subscriber)
  }

  public func send(_ value: Output) where Failure == Never {
    subject.send(value)
  }

  public func send(completion: Subscribers.Completion<Failure>) {
    subject.send(completion: completion)
  }
}

extension CurrentValuePublisher where Failure == Never {
  public func send() where Output == Void {
    subject.send(())
  }
}

private final class SendableCurrentValueSubject<Output: Sendable, Failure: Error>: @unchecked Sendable {
  private let lock = NSLock()
  private let subject: CurrentValueSubject<Output, Failure>

  init(_ value: Output) {
    self.subject = CurrentValueSubject(value)
  }

  var value: Output {
    lock.withLock { subject.value }
  }

  func send(_ value: Output) {
    lock.withLock { subject.send(value) }
  }

  func send(completion: Subscribers.Completion<Failure>) {
    lock.withLock { subject.send(completion: completion) }
  }

  func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Failure == S.Failure {
    lock.withLock { subject.receive(subscriber: subscriber) }
  }
}
