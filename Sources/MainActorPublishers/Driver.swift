//
//  Driver.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine
import os
import SendableCombineLogging

// MARK: - Core Driver3 Type

/// A shared, error-free publisher optimized for driving UI.
///
/// `Driver` represents an infallible stream of elements designed specifically to bind
/// directly to UI components. It guarantees that values are observed on the main thread
/// and ensures that any new subscriber immediately retrieves the current state of the stream.
///
/// - Note: This publisher enforces three critical constraints:
///   1. **Infallible**: It cannot emit error termination signals (`Failure == Never`).
///   2. **Main Thread**: All downstream values are guaranteed to be observed on the main queue.
///   3. **Replay**: Replays the latest element upon subscription:
///   either the `initialValue` if no data has arrived yet from upstream, or the most recent upstream emission.
///
/// ### Semantic Differences from RxSwift.Driver
/// While this structure serves the same functional purpose as its `RxSwift` counterpart, it introduces the following behavioral shifts:
/// * **Hot Stream & Lifecycle Semantics**: This stream behaves as a lazy "hot" publisher. It connects to the upstream exactly once when
/// the first consumer subscribes.
/// Crucially, unlike `RxSwift.Driver`, which tears down its connection and clears its cache when the last subscriber disconnects,
/// this implementation keeps the upstream connection active and continuously buffers new values to replay the latest one to any new subscriber,
/// even during periods with zero active consumers.
/// * **Backpressure Compliance**: Unlike `RxSwift.Driver`, which pushes data unconditionally, this `Driver` strictly respects
/// Apple Combine's `Subscribers.Demand` contract. Data flow is throttled natively according to consumer consumption speeds.
///
/// ### Replay Semantics (3 examples)
/// * **Case 1**: Subscriber 1 receives `initialValue`. Upstream generates no events. Subscriber 2 appears and also receives `initialValue`.
/// * **Case 2**: Subscriber 1 receives `initialValue`. Then upstream emits `nextValue`, and Subscriber 1 receives `nextValue`.
/// Subscriber 2 appears and receives `nextValue`.
/// * **Case 3**: `Driver` is created with `initialValue`. While there are no subscribers yet, upstream emits `nextValue`.
/// Subscriber 1 appears and receives `nextValue`.
/// Subscriber 2 appears and receives `nextValue`.
///
/// ### Diagnostic Logging & UI Lifecycle
/// Because a `Driver` is designed to continuously stream data to UI, any upstream termination, whether a normal completion (`.finished`)
/// or an unhandled failure (`.failure`), is typically unexpected.
/// Once a terminal event occurs, the reactive pipeline closes permanently, leaving UI components holding their last received state
/// without any further updates.
/// To prevent these silent pipeline terminations during development, failable factory initializers include an optional `logWhenTerminated`
/// parameter (enabled by default). When active, it intercepts the stream's completion signals and logs a diagnostic warning,
/// ensuring visibility into unexpected pipeline terminations.
public struct Driver<Element: Sendable> {
  @usableFromInline internal let _upstream: AnyPublisher<Element, Never>
  
  init(_upstream: AnyPublisher<Element, Never>) {
    self._upstream = _upstream
  }
} // FXIME: .onCompleted ?

// MARK: - Publisher Conformance

extension Driver: Publisher {
  public typealias Output = Element
  public typealias Failure = Never

  @inlinable
  public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Output {
    _upstream.receive(subscriber: subscriber)
  }
}

// MARK: - Sendable

extension Driver: @unchecked Sendable {}

// MARK: - Factory Initializers

extension Driver {
  private typealias SharedState = (publisher: AnyPublisher<Element, Never>?, cancellable: (any Cancellable)?)

  // MARK: - Init with Infallible Publisher
  
  /// Creates a `Driver` from an infallible publisher, providing explicit main-thread scheduling and state sharing.
  ///
  /// This constructor sets up a shared, resource-efficient pipeline where the actual connection to the
  /// upstream occurs **lazily**. The subscription is deferred and triggered only when the very first
  /// subscriber connects to the `Driver`. From that point forward, a single upstream connection is
  /// shared across all consumers.
  ///
  /// * **Main Thread Guarantee**: Downstream observation is automatically constrained to the main queue
  ///   (`DispatchQueue.main`), ensuring thread safety for direct UI data binding.
  /// * **Backpressure Compliance**: Data flow respects Combine's native demand contract (`Subscribers.Demand`).
  ///   The underlying shared buffer regulates demand tokens dynamically down to each individual subscriber.
  /// * **State Replay**: Synchronously replays the latest state upon subscription: either the `initialValue`
  ///   if no data has arrived yet, or the most recent upstream emission.
  ///
  /// - Parameters:
  ///   - infallibleUpstream: An existing publisher that is guaranteed never to emit failures (`Failure == Never`).
  ///   - initialValue: The default baseline element emitted upon subscription if the upstream hasn't emitted anything.
  public init<P: Publisher>(infallibleUpstream: P,
                            initialValue: Element,
                            logWhenTerminated: Bool)
    where P.Output == Element, P.Failure == Never {
    let lock = OSAllocatedUnfairLock<SharedState>(uncheckedState: (publisher: nil, cancellable: nil))
    
    let lazyPublisher = Deferred {
      lock.withLockUnchecked { state in
        if let existing = state.publisher {
          return existing
        }
        
        /// 1. CurrentValueSubject acts as an internal state buffer.
        /// It inherently preserves the backpressure contract: it requests .unlimited from the upstream
        /// and safely relays individual downstream Demand to its active subscribers.
        let bufferSubject = CurrentValueSubject<Element, Never>(initialValue)
        
        /// 2. Multicast bridges the upstream to the buffer subject.
        /// This ensures the upstream is shared and subscribed to exactly ONCE (subscriptionCount == 1).
        let connectable = infallibleUpstream
          .handleEvents(receiveCompletion: { completion in
            Self.logTerminationDiagnostic(logWhenTerminated: logWhenTerminated, completion: completion)
          })
          .receive(on: DispatchQueue.main)
          .multicast(subject: bufferSubject)
        
        // 3. Atomically connect to the upstream. Demand tracking flows natively via internal Combine mechanisms.
        state.cancellable = connectable.connect()
        
        let shared = connectable.eraseToAnyPublisher()
        state.publisher = shared
        return shared
      }
    }
    
    self._upstream = lazyPublisher.eraseToAnyPublisher()
  }

  // MARK: - Init with Infallible Publisher + Diagnostic Logging

  /// Creates a `Driver` from an infallible publisher, same as `init(infallibleUpstream:initialValue:)`,
  /// but additionally logs a diagnostic when the `initialValue` is silently dropped.
  ///
  /// The `initialValue` is dropped when the upstream gets connected (inside a `Deferred` block) before the
  /// first downstream subscriber attaches: a hot or replay(1) source (`CurrentValueSubject`, `@Published`,
  /// `Just`, ...) synchronously emits during `connect()`, replacing the buffer's `initialValue` so it is
  /// never delivered.
  ///
  /// This variant detects the drop with a lightweight `handleEvents(receiveOutput:)` tap placed **before**
  /// `.receive(on: DispatchQueue.main)` — the tap fires synchronously at connection time, when no subscriber
  /// exists yet — and logs once via the `SendableCombineLogging` observer. It requires no extra `Subject` and no value equality checks.
  ///
  /// - Parameters:
  ///   - infallibleUpstream2: An existing publisher that is guaranteed never to emit failures (`Failure == Never`).
  ///   - initialValue: The default baseline element emitted upon subscription if the upstream hasn't emitted anything.
  ///   - logWhenInitialValueDropped: When `true` (default), logs the dropped-initialValue diagnostic once.
  public init<P: Publisher>(infallibleUpstream2: P,
                            initialValue: Element,
                            logWhenInitialValueDropped: Bool) where P.Output == Element, P.Failure == Never {
    self._upstream = Self.makeLazyInfallibleDriver(
      infallibleUpstream2,
      initialValue: initialValue,
      logWhenInitialValueDropped: logWhenInitialValueDropped
    )
  }

  /// Builds the lazily-connected, shared pipeline for `init(infallibleUpstream2:initialValue:logWhenInitialValueDropped:)`.
  ///
  /// Kept as a `static` function so the escaping operator closures are not created directly inside the struct's
  /// initializer (the Swift compiler rejects escaping closures capturing a partially-initialized struct value
  /// during code generation for a `Publisher`-conforming type).
  private static func makeLazyInfallibleDriver<P>(_ infallibleUpstream: P,
                                                  initialValue: Element,
                                                  logWhenInitialValueDropped: Bool)
    -> AnyPublisher<Element, Never> where P: Publisher, P.Output == Element, P.Failure == Never {
    let lock = OSAllocatedUnfairLock<SharedState>(uncheckedState: (publisher: nil, cancellable: nil))

    /// Tiny shared signal only allocated when diagnostic logging is enabled.
    let dropLock = logWhenInitialValueDropped
      ? OSAllocatedUnfairLock<(hasSubscriber: Bool, didLog: Bool)>(uncheckedState: (hasSubscriber: false, didLog: false))
      : nil

    let lazyPublisher = Deferred {
      lock.withLockUnchecked { state in
        if let existing = state.publisher {
          return existing
        }

        let bufferSubject = CurrentValueSubject<Element, Never>(initialValue)

        let connectable = infallibleUpstream
          .handleEvents(receiveOutput: { value in
            guard logWhenInitialValueDropped, let dropLock else { return }
            let shouldLog = dropLock.withLock { signals in
              guard !signals.didLog, !signals.hasSubscriber else { return false }
              signals.didLog = true
              return true
            }
            if shouldLog {
              _log(.warning, SendableCombineLogEntry(
                code: .driverInitialValueDropped,
                message: "The initialValue (\(initialValue)) was dropped: the upstream emitted \(value) before the first subscriber attached (the upstream behaves like a hot observable or a replay(1) source). If the upstream is a CurrentValueSubject, prefer the no-argument asDriver(), which replays the subject's current value without an initialValue. If this behaviour is expected, pass logWhenInitialValueDropped: false."
              ))
            }
          })
          .receive(on: DispatchQueue.main)
          .multicast(subject: bufferSubject)

        state.cancellable = connectable.connect()

        let shared = connectable
          .handleEvents(receiveSubscription: { _ in
            dropLock?.withLock { signals in
              signals.hasSubscriber = true
            }
          })
          .eraseToAnyPublisher()

        state.publisher = shared
        return shared
      }
    }

    return lazyPublisher.eraseToAnyPublisher()
  }
}

// MARK: - Extension for CurrentValueSubject

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
  /// - Returns: A `Driver` instance.
  public func asDriver() -> Driver<Output> {
    let upstream = self
      .handleEvents(receiveCompletion: { completion in
        Driver<Output>.logTerminationDiagnostic(logWhenTerminated: true, completion: completion)
      })
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
    return Driver(_upstream: upstream)
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
  public func asDriver(initialValue: Output) -> Driver<Output> {
    Driver(infallibleUpstream: self, initialValue: initialValue, logWhenTerminated: true)
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
    let processed = self
      .handleEvents(receiveCompletion: { completion in
        Driver<Output>.logTerminationDiagnostic(logWhenTerminated: logWhenTerminated, completion: completion)
      })
      .catch { _ in Empty<Output, Never>() }

    return Driver(infallibleUpstream: processed, initialValue: initialValue, logWhenTerminated: false)
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
    let processed = self
      .handleEvents(receiveCompletion: { completion in
        Driver<Output>.logTerminationDiagnostic(logWhenTerminated: logWhenTerminated, completion: completion)
      })
      .catch { failure in Just(catchError(failure)) }
    
    return Driver(infallibleUpstream: processed, initialValue: initialValue, logWhenTerminated: false)
  }
}

// MARK: - Termination Diagnostic

extension Driver {
  /// Logs a diagnostic warning when the upstream terminates, so a silent pipeline termination
  /// (which permanently freezes the UI stream) stays visible during development.
  ///
  /// - Parameters:
  ///   - logWhenTerminated: When `true`, logs the warning; when `false`, does nothing.
  ///   - completion: The terminal event received from the upstream.
  @inline(never)
  fileprivate static func logTerminationDiagnostic<Failure: Error>(
    logWhenTerminated: Bool,
    completion: Subscribers.Completion<Failure>
  ) {
    guard logWhenTerminated else { return }
    switch completion {
    case .finished:
      _log(.warning, SendableCombineLogEntry(code: .driverUpstreamTerminatedWithCompletion,
                                             message: "The upstream is terminated with COMPLETION. The UI stream is now permanently frozen."))
    case .failure(let error):
      _log(.warning, SendableCombineLogEntry(code: .driverUpstreamTerminatedWithFailure, message: "The upstream terminated with error: \(error). The UI stream is now permanently frozen."))
    }
  }
}
