//
//  Buffering.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func buffer(size: Int, prefetch: Publishers.PrefetchStrategy, whenFull: Publishers.BufferingStrategy<Self.Failure>)
    -> some Publisher<Output, Failure> & Sendable {
    let buffer = Publishers.Buffer(upstream: self, size: size, prefetch: prefetch, whenFull: whenFull)
    return SendableShell<Publishers.Buffer<Self>>(_manuallyProven_Sendable__: buffer)
  }

  @export(implementation)
  public func collect<S>(_ strategy: Publishers.TimeGroupingStrategy<S>, options: S.SchedulerOptions? = nil)
    -> some Publisher<[Output], Failure> & Sendable {
    let collected = Publishers.CollectByTime(upstream: self, strategy: strategy, options: options)
    return SendableShell<Publishers.CollectByTime<Self, S>>(_manuallyProven_Sendable__: collected)
  }

  @export(implementation)
  public func collect() -> some Publisher<[Output], Failure> & Sendable {
    let collected = Publishers.Collect(upstream: self)
    return SendableShell<Publishers.Collect<Self>>(_manuallyProven_Sendable__: collected)
  }

  @export(implementation)
  public func collect(_ count: Int) -> some Publisher<[Output], Failure> & Sendable {
    let collected = Publishers.CollectByCount(upstream: self, count: count)
    return SendableShell<Publishers.CollectByCount<Self>>(_manuallyProven_Sendable__: collected)
  }
}
