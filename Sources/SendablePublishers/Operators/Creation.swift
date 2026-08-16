//
//  Creation.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

// MARK: - Creation Operators

public enum SendablePublishersCreation {
  @export(implementation)
  public static func empty<Output: Sendable, Failure: Error>(
    completeImmediately: Bool = true,
  ) -> some Publisher<Output, Failure> & Sendable {
    let empty = Empty<Output, Failure>(completeImmediately: completeImmediately)
    return SendableShell<Empty<Output, Failure>>(_manuallyProven_Sendable__: empty)
  }

  @export(implementation)
  public static func just<Output: Sendable>(_ output: Output) -> some Publisher<Output, Never> & Sendable {
    let just = Just(output)
    return SendableShell<Just<Output>>(_manuallyProven_Sendable__: just)
  }

  @export(implementation)
  public static func fail<Output: Sendable, Failure: Error>(_ error: Failure)
    -> some Publisher<Output, Failure> & Sendable {
    let fail = Fail<Output, Failure>(outputType: Output.self, failure: error)
    return SendableShell<Fail<Output, Failure>>(_manuallyProven_Sendable__: fail)
  }

  @export(implementation)
  public static func deferred<P: Publisher & Sendable>(
    _ createPublisher: @Sendable @escaping () -> P,
  ) -> some Publisher<P.Output, P.Failure> & Sendable
    where P.Output: Sendable {
    let deferred = Deferred(createPublisher: createPublisher)
    return SendableShell<Deferred<P>>(_manuallyProven_Sendable__: deferred)
  }

  @export(implementation)
  public static func sequence<S: Sequence & Sendable, Failure: Error>(
    _ elements: S,
  ) -> some Publisher<S.Element, Failure> & Sendable where S.Element: Sendable {
    let sequence = Publishers.Sequence<S, Failure>(sequence: elements)
    return SendableShell<Publishers.Sequence<S, Failure>>(_manuallyProven_Sendable__: sequence)
  }
}

public import Foundation

extension SendablePublishersCreation {
  @export(implementation)
  public static func timer(
    interval: TimeInterval,
    tolerance: TimeInterval? = nil,
    runLoop: RunLoop,
    mode: RunLoop.Mode = .default,
    options: RunLoop.SchedulerOptions? = nil,
  ) -> some Publisher<Date, Never> & Sendable {
    let timer = Timer.publish(every: interval, tolerance: tolerance, on: runLoop, in: mode, options: options)
    return SendableShell<Timer.TimerPublisher>(_manuallyProven_Sendable__: timer)
  }
}
