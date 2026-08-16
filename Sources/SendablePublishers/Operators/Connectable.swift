//
//  Connectable.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func multicast<S: Subject & Sendable>(
    _ createSubject: @escaping () -> S,
  ) -> some Publisher<S.Output, S.Failure> & Sendable where S.Output == Output, S.Failure == Failure {
    let multicast = Publishers.Multicast(upstream: self, createSubject: createSubject)
    return SendableShell<Publishers.Multicast<Self, S>>(_manuallyProven_Sendable__: multicast)
  }

  @export(implementation)
  public func multicast<S: Subject & Sendable>(
    subject: S,
  ) -> some Publisher<S.Output, S.Failure> & Sendable where S.Output == Output, S.Failure == Failure {
    let multicast = self.Combine::multicast(subject: subject)
    return SendableShell<Publishers.Multicast<Self, S>>(_manuallyProven_Sendable__: multicast)
  }

  @export(implementation)
  public func makeConnectable() -> some Publisher<Output, Failure> & Sendable {
    ConnectableSendablePublisher(upstream: self)
  }
}

public struct ConnectableSendablePublisher<Upstream: Publisher>: Publisher where Upstream.Output: Sendable {
  public typealias Output = Upstream.Output
  public typealias Failure = Upstream.Failure

  @usableFromInline
  internal let _connectable: Publishers.MakeConnectable<Upstream>

  @export(implementation)
  internal init(sendableShell: SendableShell<Upstream>) {
    _connectable = Publishers.MakeConnectable(upstream: sendableShell._base)
  }

  @export(implementation)
  internal init(upstream: Upstream) {
    _connectable = Publishers.MakeConnectable(upstream: upstream)
  }

  @export(implementation)
  public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
    _connectable.receive(subscriber: subscriber)
  }

  @export(implementation)
  public func connect() -> any Cancellable {
    _connectable.connect()
  }
}

extension ConnectableSendablePublisher: @unchecked Sendable {}
