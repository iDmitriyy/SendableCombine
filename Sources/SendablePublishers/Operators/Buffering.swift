//
//  Buffering.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendableShell {
  @export(implementation)
  public func buffer(size: Int, prefetch: Publishers.PrefetchStrategy, whenFull: Publishers.BufferingStrategy<Self.Failure>)
    -> SendableShell<Publishers.Buffer<Upstream>> {
    let buffer = Publishers.Buffer(upstream: _base, size: size, prefetch: prefetch, whenFull: whenFull)
    return SendableShell<Publishers.Buffer<Upstream>>(_unverified_SendablePublisher__: buffer)
  }

  @export(implementation)
  public func collect<S>(_ strategy: Publishers.TimeGroupingStrategy<S>, options: S.SchedulerOptions? = nil)
    -> SendableShell<Publishers.CollectByTime<Upstream, S>> {
    let collected = Publishers.CollectByTime(upstream: _base, strategy: strategy, options: options)
    return SendableShell<Publishers.CollectByTime<Upstream, S>>(_unverified_SendablePublisher__: collected)
  }

  @export(implementation)
  public func collect() -> SendableShell<Publishers.Collect<Upstream>> {
    let collected = Publishers.Collect(upstream: _base)
    return SendableShell<Publishers.Collect<Upstream>>(_unverified_SendablePublisher__: collected)
  }

  @export(implementation)
  public func collect(_ count: Int) -> SendableShell<Publishers.CollectByCount<Upstream>> {
    let collected = Publishers.CollectByCount(upstream: _base, count: count)
    return SendableShell<Publishers.CollectByCount<Upstream>>(_unverified_SendablePublisher__: collected)
  }
}
