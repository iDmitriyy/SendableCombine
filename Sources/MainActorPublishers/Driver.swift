//
//  Driver.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine
import os

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

  // MARK: Init with Infallible Publisher
  
  public init<P: Publisher>(infallibleUpstream: P, initialValue: Element) where P.Output == Element, P.Failure == Never {
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
          .receive(on: DispatchQueue.main)
          .multicast(subject: bufferSubject)
        
        // 3. Атомарно подключаем апстрим. Спрос пойдет через внутренние механизмы Combine.
        state.cancellable = connectable.connect()
        
        let shared = connectable.eraseToAnyPublisher()
        state.publisher = shared
        return shared
      }
    }
    
    self._upstream = lazyPublisher.eraseToAnyPublisher()
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
    // FIXME: - not in main thread
    Driver(_upstream: self.eraseToAnyPublisher())
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
    Driver(infallibleUpstream: self, initialValue: initialValue)
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
  public func asDriverIgnoringError(initialValue: Output) -> Driver<Output> {
    let processed = self.catch { _ in Empty<Output, Never>() }
    
    return Driver(infallibleUpstream: processed, initialValue: initialValue)
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
                       catchError: @Sendable @escaping (Failure) -> Output) -> Driver<Output> {
    let processed = self.catch { failure in Just(catchError(failure)) }
    return Driver(infallibleUpstream: processed, initialValue: initialValue)
  }
}
