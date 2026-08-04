//
//  Accumulation.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

// MARK: - Accumulation

extension SendablePublisher_ {
  @export(implementation)
  public func scan<T: Sendable>(_ initial: T, _ nextPartialResult: @Sendable @escaping (T, Output) -> T)
    -> SendablePublisher_<Publishers.Scan<Upstream, T>> {
    let scanned = Publishers.Scan(upstream: self._base, initialResult: initial, nextPartialResult: nextPartialResult)
    return SendablePublisher_<Publishers.Scan<Upstream, T>>(_unverified_SendablePublisher__: scanned)
  }
  
  @export(implementation)
  public func tryScan<T: Sendable>(_ initial: T, _ nextPartialResult: @Sendable @escaping (T, Output) throws -> T)
    -> SendablePublisher_<Publishers.TryScan<Upstream, T>> {
    let scanned = Publishers.TryScan(upstream: self._base, initialResult: initial, nextPartialResult: nextPartialResult)
    return SendablePublisher_<Publishers.TryScan<Upstream, T>>(_unverified_SendablePublisher__: scanned)
  }
  
  @export(implementation)
  public func reduce<T: Sendable>(_ initial: T, _ nextPartialResult: @Sendable @escaping (T, Output) -> T)
    -> SendablePublisher_<Publishers.Reduce<Upstream, T>> {
    let reduced = Publishers.Reduce(upstream: self._base, initial: initial, nextPartialResult: nextPartialResult)
    return SendablePublisher_<Publishers.Reduce<Upstream, T>>(_unverified_SendablePublisher__: reduced)
  }
  
  @export(implementation)
  public func tryReduce<T: Sendable>(_ initial: T, _ nextPartialResult: @Sendable @escaping (T, Output) throws -> T)
    -> SendablePublisher_<Publishers.TryReduce<Upstream, T>> {
    let reduced = Publishers.TryReduce(upstream: self._base, initial: initial, nextPartialResult: nextPartialResult)
    return SendablePublisher_<Publishers.TryReduce<Upstream, T>>(_unverified_SendablePublisher__: reduced)
  }
}
