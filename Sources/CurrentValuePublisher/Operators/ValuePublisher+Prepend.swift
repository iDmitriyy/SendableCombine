//
//  ValuePublisher+Prepend.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 28.09.2026.
//

extension AnyCurrentValuePublisher {  
  @export(implementation)
  public func prepend(_ elements: Output...) -> Self {
    let prepended = self.Combine::prepend(elements)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: prepended)
  }

  @export(implementation)
  public func prepend<S: Sequence>(_ elements: S) -> Self where Self.Output == S.Element {
    let prepended = self.Combine::prepend(elements)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: prepended)
  }
}
