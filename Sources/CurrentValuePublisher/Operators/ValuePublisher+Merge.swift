//
//  ValuePublisher+Merge.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

public import Combine

// MARK: - Merge

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func merge(with other: some Publisher<Output, Failure>) -> AnyCurrentValuePublisher<Output, Failure> {
    let merge = Publishers.Merge(self, other)
    return AnyCurrentValuePublisher(retained_unverifiedValuePublisher: merge)
  }
}

extension Publisher {
  @export(implementation) @_transparent
  public func merge(with other: AnyCurrentValuePublisher<Output, Failure>)
    -> AnyCurrentValuePublisher<Output, Failure> {
    other.merge(with: self)
  }
}
