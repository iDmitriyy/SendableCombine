//
//  ValuePublisher+FilterAfterFirst.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 06.08.2026.
//

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
