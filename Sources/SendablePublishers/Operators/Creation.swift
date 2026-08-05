//
//  Creation.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

// MARK: - Creation Operators

extension SendableShell {
  @export(implementation)
  public static func empty(
    completeImmediately: Bool = true
  ) -> SendableShell<Empty<Output, Failure>> {
    let empty = Empty<Output, Failure>(completeImmediately: completeImmediately)
    return SendableShell<Empty<Output, Failure>>(_unverified_SendablePublisher__: empty)
  }
  
  @export(implementation)
  public static func just(_ output: Output) -> SendableShell<Just<Output>> where Failure == Never {
    let just = Just(output)
    return SendableShell<Just<Output>>(_unverified_SendablePublisher__: just)
  }
  
  @export(implementation)
  public static func fail(_ error: Failure)
    -> SendableShell<Fail<Output, Failure>> {
    let fail = Fail<Output, Failure>(outputType: Output.self, failure: error)
    return SendableShell<Fail<Output, Failure>>(_unverified_SendablePublisher__: fail)
  }
  
  @export(implementation)
  public static func deferred<P: Publisher & Sendable>(
    _ createPublisher: @Sendable @escaping () -> P
  ) -> SendableShell<Deferred<P>>
  where P.Output: Sendable, P.Failure == Failure {
    let deferred = Deferred(createPublisher: createPublisher)
    return SendableShell<Deferred<P>>(_unverified_SendablePublisher__: deferred)
  }
  
  @export(implementation)
  public static func sequence<S: Sequence & Sendable>(
    _ elements: S
  ) -> SendableShell<Publishers.Sequence<S, Failure>> where S.Element == Output, S.Element: Sendable {
    let sequence = Publishers.Sequence<S, Failure>(sequence: elements)
    return SendableShell<Publishers.Sequence<S, Failure>>(_unverified_SendablePublisher__: sequence)
  }
}

public import Foundation

extension SendableShell {
  @export(implementation)
  public static func timer(
    interval: TimeInterval,
    tolerance: TimeInterval? = nil,
    runLoop: RunLoop,
    mode: RunLoop.Mode = .default,
    options: RunLoop.SchedulerOptions? = nil,
  ) -> SendableShell<Timer.TimerPublisher>
    where Output == Date, Failure == Never {
    let timer = Timer.publish(every: interval, tolerance: tolerance, on: runLoop, in: mode, options: options)
    return SendableShell<Timer.TimerPublisher>(_unverified_SendablePublisher__: timer)
  }
}
