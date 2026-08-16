//
//  SendableShell.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

public struct SendableShell<Upstream: Publisher>: Publisher & CustomStringConvertible, @unchecked Sendable
  where Upstream.Output: Sendable {
  public typealias Output = Upstream.Output
  public typealias Failure = Upstream.Failure

  @usableFromInline
  internal let _base: Upstream

  @export(implementation)
  internal init(_manuallyProven_Sendable__ publisher: Upstream) {
    _base = publisher
  }

  @export(implementation)
  public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
    _base.receive(subscriber: subscriber)
  }

  public var description: String {
    "SendableShell<\(Upstream.self)>"
  }
}

// MARK: - Public SPI

extension SendableShell {
  @_spi(ExtensionsUnsafeAPI)
  @export(implementation)
  public var _upstream: Upstream {
    _base
  }

  @_spi(ExtensionsUnsafeAPI)
  @export(implementation)
  public init(manuallyProven_Sendable publisher: Upstream) {
    self.init(_manuallyProven_Sendable__: publisher)
  }
}
