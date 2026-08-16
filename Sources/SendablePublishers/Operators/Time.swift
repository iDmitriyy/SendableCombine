//
//  Time.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

// MARK: - TimeShifting

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func delay<S: Scheduler>(for interval: S.SchedulerTimeType.Stride,
                                  tolerance: S.SchedulerTimeType.Stride? = nil,
                                  scheduler: S, options: S.SchedulerOptions? = nil)
    -> some Publisher<Output, Failure> & Sendable {
    let delay = self.Combine::delay(for: interval, scheduler: scheduler)
    return SendableShell<Publishers.Delay<Self, S>>(_manuallyProven_Sendable__: delay)
  }
}

// MARK: - Time-based Filtering

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func debounce<S: Scheduler & Sendable>(
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> some Publisher<Output, Failure> & Sendable {
    let debounced = Publishers.Debounce(upstream: self, dueTime: dueTime, scheduler: scheduler, options: options)
    return SendableShell<Publishers.Debounce<Self, S>>(_manuallyProven_Sendable__: debounced)
  }

  @export(implementation)
  public func throttle<S: Scheduler & Sendable>(
    for interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    latest: Bool
  ) -> some Publisher<Output, Failure> & Sendable {
    let throttled = Publishers.Throttle(upstream: self, interval: interval, scheduler: scheduler, latest: latest)
    return SendableShell<Publishers.Throttle<Self, S>>(_manuallyProven_Sendable__: throttled)
  }
}

// MARK: - Timeout

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func timeout<S: Scheduler & Sendable>(
    _ interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil,
    customError: @Sendable @escaping () -> Failure
  ) -> some Publisher<Output, Failure> & Sendable {
    let timeout = Publishers.Timeout(upstream: self,
                                     interval: interval,
                                     scheduler: scheduler,
                                     options: options,
                                     customError: customError)
    return SendableShell<Publishers.Timeout<Self, S>>(_manuallyProven_Sendable__: timeout)
  }
}

// MARK: - Others

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func measureInterval<S: Scheduler & Sendable>(
    using scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> some Publisher<S.SchedulerTimeType.Stride, Failure> & Sendable where S.SchedulerTimeType.Stride: Sendable {
    let measured = self.Combine::measureInterval(using: scheduler, options: options)
    return SendableShell<Publishers.MeasureInterval<Self, S>>(_manuallyProven_Sendable__: measured)
  }
}
