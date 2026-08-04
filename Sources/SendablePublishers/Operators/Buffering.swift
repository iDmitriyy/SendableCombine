//
//  Buffering.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendablePublisher_ {
  @export(implementation)
  public func buffer(size: Int, prefetch: Publishers.PrefetchStrategy, whenFull: Publishers.BufferingStrategy<Self.Failure>)
    -> SendablePublisher_<Publishers.Buffer<Upstream>> {
    let buffer = Publishers.Buffer(upstream: self._base, size: size, prefetch: prefetch, whenFull: whenFull)
    return SendablePublisher_<Publishers.Buffer<Upstream>>(_unverified_SendablePublisher__: buffer)
  }
  
  @export(implementation)
  public func collect<S>(_ strategy: Publishers.TimeGroupingStrategy<S>, options: S.SchedulerOptions? = nil)
    -> SendablePublisher_<Publishers.CollectByTime<Upstream, S>>{
    let collected = Publishers.CollectByTime(upstream: _base, strategy: strategy, options: options)
    return SendablePublisher_<Publishers.CollectByTime<Upstream, S>>.init(_unverified_SendablePublisher__: collected)
  }
  
  @export(implementation)
  public func collect() -> SendablePublisher_<Publishers.Collect<Upstream>> {
    let collected = Publishers.Collect(upstream: self._base)
    return SendablePublisher_<Publishers.Collect<Upstream>>(_unverified_SendablePublisher__: collected)
  }
  
  @export(implementation)
  public func collect(_ count: Int) -> SendablePublisher_<Publishers.CollectByCount<Upstream>> {
    let collected = Publishers.CollectByCount(upstream: self._base, count: count)
    return SendablePublisher_<Publishers.CollectByCount<Upstream>>(_unverified_SendablePublisher__: collected)
  }
}

