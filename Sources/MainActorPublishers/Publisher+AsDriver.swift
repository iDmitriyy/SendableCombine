//
//  Publisher+AsDriver.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 27.09.2026.
//

public import Combine
import Foundation
import SendablePublishers

// MARK: - CurrentValueSubject as Driver

extension CurrentValueSubject where Failure == Never, Output: Sendable {
  /// Converts an existing `CurrentValueSubject` directly into a `Driver` wrapper.
  ///
  /// This transformation provides a highly performant way to expose an existing stateful subject
  /// to the user interface. Because a `CurrentValueSubject` is already an active, thread-safe,
  /// state-holding source, it requires no lazy deferred wrappers.
  ///
  /// * **Main Thread Guarantee**: To ensure safety for UI bindings, the resulting stream is
  ///   explicitly scheduled to emit all events on the main execution context (`DispatchQueue.main`).
  /// * **State Preservation**: The driver inherits the current value of the subject at the moment
  ///   of subscription and instantly streams any subsequent state modifications.
  ///
  /// - Parameter logWhenTerminated: When `true` (default), logs upstream termination (`.finished` /
  ///   `.failure`) as a diagnostic warning; `false` disables the logging.
  /// - Returns: A `Driver` instance.
  public func asDriver(logWhenTerminated: Bool = true) -> Driver<Output> {
    if logWhenTerminated {
      let upstream = handleEvents(receiveCompletion: { completion in
        _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
                                  sharedPublisherName: "Driver<\(Output.self)>",
                                  completion: completion)
      })
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
      return Driver(_unchecked_HotUpstream: upstream)
    } else {
      let upstream = receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
      return Driver(_unchecked_HotUpstream: upstream)
    }
  }
}

// MARK: - Publisher as Driver (Infallible)

extension Publisher where Failure == Never, Output: Sendable {
  /// Transforms an infallible publisher into a `Driver`.
  ///
  /// Use this operator when your upstream data source is already guaranteed never to fail
  /// (e.g., after explicit error handling or state mapping) and needs to be prepared for UI binding.
  ///
  /// * **Main Thread Guarantee**: Downstream observation is automatically constrained to the main queue.
  /// * **Lazy Replay Bridge**: The underlying connection to the upstream is delayed until the first
  ///   subscriber connects. From that point forward, the stream becomes a shared **hot** pipeline that
  ///   buffers and replays the latest state to any new subscriber.
  ///
  /// - Parameter initialValue: The default baseline element sent upon subscription
  ///   if the upstream has not emitted any data yet.
  /// - Returns: A `Driver` instance.
  public func asDriver(initialValue: Output, logWhenTerminated: Bool = true) -> Driver<Output> {
    Driver(infallibleUpstream: self, initialValue: initialValue, logWhenTerminated: logWhenTerminated)
  }
}

// MARK: - Publisher as Driver (Failable)

extension Publisher where Output: Sendable {
  /// Transforms a failable publisher into a driver stream by dropping any generated errors silently.
  ///
  /// This operator is designed for non-critical UI updates where an error condition should simply
  /// cause the stream to halt gracefully without disrupting the user interface.
  ///
  /// * **Error Swallowing Semantics**: If an error is intercepted from the upstream, the failure signal
  ///   is dropped, and the stream gracefully terminates (completing the downstream pipeline). No further
  ///   values will be emitted, but the last cached value remains available to any new subscriber.
  /// * **Thread and Replay Guarantees**: Shares a single main-thread connection and synchronously
  ///   replays either the `initialValue` or the most recent successful emission.
  ///
  /// - Parameter initialValue: The default state element transmitted synchronously upon subscriber connection
  ///   if the upstream hasn't emitted anything.
  /// - Returns: A `Driver` instance.
  public func asDriverIgnoringError(initialValue: Output, logWhenTerminated: Bool = true) -> Driver<Output> {
    func makeDriver(failableSource: some Publisher<Output, Failure>) -> Driver<Output> {
      let infallible = failableSource.catch { _ in Empty<Output, Never>() }
      return Driver(infallibleUpstream: infallible, initialValue: initialValue, logWhenTerminated: false)
    }

    if logWhenTerminated {
      let withTerminationDiagnostic = handleEvents(receiveCompletion: { completion in
        _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
                                  sharedPublisherName: "Driver<\(Output.self)>",
                                  completion: completion)
      })
      return makeDriver(failableSource: withTerminationDiagnostic)
    } else {
      return makeDriver(failableSource: self)
    }
  }

  /// Transforms a failable publisher into a driver stream, recovering from errors with a fallback state mapping.
  ///
  /// Use this operator when an upstream failure must be explicitly handled by providing a meaningful
  /// default or error-state value to the user interface, allowing the stream to remain functionally alive.
  ///
  /// * **Error Recovery Semantics**: When an upstream error occurs, the provided `catchError` closure is
  ///   invoked to compute a fallback element. This fallback value is immediately pushed downstream,
  ///   after which the stream terminates gracefully. The recovery value becomes the new cached state
  ///   and will be replayed to any new subscriber who connects later.
  /// * **Thread and Replay Guarantees**: Maintains strict main-thread delivery and synchronizes state
  ///   sharing across multiple UI components.
  ///
  /// - Parameters:
  ///   - initialValue: The default state element transmitted synchronously upon subscriber connection
  ///     if the upstream hasn't emitted anything.
  ///   - catchError: A thread-safe, `@Sendable` closure invoked to transform an upstream `Failure`
  ///     into a safe fallback `Output` element.
  /// - Returns: A `Driver` instance that emits a fallback value upon error.
  public func asDriver(initialValue: Output,
                       logWhenTerminated: Bool = true,
                       catchError: @Sendable @escaping (Failure) -> Output) -> Driver<Output> {
    func makeDriver(failableSource: some Publisher<Output, Failure>) -> Driver<Output> {
      let infallible = failableSource.catch { failure in Just(catchError(failure)) }
      return Driver(infallibleUpstream: infallible, initialValue: initialValue, logWhenTerminated: false)
    }

    if logWhenTerminated {
      let withTerminationDiagnostic = handleEvents(receiveCompletion: { completion in
        _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
                                  sharedPublisherName: "Driver<\(Output.self)>",
                                  completion: completion)
      })
      return makeDriver(failableSource: withTerminationDiagnostic)
    } else {
      return makeDriver(failableSource: self)
    }
  }
}
