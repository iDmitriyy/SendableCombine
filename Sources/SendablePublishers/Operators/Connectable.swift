//
//  Connectable.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendableShell {
  @export(implementation)
  public func multicast<S: Subject & Sendable>(
    _ createSubject: @escaping () -> S,
  ) -> SendableShell<Publishers.Multicast<Upstream, S>> where S.Output == Output, S.Failure == Failure {
    let multicast = Publishers.Multicast(upstream: _base, createSubject: createSubject)
    return SendableShell<Publishers.Multicast<Upstream, S>>(_unverified_SendablePublisher__: multicast)
  }

  @export(implementation)
  public func multicast<S: Subject & Sendable>(
    subject: S,
  ) -> SendableShell<Publishers.Multicast<Upstream, S>> where S.Output == Output, S.Failure == Failure {
    let multicast = _base.multicast(subject: subject)
    return SendableShell<Publishers.Multicast<Upstream, S>>(_unverified_SendablePublisher__: multicast)
  }

  @export(implementation)
  public func makeConnectable() -> ConnectableSendablePublisher<Upstream> {
    ConnectableSendablePublisher(sendableShell: self)
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
  public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
    _connectable.receive(subscriber: subscriber)
  }

  @export(implementation)
  public func connect() -> any Cancellable {
    _connectable.connect()
  }
}

extension ConnectableSendablePublisher: @unchecked Sendable {}
