//
//  Connectable.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func multicast<S: Subject & Sendable>(
    _ createSubject: sending @escaping () -> S,
  ) -> some ConnectablePublisher<S.Output, S.Failure> & Sendable where S.Output == Output, S.Failure == Failure {
    let multicast = Publishers.Multicast(upstream: self, createSubject: createSubject)
    return SendableShell<Publishers.Multicast<Self, S>>(_manuallyProven_Sendable__: multicast)
  }

  @export(implementation)
  public func multicast<S: Subject & Sendable>(
    subject: S,
  ) -> some ConnectablePublisher<S.Output, S.Failure> & Sendable where S.Output == Output, S.Failure == Failure {
    let multicast = self.Combine::multicast(subject: subject)
    return SendableShell<Publishers.Multicast<Self, S>>(_manuallyProven_Sendable__: multicast)
  }

  @export(implementation)
  public func makeConnectable() -> some ConnectablePublisher<Output, Failure> & Sendable {
    let connectable = Publishers.MakeConnectable(upstream: self)
    return SendableShell<Publishers.MakeConnectable<Self>>(_manuallyProven_Sendable__: connectable)
  }
}

extension SendableShell: ConnectablePublisher where Upstream: ConnectablePublisher {
  public func connect() -> any Cancellable {
    _upstream.connect()
  }
}
