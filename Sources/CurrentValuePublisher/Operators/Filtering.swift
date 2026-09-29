//
//  Filtering.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 29.09.2026.
//

// MARK: - FilterAfterFirst

extension AnyCurrentValuePublisher {
  /// Filters values from this publisher, guaranteeing that the first value
  /// is always emitted regardless of the predicate.
  ///
  /// Subscribers immediately receive the current value upon subscription.
  /// All subsequent values are filtered by the predicate – only values
  /// where `isIncluded` returns `true` are forwarded.
  ///
  /// - Parameter isIncluded: A closure that takes a value and returns `true`
  ///   if the value should be forwarded to subscribers.
  /// - Returns: A `CurrentValuePublisher` that emits the first value unconditionally,
  ///   then filters subsequent values.
  public func filterAfterFirst(_ isIncluded: @Sendable @escaping (Output) -> Bool) -> Self {
    let pipeline = scan((Output?.none, true)) { state, element in
      let isFirstElement = state.1

      if isFirstElement || isIncluded(element) {
        return (element, false)
      } else {
        return (nil, false)
      }
    }
    .compactMap { state in
      state.0
    }

    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: pipeline)
  }
}

// MARK: - RemoveDuplicates

extension AnyCurrentValuePublisher {
  @export(implementation)
  public func removeDuplicates(by predicate: @Sendable @escaping (Self.Output, Self.Output) -> Bool) -> Self {
    let removeDuplicates = Publishers.RemoveDuplicates(upstream: self, predicate: predicate)
    return Self(manuallyProven_SemiSendable: removeDuplicates)
  }
}

extension AnyCurrentValuePublisher where Output: Equatable & SendableMetatype {
  @export(implementation)
  public func removeDuplicates() -> Self {
    let isEqual: @Sendable (Output, Output) -> Bool = { $0 == $1 }
    return self.removeDuplicates(by: isEqual)
  }
}
