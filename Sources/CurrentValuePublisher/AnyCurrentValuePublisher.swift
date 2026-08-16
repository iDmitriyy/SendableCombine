//
//  AnyCurrentValuePublisher.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import SendablePublishers
@_exported public import Combine

// MARK: - InfallibleValuePublisher

// FIXME: - Make it conditionaly Sendable when Output: Sendable
public typealias AnyInfallibleValuePublisher<Output> = AnyCurrentValuePublisher<Output, Never>

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher

/// A type-erasing publisher that represents a continuous state or value stream.
///
/// All CurrentValuePublisher specific operators are created with @Sendable closures.
/// CurrentValuePublisher is conditionally Sendable when Output is Sendable.
public struct AnyCurrentValuePublisher<Output, Failure: Error>: Publisher {
  @usableFromInline
  internal let __base: any Publisher<Output, Failure>
  
  @usableFromInline @_transparent
  internal init(manuallyProven_SemiSendable base: any Publisher<Output, Failure>) {
    __base = base
  }

  @export(implementation)
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    __base.receive(subscriber: subscriber)
  }
}

extension AnyCurrentValuePublisher: @unchecked Sendable where Output: Sendable {}

extension AnyCurrentValuePublisher {
  /// For external types like Relay or Custom subjects with replay(1...) behavior
  @_spi(ExtensionsUnsafeAPI)
  @export(implementation)
  public init<P: Publisher & Sendable>(manuallyProven_ReplayCurrentValuePublisher base: P,
                                       getCurrentValue: @escaping () -> Output)
    where P.Output: Sendable, P.Output == Output, P.Failure == Failure {
    _ = getCurrentValue // needed only as a guarantee that subject can return value, e.g. for Relay from other lib.
    __base = base
  }
}

extension CurrentValueSubject {
  @export(implementation)
  public func asCurrentValuePublisher() -> AnyCurrentValuePublisher<Output, Failure> {
    AnyCurrentValuePublisher(manuallyProven_SemiSendable: self)
  }
}
