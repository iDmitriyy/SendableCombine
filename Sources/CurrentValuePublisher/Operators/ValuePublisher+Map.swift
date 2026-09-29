//
//  ValuePublisher+Map.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 17.07.2026.
//

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func map<T>(_ transform: @Sendable @escaping (Output) -> T) -> AnyCurrentValuePublisher<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return AnyCurrentValuePublisher<T, Failure>(manuallyProven_SemiSendable: map)
  }
}

