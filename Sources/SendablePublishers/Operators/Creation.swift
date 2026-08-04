//
//  Creation.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

// MARK: - asSendablePublisher extensions

extension PassthroughSubject where Output: Sendable {
  @export(implementation)
  public func asSendablePublisher() -> SendablePublisher_<PassthroughSubject<Output, Failure>> {
    SendablePublisher_(_unverified_SendablePublisher__: self)
  }
}

extension CurrentValueSubject where Output: Sendable {
  @export(implementation)
  public func asSendablePublisher() -> SendablePublisher_<CurrentValueSubject<Output, Failure>> {
    SendablePublisher_(_unverified_SendablePublisher__: self)
  }
}

// MARK: - Creation Operators

extension SendablePublisher_ {
  @export(implementation)
  public static func empty(
    completeImmediately: Bool = true
  ) -> SendablePublisher_<Empty<Output, Failure>> {
    let empty = Empty<Output, Failure>(completeImmediately: completeImmediately)
    return SendablePublisher_<Empty<Output, Failure>>(_unverified_SendablePublisher__: empty)
  }
  
  @export(implementation)
  public static func just(_ output: Output) -> SendablePublisher_<Just<Output>> where Failure == Never {
    let just = Just(output)
    return SendablePublisher_<Just<Output>>(_unverified_SendablePublisher__: just)
  }
  
  @export(implementation)
  public static func fail(_ error: Failure)
    -> SendablePublisher_<Fail<Output, Failure>> {
    let fail = Fail<Output, Failure>(outputType: Output.self, failure: error)
    return SendablePublisher_<Fail<Output, Failure>>(_unverified_SendablePublisher__: fail)
  }
  
  @export(implementation)
  public static func deferred<P: Publisher & Sendable>(
    _ createPublisher: @Sendable @escaping () -> P
  ) -> SendablePublisher_<Deferred<P>>
  where P.Output: Sendable, P.Failure == Failure {
    let deferred = Deferred(createPublisher: createPublisher)
    return SendablePublisher_<Deferred<P>>(_unverified_SendablePublisher__: deferred)
  }
  
  @export(implementation)
  public static func sequence<S: Sequence & Sendable>(
    _ elements: S
  ) -> SendablePublisher_<Publishers.Sequence<S, Failure>> where S.Element == Output, S.Element: Sendable {
    let sequence = Publishers.Sequence<S, Failure>(sequence: elements)
    return SendablePublisher_<Publishers.Sequence<S, Failure>>(_unverified_SendablePublisher__: sequence)
  }
}

public import Foundation

extension SendablePublisher_ {
  @export(implementation)
  public static func timer(
    interval: TimeInterval,
    tolerance: TimeInterval? = nil,
    runLoop: RunLoop,
    mode: RunLoop.Mode = .default,
    options: RunLoop.SchedulerOptions? = nil,
  ) -> SendablePublisher_<Timer.TimerPublisher>
    where Output == Date, Failure == Never {
    let timer = Timer.publish(every: interval, tolerance: tolerance, on: runLoop, in: mode, options: options)
    return SendablePublisher_<Timer.TimerPublisher>(_unverified_SendablePublisher__: timer)
  }
}
