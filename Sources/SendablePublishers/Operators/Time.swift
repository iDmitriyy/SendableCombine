//
//  Time.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

// MARK: - TimeShifting

extension SendableShell {
  @export(implementation)
  public func delay<S: Scheduler>(for interval: S.SchedulerTimeType.Stride,
                                  tolerance: S.SchedulerTimeType.Stride? = nil,
                                  scheduler: S, options: S.SchedulerOptions? = nil)
    -> SendableShell<Publishers.Delay<Upstream, S>> {
    let delay = _base.delay(for: interval, scheduler: scheduler)
    return SendableShell<Publishers.Delay<Upstream, S>>(_unverified_SendablePublisher__: delay)
  }
}

// MARK: - Time-based Filtering

extension SendableShell {
  @export(implementation)
  public func debounce<S: Scheduler & Sendable>(
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> SendableShell<Publishers.Debounce<Upstream, S>> {
    let debounced = Publishers.Debounce(upstream: self._base, dueTime: dueTime, scheduler: scheduler, options: options)
    return SendableShell<Publishers.Debounce<Upstream, S>>(_unverified_SendablePublisher__: debounced)
  }
  
  @export(implementation)
  public func throttle<S: Scheduler & Sendable>(
    for interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    latest: Bool
  ) -> SendableShell<Publishers.Throttle<Upstream, S>> {
    let throttled = Publishers.Throttle(upstream: self._base, interval: interval, scheduler: scheduler, latest: latest)
    return SendableShell<Publishers.Throttle<Upstream, S>>(_unverified_SendablePublisher__: throttled)
  }
}

// MARK: - Timeout

extension SendableShell {
  @export(implementation)
  public func timeout<S: Scheduler & Sendable>(
    _ interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil,
    customError: @Sendable @escaping () -> Failure
  ) -> SendableShell<Publishers.Timeout<Upstream, S>> {
    let timeout = Publishers.Timeout(upstream: self._base,
                                     interval: interval,
                                     scheduler: scheduler,
                                     options: options,
                                     customError: customError)
    return SendableShell<Publishers.Timeout<Upstream, S>>(_unverified_SendablePublisher__: timeout)
  }
}

// MARK: - Others

extension SendableShell {
  @export(implementation)
  public func measureInterval<S: Scheduler & Sendable>(
    using scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> SendableShell<Publishers.MeasureInterval<Upstream, S>> {
    let measured = _base.measureInterval(using: scheduler, options: options)
    return SendableShell<Publishers.MeasureInterval<Upstream, S>>(_unverified_SendablePublisher__: measured)
  }
}

