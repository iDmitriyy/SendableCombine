//
//  ValuePublisher+PreviousAndCurrent.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 29.09.2026.
//

extension AnyCurrentValuePublisher {
  /// Emits every element paired with the element that preceded it.
  ///
  /// The first element is paired with itself: `(previous: first, current: first)`.
  /// Every subsequent element is paired with the element emitted right before it.
  ///
  /// - Returns: A publisher emitting `(previous:current:)` tuples.
  @export(implementation)
  public func previousAndCurrent() -> AnyCurrentValuePublisher<(previous: Output, current: Output), Failure> {
    let scan = Publishers.Scan(
      upstream: self,
      initialResult: nil as (previous: Output, current: Output)?
    ) { accumulator, newElement -> (previous: Output, current: Output)? in
      guard let accumulator else {
        return (previous: newElement, current: newElement)
      }
      return (previous: accumulator.current, current: newElement)
    }

    let compactMapped = Publishers.CompactMap(upstream: scan) { $0 }

    return AnyCurrentValuePublisher<(previous: Output, current: Output), Failure>(manuallyProven_SemiSendable: compactMapped)
  }
}
