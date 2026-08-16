//
//  Transforming.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func map<T: Sendable>(_ transform: @Sendable @escaping (Output) -> T) -> some Publisher<T, Failure> & Sendable {
    let mapped = Publishers.Map(upstream: self, transform: transform)
    return SendableShell<Publishers.Map<Self, T>>(_manuallyProven_Sendable__: mapped)
  }
  
  @export(implementation)
  public func tryMap<T: Sendable>(_ transform: @Sendable @escaping (Output) throws -> T)
  -> some Publisher<T, any Error> & Sendable {
    let mapped = Publishers.TryMap(upstream: self, transform: transform)
    return SendableShell<Publishers.TryMap<Self, T>>(_manuallyProven_Sendable__: mapped)
  }
  
  @export(implementation)
  public func compactMap<T: Sendable>(_ transform: @Sendable @escaping (Output) -> T?) -> some Publisher<T, Failure> & Sendable {
    let compactMapped = Publishers.CompactMap(upstream: self, transform: transform)
    return SendableShell<Publishers.CompactMap<Self, T>>(_manuallyProven_Sendable__: compactMapped)
  }
  
  @export(implementation)
  public func tryCompactMap<T: Sendable>(_ transform: @Sendable @escaping (Output) -> T?) -> some Publisher<T, any Error> & Sendable {
    let compactMapped = Publishers.TryCompactMap(upstream: self, transform: transform)
    return SendableShell<Publishers.TryCompactMap<Self, T>>(_manuallyProven_Sendable__: compactMapped)
  }
  
  @export(implementation)
  public func flatMap<P: Publisher & Sendable>(
    maxPublishers: Subscribers.Demand = .unlimited,
    _ transform: @Sendable @escaping (Output) -> P,
  ) -> some Publisher<P.Output, Failure> & Sendable where P.Failure == Failure, P.Output: Sendable {
    let flatMapped = Publishers.FlatMap(upstream: self, maxPublishers: maxPublishers, transform: transform)
    return SendableShell<Publishers.FlatMap<P, Self>>(_manuallyProven_Sendable__: flatMapped)
  }

  @export(implementation)
  public func switchToLatest<P: Publisher & Sendable>() -> some Publisher<P.Output, Failure> & Sendable
    where P == Self.Output, P.Failure == Self.Failure, P.Output: Sendable {
    let switched = Publishers.SwitchToLatest(upstream: self)
    return SendableShell<Publishers.SwitchToLatest<P, Self>>(_manuallyProven_Sendable__: switched)
  }
}
