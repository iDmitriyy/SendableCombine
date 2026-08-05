//
//  Scheduling.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendableShell {
  @export(implementation)
  public func receive<S: Scheduler & Sendable>(
    on scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> SendableShell<Publishers.ReceiveOn<Upstream, S>> {
    let received = Publishers.ReceiveOn(upstream: self._base, scheduler: scheduler, options: options)
    return SendableShell<Publishers.ReceiveOn<Upstream, S>>(_unverified_SendablePublisher__: received)
  }
  
  @export(implementation)
  public func subscribe<S: Scheduler & Sendable>(on scheduler: S,
                                                 options: S.SchedulerOptions? = nil)
    -> SendableShell<Publishers.SubscribeOn<Upstream, S>> {
    let subscribed = Publishers.SubscribeOn(upstream: self._base, scheduler: scheduler, options: options)
    return SendableShell<Publishers.SubscribeOn<Upstream, S>>(_unverified_SendablePublisher__: subscribed)
  }
}
