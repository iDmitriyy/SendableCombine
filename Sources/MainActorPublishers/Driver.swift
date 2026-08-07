//
//  Driver.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine
import Foundation

public struct Driver<Element>: Publisher {
  public typealias Output = Element
  public typealias Failure = Never

  @usableFromInline internal let _mainThreadUpstream: AnyPublisher<Element, Never>

  public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Element {
    _mainThreadUpstream.receive(subscriber: subscriber)
  }

  // MARK: init with Infallible Publisher

  /// Internal init: pre-processed Publisher → main thread → share
  internal init<P: Publisher>(infallibleUpstream: P, initialValue: Element) where P.Output == Element, P.Failure == Never {
    _mainThreadUpstream = infallibleUpstream
      .prepend(initialValue)
      .receive(on: DispatchQueue.main)
      .share()
      .eraseToAnyPublisher()
  }

  // MARK: init with Failable Publisher

  /// Public init: generic Publisher → ignore errors → main thread → share
  public init<P: Publisher>(failableUpstream: P, initialValue: Element) where P.Output == Element {
    _mainThreadUpstream = failableUpstream
      .prepend(initialValue)
      .catch { _ in Empty() }
      .receive(on: DispatchQueue.main)
      .share()
      .eraseToAnyPublisher()
  }

  public init<P: Publisher>(failableUpstream: P,
                            initialValue: Element,
                            catchError: @escaping () -> Output) where P.Output == Element {
    _mainThreadUpstream = failableUpstream
      .prepend(initialValue)
      .catch { _ in Just(catchError()) }
      .receive(on: DispatchQueue.main)
      .share()
      .eraseToAnyPublisher()
  }

  // Sink override
}

// MARK: - Sendable

extension Driver: @unchecked Sendable where Element: Sendable {}

extension Driver where Element: Sendable {
  public func sink(receiveValue: @MainActor @Sendable @escaping (Self.Output) -> Void) -> AnyCancellable {
    _mainThreadUpstream.sink(receiveValue: { value in
      MainActor.assumeIsolated {
        receiveValue(value)
      }
    })
  }
}

// MARK: - Driver as Publisher

extension Driver {
  public func asPublisher() -> AnyPublisher<Element, Never> {
    _mainThreadUpstream
  }
}

// MARK: - Publisher as Driver

extension Publisher where Failure == Never {
  public func asDriver(initialValue: Output) -> Driver<Output> {
    Driver(infallibleUpstream: self, initialValue: initialValue)
  }
}

extension Publisher {
  public func asDriverIgnoringError(initialValue: Output) -> Driver<Output> {
    Driver(failableUpstream: self, initialValue: initialValue)
  }

  public func asDriver(initialValue: Output,
                       catchError: @Sendable @escaping () -> Output) -> Driver<Output> {
    Driver(failableUpstream: self, initialValue: initialValue, catchError: catchError)
  }
}
