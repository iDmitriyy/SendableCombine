//
//  ValuePublisher+Merge.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

// MARK: - Merge

// TODO: some Publisher<Output, Failure> & Sendable
// to make AnyCurrentValuePublisher conditionally Sendable is not achievable when Output: Sendable, because
// when Output: Sendable we can not guarantee that other: Publisher is sendable (e.g. closures with non-Sendable captures)

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func merge(with other: some Publisher<Output, Failure>) -> AnyCurrentValuePublisher<Output, Failure> {
    let merge = Publishers.Merge(self, other)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: merge)
  }
  // TODO: - ? use variadic generics
}

//extension Publisher {
//  @export(implementation) @_transparent
//  public func merge(with other: AnyCurrentValuePublisher<Output, Failure>)
//    -> AnyCurrentValuePublisher<Output, Failure> {
//    other.merge(with: self)
//  }
//}
