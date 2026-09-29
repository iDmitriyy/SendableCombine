//
//  Combining.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 29.09.2026.
//

// MARK: - Merge

extension AnyCurrentValuePublisher {
  @export(implementation)
  public func merge(with other: some Publisher<Output, Failure> & Sendable) -> AnyCurrentValuePublisher<Output, Failure> {
    let merge = Publishers.Merge(self, other)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: merge)
  }
  
  @export(implementation)
  public func merge(with b: some Publisher<Output, Failure> & Sendable,
                    _ c: some Publisher<Output, Failure> & Sendable) -> AnyCurrentValuePublisher<Output, Failure> {
    let merge = Publishers.Merge3(self, b, c)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: merge)
  }
}

// MARK: - CombineLatest

extension AnyCurrentValuePublisher {
  @export(implementation)
  public func combineLatest<O>(_ other: AnyCurrentValuePublisher<O, Failure>)
    -> AnyCurrentValuePublisher<(Output, O), Failure> {
    let combineLatest = Publishers.CombineLatest(self, other)
    return AnyCurrentValuePublisher<(Output, O), Failure>(manuallyProven_SemiSendable: combineLatest)
  }
  
  @export(implementation)
  public func combineLatest<B, C>(
    _ b: AnyCurrentValuePublisher<B, Failure>,
    _ c: AnyCurrentValuePublisher<C, Failure>,
  ) -> AnyCurrentValuePublisher<(Output, B, C), Failure> {
    let combineLatest = Publishers.CombineLatest3(self, b, c)
    return AnyCurrentValuePublisher<(Output, B, C), Failure>(manuallyProven_SemiSendable: combineLatest)
  }
}

// MARK: - Prepend

extension AnyCurrentValuePublisher {
  @export(implementation)
  public func prepend(_ first: Output, _ others: Output...) -> Self {
    let prepended = self.Combine::prepend([first] + others)
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: prepended)
  }

  @export(implementation)
  public func prepend<S: Sequence>(_ first: Output, _ others: S) -> Self where Self.Output == S.Element {
    let prepended = self.Combine::prepend([first] + Array(others))
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: prepended)
  }
}
