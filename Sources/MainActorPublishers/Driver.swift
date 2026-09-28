//
//  Driver.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine
public import SendablePublishers
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
///   1. **Infallible**: It cannot emit error termination signal (`Failure == Never`).
///   2. **Main Thread**: All downstream values are guaranteed to be observed on the main thread.
///   3. **Replay**: Replays the latest element upon subscription:
///   either the `initialValue` if no data has arrived yet from upstream, or the most recent upstream emission.
///
/// ### Semantic Differences from RxSwift.Driver
/// While this structure serves the same functional purpose as its `RxSwift` counterpart, it introduces the following behavioral shifts:
/// * **Hot Stream & Lifecycle Semantics**: This stream behaves as a "hot" publisher. It connects to the upstream exactly once when
/// Driver initialized.
/// Crucially, unlike `RxSwift.Driver`, which tears down its connection and clears its cache when the last subscriber disconnects,
/// this implementation keeps the upstream connection active and continuously buffers new values to replay the latest one to any new subscriber,
/// even during periods with zero active consumers.
/// * **Backpressure Compliance**: Unlike `RxSwift.Driver`, which pushes data unconditionally, this `Driver` strictly respects
/// Apple Combine's `Subscribers.Demand` contract. Data flow is throttled natively according to consumer consumption speeds.
///
/// ### Replay Semantics (3 examples)
/// * **Case 1**: `Subscriber 1` receives `initialValue`. Upstream generates no events. `Subscriber 2` appears and also receives `initialValue`.
/// * **Case 2**: `Subscriber 1` receives `initialValue`. Then upstream emits `nextValue`, and `Subscriber 1` receives `nextValue`.
/// `Subscriber 2` appears and receives `nextValue`.
/// * **Case 3**: `Driver` is created with `initialValue`. While there are no subscribers yet, upstream emits `nextValue`.
/// `Subscriber 1` appears and receives `nextValue`.
/// `Subscriber 2` appears and receives `nextValue`.
///
/// ### Diagnostic Logging & UI Lifecycle
/// Because a `Driver` is designed to continuously stream data to UI, any upstream termination, whether a normal completion (`.finished`)
/// or an unhandled failure (`.failure`), is typically unexpected.
/// Once a terminal event occurs, the reactive pipeline closes permanently, leaving UI components holding their last received state
/// without any further updates.
/// To prevent these silent pipeline terminations during development, failable factory initializers include an optional `logWhenTerminated`
/// parameter (enabled by default). When active, it intercepts the stream's completion signals and logs a diagnostic warning,
/// ensuring visibility into unexpected pipeline terminations.
public struct Driver<Element: Sendable>: Sendable {
  @usableFromInline internal let _hotUpstream: any Publisher<Output, Failure> & Sendable
  fileprivate let _connectionCancellable: any Sendable

  init(_unchecked_HotUpstream: any Publisher<Output, Failure> & Sendable,
       connectionCancellable: any Cancellable) {
    _hotUpstream = _unchecked_HotUpstream
    _connectionCancellable = OSAllocatedUnfairLock(uncheckedState: connectionCancellable)
  }
}

// FXIME: send .onCompleted on deinit?

// MARK: - Publisher Conformance

extension Driver: Publisher {
  public typealias Output = Element
  public typealias Failure = Never

  @inlinable
  public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Output {
    _hotUpstream.receive(subscriber: subscriber)
  }
}

// MARK: - MainActor observation

extension Driver {
  /// Subscribes a `@MainActor`-isolated receive closure.
  ///
  /// The Driver guarantees every value — both upstream emissions and the replayed `initialValue` —
  /// is delivered on the main thread, because the pipeline re-schedules on `DispatchQueue.main`
  /// downstream of its internal buffer. This method bridges that runtime guarantee into the compiler
  /// with `MainActor.assumeIsolated`, which traps only if the closure ever ran off the main thread.
  public func drive(receiveValue: @MainActor @Sendable @escaping (Element) -> Void) -> AnyCancellable {
    _hotUpstream.sink(receiveValue: { value in
      MainActor.assumeIsolated {
        receiveValue(value)
      }
    })
  }
}

// MARK: - as Publisher

extension Driver {
  @export(implementation) @_transparent
  public func asPublisher() -> any Publisher<Element, Never> & Sendable {
    _hotUpstream
  }
}

// TODO: - add test case that every new subscriber her last value. connect() / multicast should not break replay(1)

// MARK: - Common Initializer

extension Driver {
  private typealias SharedState = (publisher: AnySendablePublisher<Element, Never>?, cancellable: (any Cancellable)?)

  // MARK: - Init with Infallible Publisher

  @inline(never)
  internal init<P: Publisher & Sendable>(
    infallibleUpstream: P,
    initialValue: Element,
    logWhenTerminated: Bool,
  ) where P.Output: Sendable, P.Output == Element, P.Failure == Never {
    let bufferSubject = CurrentValueSubject<Element, Never>(initialValue)
    let upstreamCancellable = infallibleUpstream.subscribe(bufferSubject)

    self.init(infallibleCurrentValueSubject: bufferSubject,
              upstreamCancellable: upstreamCancellable,
              logWhenTerminated: logWhenTerminated)
  }

  @inline(never)
  internal init(infallibleCurrentValueSubject: CurrentValueSubject<Element, Never>,
                upstreamCancellable: (any Cancellable)?,
                logWhenTerminated: Bool) {
    let upstream: any Publisher<Element, Never> & Sendable = if logWhenTerminated {
      infallibleCurrentValueSubject.handleEvents(receiveCompletion: { completion in
        _logTerminationDiagnostic(logWhenTerminated: logWhenTerminated,
                                  sharedPublisherName: "Driver<\(Output.self)>",
                                  completion: completion)
      })
    } else {
      infallibleCurrentValueSubject
    }

    let connectable = upstream
      .receive(on: DispatchQueue.main)
      .SendablePublishers::makeConnectable()

    let connectionCancellable = connectable.connect()

    let cancellable = AnyCancellable {
      connectionCancellable.cancel()
      upstreamCancellable?.cancel()
    }

    self.init(_unchecked_HotUpstream: connectable,
              connectionCancellable: cancellable)
  }
}
