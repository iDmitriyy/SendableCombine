//
//  ValuePublisher+ShareHot.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 28.09.2026.
//

import SendablePublishers

// MARK: - Hot Share-Replay

extension AnyCurrentValuePublisher where Output: Sendable, Failure == Never {
  public func shareHot() -> Self {
    let connectable: any ConnectablePublisher<Output, Failure> & Sendable = self.SendablePublishers::makeConnectable()
    let connectionCancellable = connectable.SendablePublishers::connect()

    let adapter = BridgePublisher<Output, Failure>(subscribeSendingClosure: { [connectionCancellable] subscriber in
      _ = connectionCancellable // Retain connectionCancellable for hot semantics
      connectable.receive(subscriber: subscriber)
    })

    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: adapter)
  }
}

/// Adapter that bridges a downstream subscription to upstream sequence.
///
/// It acts as a functional proxy that can retain auxiliary resource handles
/// (such as active connection tokens) for the exact duration of the publisher's lifespan.
package struct BridgePublisher<Output, Failure: Error>: Publisher {
  @usableFromInline
  internal let __subscribeClosure: @Sendable (any Subscriber<Output, Failure>) -> Void

  @inlinable
  package init(subscribeClosure: @Sendable @escaping (any Subscriber<Output, Failure>) -> Void) {
    __subscribeClosure = subscribeClosure
  }

  package init(subscribeSendingClosure: sending @escaping (any Subscriber<Output, Failure>) -> Void) {
    let box = _SendingBox(subscribeSendingClosure)

    __subscribeClosure = { subscriber in
      box.closure(subscriber)
    }
  }
  
  @inlinable
  package func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    __subscribeClosure(subscriber)
  }
}

extension BridgePublisher: Sendable where Output: Sendable {}

fileprivate struct _SendingBox<Output, Failure>: @unchecked Sendable {
  let closure: (any Subscriber<Output, Failure>) -> Void
  
  init(_ closure: sending @escaping (any Subscriber<Output, Failure>) -> Void) {
    self.closure = closure
  }
}
