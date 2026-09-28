//
//  ValuePublisher+Scan.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 28.09.2026.
//

extension AnyCurrentValuePublisher {
  @export(implementation)
  public func scan<Accumulate>(_ initial: Accumulate,
                               _ nextPartialResult: @Sendable @escaping (Accumulate, Output) -> Accumulate)
    -> AnyCurrentValuePublisher<Accumulate, Failure> {
    let scan = Publishers.Scan(upstream: self, initialResult: initial, nextPartialResult: nextPartialResult)
    return AnyCurrentValuePublisher<Accumulate, Failure>(manuallyProven_SemiSendable: scan)
  }
}
