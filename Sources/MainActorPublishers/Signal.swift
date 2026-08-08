//
//  Signal.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine
import Foundation
import SendableCombineLogging

// MARK: - Core Signal Type

/// A shared, error-free publisher optimized for *UI events*.
///
/// `Signal` represents an infallible stream of elements designed for transient UI events —
/// user actions, notifications, navigation decisions. Like `Driver`, it
/// guarantees that values are observed on the main thread and shares a single upstream
/// connection among all active subscribers.
///
/// - Note: This publisher enforces four critical constraints:
///   1. **Infallible**: It cannot emit error termination signals (`Failure == Never`).
///   2. **Main Thread**: All downstream values are guaranteed to be observed on the main queue.
///   3. **Shared**: A single upstream connection is shared among all active subscribers.
///   4. **No Replay**: Unlike `Driver`, a `Signal` **does not** buffer or replay its latest
///      element. Events are delivered **only** to subscribers that are attached *at the moment*
///      an element is emitted. See "Sharing Semantics" below.
///
/// ### Semantic Differences from RxSwift.Signal
/// `RxSwift.Signal` is `RxCocoa`'s event-oriented counterpart to `Driver`:
/// - `Driver` replays its latest element to every new subscriber (state persistence).
/// - `Signal` forwards events **only while connected** and never replays (transient actions).
///
/// This type mirrors that contract in Combine:
/// * **Hot Stream & Lifecycle Semantics**: The stream connects to the upstream lazily, when the
///   very first subscriber attaches. The shared connection is torn down when the *last*
///   subscriber disconnects and is re-established from scratch when the subscriber count goes
///   from `0` back to `1`. Elements emitted during a subscriber-free window are lost.
/// * **Backpressure Compliance**: Unlike `RxSwift.Signal`, which pushes data unconditionally,
///   this `Signal` strictly respects Combine's `Subscribers.Demand` contract.
///
/// ### Sharing Semantics (3 examples)
/// * **Case 1**: Subscriber 1 attaches. Upstream emits `event`; Subscriber 1 receives it.
///   Subscriber 2 attaches afterwards and receives nothing.
/// * **Case 2**: Subscriber 1 attaches; Subscriber 2 attaches. Upstream emits `event`;
///   both Subscriber 1 and Subscriber 2 receive it.
/// * **Case 3**: No subscribers. Upstream emits `event` in a subscriber-free window — it is
///   lost. Subscriber 1 attaches immediately afterwards and receives nothing.
///
/// ### Diagnostic Logging & UI Lifecycle
/// Because a `Signal` is designed to continuously stream UI events, upstream termination — a
/// normal completion (`.finished`) or an unhandled failure (`.failure`) — is typically unexpected.
/// Once a terminal event occurs, the pipeline closes permanently, and subsequent subscribers
/// receive `.finished` immediately. To prevent these silent pipeline terminations during
/// development, every factory initializer / conversion includes an optional `logWhenTerminated`
/// parameter (enabled by default) that logs a diagnostic warning via `SendableCombineLogging`.
public struct Signal<Element: Sendable>: Publisher {
  @usableFromInline internal let _upstream: AnyPublisher<Element, Never>
}

// MARK: - Sendable

extension Signal: @unchecked Sendable where Element: Sendable {}

// MARK: - Publisher Conformance

extension Signal {
  public typealias Output = Element
  public typealias Failure = Never
  
  public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Element {
    _upstream.receive(subscriber: subscriber)
  }
}

// MARK: - MainActor observation

extension Signal where Element: Sendable {
  /// Subscribes a `@MainActor`-isolated receive closure.
  ///
  /// The Signal guarantees every element is delivered on the main thread (via `receive(on:)`).
  /// This method bridges that runtime guarantee into the compiler with `MainActor.assumeIsolated`,
  /// which traps only if the closure ever ran off the main thread.
  public func emit(receiveValue: @MainActor @Sendable @escaping (Self.Output) -> Void) -> AnyCancellable {
    _upstream.sink(receiveValue: { value in
      MainActor.assumeIsolated {
        receiveValue(value)
      }
    })
  }
}

// MARK: - as Publisher

extension Signal {
  public func asPublisher() -> AnyPublisher<Element, Never> {
    _upstream
  }
}

// MARK: - Common initializer

extension Signal {
  /// Creates a `Signal` from an infallible publisher, providing main-thread scheduling and
  /// subscriber-count-driven ("while connected") state sharing.
  ///
  /// This constructor sets up a shared, resource-efficient pipeline. The connection to the
  /// upstream happens **lazily**, only when the very first subscriber attaches, and is kept
  /// alive **only** while at least one subscriber remains. When the last subscriber cancels,
  /// the connection tears down; when a new subscriber arrives later, a fresh connection is
  /// established.
  ///
  /// * **Main Thread Guarantee**: Downstream observation is automatically constrained to the
  ///   main queue (`DispatchQueue.main`), ensuring thread safety for direct UI event binding.
  /// * **No Replay**: Consecutive attachments do not receive previously emitted events.
  /// * **Backpressure Compliance**: Data flow respects Combine's native demand
  ///   (`Subscribers.Demand`).
  ///
  /// - Parameters:
  ///   - infallibleUpstream: An existing publisher that is guaranteed never to fail (`Failure == Never`).
  ///   - logWhenTerminated: When `true` (default), logs upstream termination (`.finished` /
  ///     `.failure`) as a diagnostic warning; `false` disables the logging.
  public init<P: Publisher>(infallibleUpstream: P,
                            logWhenTerminated: Bool = true) where P.Output == Element, P.Failure == Never {
    _upstream = infallibleUpstream
      .handleEvents(receiveCompletion: { completion in
        _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
                                   publisherName: "Signal<\(Output.self)>",
                                   completion: completion)
      })
      .receive(on: DispatchQueue.main)
      .share()
      .eraseToAnyPublisher()
  }

  // MARK: - Init with Failable Publisher

  /// Creates a `Signal` from a failable publisher, silently dropping any generated errors.
  ///
  /// * **Error Swallowing**: If the upstream emits `.failure`, the error is dropped and the
  ///   stream permanently completes (no further events are delivered).
  /// * **Thread and Sharing Guarantees**: Shares a single main-thread connection and never
  ///   replays elements.
  /// * **Diagnostics**: Termination (`.finished` or `.failure`) is logged by default through
  ///   `logWhenTerminated`.
  ///
  /// - Parameters:
  ///   - failableUpstream: An arbitrary publisher whose `Output` matches this `Signal`'s.
  ///   - logWhenTerminated: When `true` (default), logs a diagnostic warning on termination.
//  public init<P: Publisher>(failableUpstream: P,
//                            logWhenTerminated: Bool = true) where P.Output == Element {
//    _upstream = failableUpstream
//      .handleEvents(receiveCompletion: { completion in
//        _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
//                                   publisherName: "Signal<\(Output.self)>",
//                                   completion: completion)
//      })
//      .catch { _ in Empty<Element, Never>() }
//      .receive(on: DispatchQueue.main)
//      .share()
//      .eraseToAnyPublisher()
//  }

  // MARK: - Init with Failable Publisher + Recovery

  /// Creates a `Signal` from a failable publisher, recovering from errors with a fallback event.
  ///
  /// When the upstream emits an error, the `catchError` closure computes a fallback `Output`
  /// that is forwarded downstream (so the UI receives an explicit "error event"), after which
  /// the stream terminates permanently. Elements are **not** replayed to any new subscriber.
  ///
  /// - Parameters:
  ///   - failableUpstream: An arbitrary publisher that may fail.
  ///   - catchError: A `@Sendable` closure invoked to transform an upstream `Failure` into a
  ///     safe fallback `Output` element.
  ///   - logWhenTerminated: When `true` (default), logs a diagnostic warning on termination.
//  public init<P: Publisher>(failableUpstream: P,
//                            catchError: @Sendable @escaping () -> Output,
//                            logWhenTerminated: Bool = true) where P.Output == Element {
//    _upstream = failableUpstream
//      .handleEvents(receiveCompletion: { completion in
//        _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
//                                   publisherName: "Signal<\(Output.self)>",
//                                   completion: completion)
//      })
//      .catch { _ in Just(catchError()) }
//      .receive(on: DispatchQueue.main)
//      .share()
//      .eraseToAnyPublisher()
//  }
}

// MARK: - Publisher as Signal (Infallible)

extension Publisher where Failure == Never, Output: Sendable {
  /// Transforms an infallible publisher into a `Signal`.
  ///
  /// Use this operator when upstream is guaranteed never to fail and is
  /// intended for UI events. The resulting `Signal` is shared among subscribers.
  ///
  /// - Parameter logWhenTerminated: When `true` (default), logs upstream termination as a
  ///   diagnostic warning.
  public func asSignal(logWhenTerminated: Bool = true) -> Signal<Output> {
    Signal(infallibleUpstream: self, logWhenTerminated: logWhenTerminated)
  }
}

// MARK: - Publisher as Signal (Failable)

extension Publisher where Output: Sendable {
  /// Transforms a failable publisher into a `Signal`, dropping any generated errors silently.
  public func asSignalIgnoringError(logWhenTerminated: Bool = true) -> Signal<Output> {
    let processed = handleEvents(receiveCompletion: { completion in
      _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
                                 publisherName: "Signal<\(Output.self)>",
                                 completion: completion)
    })
    .catch { _ in Empty<Output, Never>() }
    
    return Signal(infallibleUpstream: processed, logWhenTerminated: false)
  }

  /// Transforms a failable publisher into a `Signal`, recovering from errors with a fallback event.
  public func asSignal(catchError: @Sendable @escaping () -> Output,
                       logWhenTerminated: Bool = true) -> Signal<Output> {
    let processed = handleEvents(receiveCompletion: { completion in
      _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
                                 publisherName: "Signal<\(Output.self)>",
                                 completion: completion)
    })
    .catch { _ in Just(catchError()) }
    
    return Signal(infallibleUpstream: processed, logWhenTerminated: false)
  }
}
