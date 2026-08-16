//
//  ValuePublisher+Merge.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

// MARK: - Merge

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func merge(with other: some Publisher<Output, Failure>) -> AnyCurrentValuePublisher<Output, Failure> {
    let merge = Publishers.Merge(self, other)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: merge)
  }
}

extension Publisher {
  @export(implementation) @_transparent
  public func merge(with other: AnyCurrentValuePublisher<Output, Failure>)
    -> AnyCurrentValuePublisher<Output, Failure> {
    other.merge(with: self)
  }
}
