//
//  AnyCurrentValuePublisher.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

import Foundation
public import SendablePublishers

// MARK: - InfallibleValuePublisher

// FIXME: - Make it conditionaly Sendable when Output: Sendable
public typealias AnyInfallibleValuePublisher<Output> = AnyCurrentValuePublisher<Output, Never>

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher (Non-Versioned, Generic Failure)

/// A type-erasing publisher that represents a continuous state or value stream.
///
/// All CurrentValuePublisher specific operators are created with @Sendable closures.
/// CurrentValuePublisher is conditionally Sendable when Output is Sendable.
public struct AnyCurrentValuePublisher<Output, Failure: Error>: Publisher {
  @usableFromInline
  internal let __base: any Publisher<Output, Failure>

  // TODO: - ?replace generic param by existential
  // ? @export(implementation) @_transparent
  // TODO: add 2 __ underscores
  @usableFromInline @_transparent
  internal init<P: Publisher & Sendable>(retained_unverifiedValuePublisher base: P)
  where P.Output == Output, P.Failure == Failure {
    __base = base
  }

  
  @usableFromInline @_transparent
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P,
                               getCurrentValue _: @escaping () -> Output) where P.Output == Output, P.Failure == Failure {
    __base = base
  }

  @export(implementation) @_transparent
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    __base.receive(subscriber: subscriber)
  }
}

extension AnyCurrentValuePublisher {
  // TODO: - ?replace generic param by existential
  // FIXME: retained_unverifiedValuePublisher should be Sendable in this initializer
  
  /// For external types like Relay or Custom subjects with replay(1...) behavior
  @_spi(ExtensionsUnsafeAPI)
  @export(implementation) @_transparent
  public init<P: Publisher & Sendable>(unverified_ValueNonSendableSubject base: P,
                                       getCurrentValue: @escaping () -> Output)
    where P.Output == Output, P.Failure == Failure {
    _ = getCurrentValue // needed only as a guarantee that subject can return value, e.g. for Relay from other lib.
    __base = base
  }
  
  @export(implementation) @_transparent
  public init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject)
  }
}
