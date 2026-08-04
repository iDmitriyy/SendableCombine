//
//  Transforming.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

extension SendablePublisher_ {
  @export(implementation)
  public func map<T>(_ transform: @Sendable @escaping (Output) -> T) -> SendablePublisher_<Publishers.Map<Upstream, T>> {
    let mapped = Publishers.Map(upstream: self._base, transform: transform)
    return SendablePublisher_<Publishers.Map<Upstream, T>>(_unverified_SendablePublisher__: mapped)
  }
  
  @export(implementation)
  public func tryMap<T>(_ transform: @Sendable @escaping (Output) throws -> T)
  -> SendablePublisher_<Publishers.TryMap<Upstream, T>> {
    let mapped = Publishers.TryMap(upstream: self._base, transform: transform)
    return SendablePublisher_<Publishers.TryMap<Upstream, T>>(_unverified_SendablePublisher__: mapped)
  }
  
  @export(implementation)
  public func compactMap<T>(_ transform: @Sendable @escaping (Output) -> T?) -> SendablePublisher_<Publishers.CompactMap<Upstream, T>> {
    let compactMapped = Publishers.CompactMap(upstream: self._base, transform: transform)
    return SendablePublisher_<Publishers.CompactMap<Upstream, T>>(_unverified_SendablePublisher__: compactMapped)
  }
  
  @export(implementation)
  public func tryCompactMap<T>(_ transform: @Sendable @escaping (Output) -> T?) -> SendablePublisher_<Publishers.TryCompactMap<Upstream, T>> {
    let compactMapped = Publishers.TryCompactMap(upstream: self._base, transform: transform)
    return SendablePublisher_<Publishers.TryCompactMap<Upstream, T>>(_unverified_SendablePublisher__: compactMapped)
  }
  
  @export(implementation)
  public func flatMap<P: Publisher & Sendable>(
    maxPublishers: Subscribers.Demand = .unlimited,
    _ transform: @Sendable @escaping (Output) -> P,
  ) -> SendablePublisher_<Publishers.FlatMap<P, Upstream>> where P.Failure == Failure, P.Output: Sendable {
    let flatMapped = Publishers.FlatMap(upstream: self._base, maxPublishers: maxPublishers, transform: transform)
    return SendablePublisher_<Publishers.FlatMap<P, Upstream>>(_unverified_SendablePublisher__: flatMapped)
  }

  @export(implementation)
  public func switchToLatest<P: Publisher & Sendable>() -> SendablePublisher_<Publishers.SwitchToLatest<P, Upstream>>
    where P == Upstream.Output, P.Failure == Upstream.Failure {
    let switched = Publishers.SwitchToLatest(upstream: self._base)
    return SendablePublisher_<Publishers.SwitchToLatest<P, Upstream>>(_unverified_SendablePublisher__: switched)
  }
}
