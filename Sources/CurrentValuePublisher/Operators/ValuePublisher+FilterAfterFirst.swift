//
//  ValuePublisher+FilterAfterFirst.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 06.08.2026.
//

// MARK: - FilterAfterFirst Implementation 2

import os

/// A subject that buffers the latest value and applies filterAfterFirst semantics:
/// - First value always emitted and cached
/// - Subsequent values filtered by `isIncluded` predicate
/// - New subscribers receive latest cached (filtered) value
/// Uses same shared-multicast pattern as Driver.
@usableFromInline
internal final class _FilterAfterFirstBuffer<Output, Failure: Error>: Subject {
  @usableFromInline typealias Output = Output
  @usableFromInline typealias Failure = Failure

  private let isIncluded: @Sendable (Output) -> Bool
  private let lock = OSAllocatedUnfairLock(uncheckedState: (hasValue: false, value: nil as Output?, completed: false as Bool, subs: [] as [_FilterAfterFirstSubscription<Output, Failure>]))

  @usableFromInline
  init(isIncluded: @Sendable @escaping (Output) -> Bool) {
    self.isIncluded = isIncluded
  }

  // MARK: - Subject

  @usableFromInline
  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    let subscription = _FilterAfterFirstSubscription(downstream: subscriber, buffer: self)
    subscriber.receive(subscription: subscription)

    lock.withLockUnchecked { state in
      state.subs.append(subscription)
      if state.hasValue, let value = state.value {
        _ = subscription.downstream.receive(value)
      }
      if state.completed {
        subscription.downstream.receive(completion: .finished)
      }
    }
  }

  // MARK: - Publisher (for multicast)

  @usableFromInline
  func send(_ value: Output) {
    let shouldEmit = lock.withLockUnchecked { state -> Bool in
      if !state.hasValue {
        state.hasValue = true
        state.value = value
        return true
      }
      return isIncluded(value)
    }
    if shouldEmit {
      lock.withLockUnchecked { state in
        state.value = value
      }
      dispatch(value)
    }
  }

  @usableFromInline
  func send(completion: Subscribers.Completion<Failure>) {
    let subs = lock.withLockUnchecked { state -> [_FilterAfterFirstSubscription<Output, Failure>] in
      state.completed = true
      let s = state.subs
      state.subs.removeAll()
      return s
    }
    for sub in subs { sub.downstream.receive(completion: completion) }
  }

  @usableFromInline
  func send(subscription: any Subscription) { subscription.request(.unlimited) }

  private func dispatch(_ value: Output) {
    let subs = lock.withLockUnchecked { $0.subs }
    for sub in subs { _ = sub.downstream.receive(value) }
  }

  @usableFromInline
  func removeSubscription(_ sub: _FilterAfterFirstSubscription<Output, Failure>) {
    lock.withLockUnchecked { state in state.subs.removeAll { $0 === sub } }
  }
}

@usableFromInline
internal final class _FilterAfterFirstSubscription<Output, Failure: Error>: Subscription {
  fileprivate let downstream: any Subscriber<Output, Failure>
  private weak var buffer: _FilterAfterFirstBuffer<Output, Failure>?
  private let lock = OSAllocatedUnfairLock(uncheckedState: false)

  @usableFromInline
  init(downstream: any Subscriber<Output, Failure>, buffer: _FilterAfterFirstBuffer<Output, Failure>) {
    self.downstream = downstream
    self.buffer = buffer
  }

  @usableFromInline
  func request(_ demand: Subscribers.Demand) {}

  @usableFromInline
  func cancel() {
    let wasCancelled = lock.withLockUnchecked { state in
      if state { return true }
      state = true
      return false
    }
    if !wasCancelled { buffer?.removeSubscription(self); buffer = nil }
  }
}

extension AnyCurrentValuePublisher {
  /// Filters values from this publisher, guaranteeing that the first value
  /// is always emitted regardless of the predicate.
  ///
  /// All subscribers share a single upstream subscription and receive the same
  /// filtered sequence. The first value is always emitted; subsequent values
  /// are filtered by `isIncluded`.
  ///
  /// - Parameter isIncluded: A closure that takes a value and returns `true`
  ///   if the value should be forwarded to subscribers.
  /// - Returns: A `CurrentValuePublisher` that emits the first value unconditionally,
  ///   then filters subsequent values. All subscribers receive identical output.
  @export(implementation) @_transparent
  public func filterAfterFirst(_ isIncluded: @Sendable @escaping (Output) -> Bool)
    -> AnyCurrentValuePublisher<Output, Failure> {
      let buffer = _FilterAfterFirstBuffer<Output, Failure>(isIncluded: isIncluded)
      let connectable = self.multicast(subject: buffer)
      let shared = connectable.eraseToAnyPublisher()
      _ = connectable.connect()
      return AnyCurrentValuePublisher(manuallyProven_SemiSendable: shared)
  }
}

// MARK: - FilterAfterFirst Implementation 1

// FIXME: - try to replace this implementation by Combine operators + share()

//extension AnyCurrentValuePublisher {
//  /// Filters values from this publisher, guaranteeing that the first value
//  /// is always emitted regardless of the predicate.
//  ///
//  /// Subscribers immediately receive the current value upon subscription.
//  /// All subsequent values are filtered by the predicate – only values
//  /// where `isIncluded` returns `true` are forwarded.
//  ///
//  /// - Parameter isIncluded: A closure that takes a value and returns `true`
//  ///   if the value should be forwarded to subscribers.
//  /// - Returns: A `CurrentValuePublisher` that emits the first value unconditionally,
//  ///   then filters subsequent values.
//  @export(implementation) @_transparent
//  public func filterAfterFirst(_ isIncluded: @Sendable @escaping (Output) -> Bool)
//    -> AnyCurrentValuePublisher<Output, Failure> {
//      let filterAfterFirst = _FilterAfterFirst(upstream: self, isIncluded: isIncluded)
//      return AnyCurrentValuePublisher(manuallyProven_SemiSendable: filterAfterFirst)
//  }
//}
//
//// MARK: - _FilterAfterFirst
//
//@usableFromInline
//internal struct _FilterAfterFirst<Upstream: Publisher>: Publisher {
//  @usableFromInline typealias Output = Upstream.Output
//  @usableFromInline typealias Failure = Upstream.Failure
//
//  let upstream: Upstream
//  let isIncluded: @Sendable (Output) -> Bool
//
//  @usableFromInline
//  init(upstream: Upstream, isIncluded: @Sendable @escaping (Output) -> Bool) {
//    self.upstream = upstream
//    self.isIncluded = isIncluded
//  }
//  
//  @usableFromInline
//  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
//    upstream.receive(subscriber: _FilterAfterFirstSubscriber(inner: subscriber, isIncluded: isIncluded))
//  }
//}
//
//// MARK: - _FilterAfterFirstSubscriber
//
//import os
//
//// TODO: - need code review / tests
//
//fileprivate final class _FilterAfterFirstSubscriber<Downstream: Subscriber>: Subscriber, Subscription, @unchecked Sendable {
//  typealias Input = Downstream.Input
//  typealias Failure = Downstream.Failure
//
//  private enum State {
//    case awaitingSubscription
//    case connected(any Subscription)
//    case completed
//  }
//
//  private let downstream: Downstream
//  private let isIncluded: (Input) -> Bool
//  private let lock = OSAllocatedUnfairLock(uncheckedState: State.awaitingSubscription)
//  private var hasReceivedFirstValue = false  // only accessed from Combine's serialized receive(_:) – no lock needed
//
//  init(inner downstream: Downstream, isIncluded: @escaping (Input) -> Bool) {
//    self.downstream = downstream
//    self.isIncluded = isIncluded
//  }
//
//  // MARK: - Subscriber
//
//  final func receive(subscription: any Subscription) {
//    lock.withLockUnchecked { state in
//      guard case .awaitingSubscription = state else {
//        subscription.cancel()
//        return
//      }
//      state = .connected(subscription)
//    }
//    downstream.receive(subscription: self)
//    // TODO: is it correct to always call downstream.receive(subscription: self)?
//    // There can subscription.cancel() happen.
//  }
//
//  final func receive(_ input: Input) -> Subscribers.Demand {
//    // hasReceivedFirstValue is only accessed here — Combine serializes receive(_:) calls
//    // TODO: very this or use Atomic<Bool>
//    if hasReceivedFirstValue {
//      return isIncluded(input) ? downstream.receive(input) : .none
//    } else {
//      hasReceivedFirstValue = true
//      return downstream.receive(input)
//    }
//  }
//
//  final func receive(completion: Subscribers.Completion<Failure>) {
//    lock.withLockUnchecked { state in
//      if case .connected(let subscription) = state {
//        subscription.cancel()
//      }
//      state = .completed
//    }
//    downstream.receive(completion: completion)
//  }
//  
//  // MARK: - Subscription
//
//  final func request(_ demand: Subscribers.Demand) {
//    lock.withLockUnchecked { state in
//      if case .connected(let subscription) = state {
//        subscription.request(demand)
//      }
//    }
//  }
//
//  final func cancel() {
//    lock.withLockUnchecked { state in
//      if case .connected(let subscription) = state {
//        subscription.cancel()
//      }
//      state = .completed
//    }
//  }
//}
