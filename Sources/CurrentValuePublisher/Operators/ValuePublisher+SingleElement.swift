//
//  ValuePublisher+SingleElement.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 28.09.2026.
//

public import SendablePublishers

extension AnyCurrentValuePublisher {
  /// Creates a value stream that emits a single element and never completes.
  ///
  /// Unlike `Just`, which emits one value and then terminates, `once` keeps the
  /// stream open (a continuous, replay(1) value stream holding `element`). This
  /// matches the `CurrentValuePublisher` contract of a non-terminating state stream.
  @export(implementation)
  public static func SingleElement(_ element: Output) -> AnyCurrentValuePublisher<Output, Failure> {
    AnyCurrentValuePublisher(manuallyProven_SemiSendable: Publishers.SingleElement(element))
  }
}
