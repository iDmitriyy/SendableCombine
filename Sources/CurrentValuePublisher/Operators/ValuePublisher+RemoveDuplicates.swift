//
//  ValuePublisher+RemoveDuplicates.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

public import Combine

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func removeDuplicates(by predicate: @escaping (Self.Output, Self.Output) -> Bool) -> Self {
    let removeDuplicates = Publishers.RemoveDuplicates(upstream: self, predicate: predicate)
    return Self(retained_unverifiedValuePublisher: removeDuplicates)
  }
}

extension AnyCurrentValuePublisher where Output: Equatable {
  @export(implementation) @_transparent
  public func removeDuplicates() -> Self {
    self.removeDuplicates(by: ==)
  }
}
