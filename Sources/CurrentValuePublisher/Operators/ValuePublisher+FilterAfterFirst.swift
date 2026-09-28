//
//  ValuePublisher+FilterAfterFirst.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 06.08.2026.
//

// MARK: - FilterAfterFirst Implementation 2

extension AnyCurrentValuePublisher {
  public func filterAfterFirst(_ isIncluded: @Sendable @escaping (Output) -> Bool)
    -> AnyCurrentValuePublisher<Output, Failure> {
    let pipeline = scan((Output?.none, true)) { state, element in
      let isFirstElement = state.1

      if isFirstElement || isIncluded(element) {
        return (element, false)
      } else {
        return (nil, false)
      }
    }
    .compactMap { state in
      state.0
    }

    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: pipeline)
  }
}
