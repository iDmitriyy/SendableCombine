//
//  ValuePublisher+Once.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 28.09.2026.
//

extension AnyCurrentValuePublisher {
  /// Creates a value stream that emits a single element and never completes.
  ///
  /// Unlike `Just`, which emits one value and then terminates, `once` keeps the
  /// stream open (a continuous, replay(1) value stream holding `element`). This
  /// matches the `CurrentValuePublisher` contract of a non-terminating state stream.
  @export(implementation)
  public static func once(_ element: Output) -> AnyCurrentValuePublisher<Output, Failure> {
    let subject = CurrentValueSubject<Output, Failure>(element)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: subject)
  }
}
