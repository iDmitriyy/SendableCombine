//
//  Signal.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine
import Foundation

public struct Signal<Element>: Publisher {
  public typealias Output = Element
  public typealias Failure = Never

  @usableFromInline internal let _mainThreadUpstream: AnyPublisher<Element, Never>

  public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Element {
    _mainThreadUpstream.receive(subscriber: subscriber)
  }

  // MARK: init with Infallible Publisher

  /// Internal init: infallible Publisher → main thread → share
  internal init<P: Publisher>(infallibleUpstream: P) where P.Output == Element, P.Failure == Never {
    _mainThreadUpstream = infallibleUpstream
      .receive(on: DispatchQueue.main)
      .share()
      .eraseToAnyPublisher()
  }

  // MARK: init with Failable Publisher

  /// Public init: generic Publisher → ignore errors → main thread → share
  public init<P: Publisher>(failableUpstream: P) where P.Output == Element {
    _mainThreadUpstream = failableUpstream
      .catch { _ in Empty() }
      .receive(on: DispatchQueue.main)
      .share()
      .eraseToAnyPublisher()
  }

  public init<P: Publisher>(failableUpstream: P,
                            catchError: @escaping () -> Output) where P.Output == Element {
    _mainThreadUpstream = failableUpstream
      .catch { _ in Just(catchError()) }
      .receive(on: DispatchQueue.main)
      .share()
      .eraseToAnyPublisher()
  }
}

// MARK: - Sendable

extension Signal: @unchecked Sendable where Element: Sendable {}

extension Signal where Element: Sendable {
  public func sink(receiveValue: @MainActor @Sendable @escaping (Self.Output) -> Void) -> AnyCancellable {
    _mainThreadUpstream.sink(receiveValue: { value in
      MainActor.assumeIsolated {
        receiveValue(value)
      }
    })
  }
}

// MARK: - Signal as Publisher

extension Signal {
  public func asPublisher() -> AnyPublisher<Element, Never> {
    _mainThreadUpstream
  }
}

// MARK: - Publisher as Signal

extension Publisher where Failure == Never {
  public func asSignal() -> Signal<Output> {
    Signal(infallibleUpstream: self)
  }
}

extension Publisher {
  public func asSignalIgnoringError() -> Signal<Output> {
    Signal(failableUpstream: self)
  }

  public func asSignal(catchError: @Sendable @escaping () -> Output) -> Signal<Output> {
    Signal(failableUpstream: self, catchError: catchError)
  }
}
