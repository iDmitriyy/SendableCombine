//
//  Scheduling.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func receive<S: Scheduler & Sendable>(
    on scheduler: S,
    options: S.SchedulerOptions? = nil,
  ) -> some Publisher<Output, Failure> & Sendable {
    let received = Publishers.ReceiveOn(upstream: self, scheduler: scheduler, options: options)
    return SendableShell<Publishers.ReceiveOn<Self, S>>(_manuallyProven_Sendable__: received)
  }

  @export(implementation)
  public func subscribe<S: Scheduler & Sendable>(on scheduler: S,
                                                 options: S.SchedulerOptions? = nil)
    -> some Publisher<Output, Failure> & Sendable {
    let subscribed = Publishers.SubscribeOn(upstream: self, scheduler: scheduler, options: options)
    return SendableShell<Publishers.SubscribeOn<Self, S>>(_manuallyProven_Sendable__: subscribed)
  }
}
