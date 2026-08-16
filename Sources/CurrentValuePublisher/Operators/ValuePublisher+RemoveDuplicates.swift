//
//  ValuePublisher+RemoveDuplicates.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func removeDuplicates(by predicate: @Sendable @escaping (Self.Output, Self.Output) -> Bool) -> Self {
    let removeDuplicates = Publishers.RemoveDuplicates(upstream: self, predicate: predicate)
    return Self(manuallyProven_SemiSendable: removeDuplicates)
  }
}

extension AnyCurrentValuePublisher where Output: Equatable & SendableMetatype {
  @export(implementation) @_transparent
  public func removeDuplicates() -> Self {
    let isEqual: @Sendable (Output, Output) -> Bool = { $0 == $1 }
    return self.removeDuplicates(by: isEqual)
  }
}
