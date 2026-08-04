//
//  SendablePublisher.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

@_exported public import Combine

// MARK: - Protocol

public typealias SendablePublisher<Output: Sendable, Failure> = Publisher<Output, Failure> & Sendable

// MARK: - Shell

public struct SendablePublisher_<Upstream: Publisher>: Publisher, @unchecked Sendable where Upstream.Output: Sendable {
  public typealias Output = Upstream.Output
  public typealias Failure = Upstream.Failure
  
  @usableFromInline
  internal let _base: Upstream
  
  @export(implementation)
  internal init(_unverified_SendablePublisher__ publisher: Upstream) {
    _base = publisher
  }
  
  public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    _base.receive(subscriber: subscriber)
  }
  
  @export(implementation)
  public func eraseToOpaque() -> some SendablePublisher<Output, Failure> {
    self
  }
}

// MARK: - Public SPI

extension SendablePublisher_ {
  @_spi(ExtensionsUnsafeAPI)
  @export(implementation)
  public var _upstream: Upstream { _base }
  
  @_spi(ExtensionsUnsafeAPI)
  @export(implementation)
  public init(unverified_SendablePublisher publisher: Upstream) {
    self.init(_unverified_SendablePublisher__: publisher)
  }
}
