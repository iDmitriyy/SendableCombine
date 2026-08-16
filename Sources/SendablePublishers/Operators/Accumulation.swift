//
//  Accumulation.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

// MARK: - Accumulation

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func scan<T: Sendable>(_ initial: T, _ nextPartialResult: @Sendable @escaping (T, Output) -> T)
    -> some Publisher<T, Failure> & Sendable {
    let scanned = Publishers.Scan(upstream: self, initialResult: initial, nextPartialResult: nextPartialResult)
    return SendableShell<Publishers.Scan<Self, T>>(_manuallyProven_Sendable__: scanned)
  }

  @export(implementation)
  public func tryScan<T: Sendable>(_ initial: T, _ nextPartialResult: @Sendable @escaping (T, Output) throws -> T)
    -> some Publisher<T, any Error> & Sendable {
    let scanned = Publishers.TryScan(upstream: self, initialResult: initial, nextPartialResult: nextPartialResult)
    return SendableShell<Publishers.TryScan<Self, T>>(_manuallyProven_Sendable__: scanned)
  }

  @export(implementation)
  public func reduce<T: Sendable>(_ initial: T, _ nextPartialResult: @Sendable @escaping (T, Output) -> T)
    -> some Publisher<T, Failure> & Sendable {
    let reduced = Publishers.Reduce(upstream: self, initial: initial, nextPartialResult: nextPartialResult)
    return SendableShell<Publishers.Reduce<Self, T>>(_manuallyProven_Sendable__: reduced)
  }

  @export(implementation)
  public func tryReduce<T: Sendable>(_ initial: T, _ nextPartialResult: @Sendable @escaping (T, Output) throws -> T)
    -> some Publisher<T, any Error> & Sendable {
    let reduced = Publishers.TryReduce(upstream: self, initial: initial, nextPartialResult: nextPartialResult)
    return SendableShell<Publishers.TryReduce<Self, T>>(_manuallyProven_Sendable__: reduced)
  }
}
