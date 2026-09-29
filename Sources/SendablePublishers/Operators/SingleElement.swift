//
//  Once.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 29.09.2026.
//

import Combine

extension Publishers {
  /// Creates a value stream that emits a single element and never completes.
  ///
  /// Unlike `Just`, which emits one value and then terminates, `once` keeps the
  /// stream open (a continuous, replay(1) value stream holding `element`). This
  /// matches the `CurrentValuePublisher` contract of a non-terminating state stream.
  @export(implementation)
  public static func SingleElement<Output, Failure: Error>(_ element: Output) -> some Publisher<Output, Failure> {
    CurrentValueSubject<Output, Failure>(element)
  }
}

extension SendablePublishers {
  @export(implementation)
  public static func SingleElement<Output: Sendable, Failure: Error>(_ element: Output)
    -> some Publisher<Output, Failure> & Sendable {
    SendableShell(_manuallyProven_Sendable__: Publishers.SingleElement(element))
  }
}
