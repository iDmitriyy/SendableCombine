//
//  ValuePublisher+CombineLatest.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

public import Combine

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func combineLatest<O>(_ other: AnyCurrentValuePublisher<O, Failure>)
    -> AnyCurrentValuePublisher<(Output, O), Failure> {
    let combineLatest = Publishers.CombineLatest(self, other)
    return AnyCurrentValuePublisher<(Output, O), Failure>(retained_unverifiedValuePublisher: combineLatest)
  }
}
