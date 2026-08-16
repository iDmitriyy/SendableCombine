//
//  Filtering.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func filter(_ isIncluded: @Sendable @escaping (Output) -> Bool) -> some Publisher<Output, Failure> & Sendable {
    let filtered = Publishers.Filter(upstream: self, isIncluded: isIncluded)
    return SendableShell<Publishers.Filter<Self>>(_manuallyProven_Sendable__: filtered)
  }

  @export(implementation)
  public func tryFilter(_ isIncluded: @Sendable @escaping (Output) throws -> Bool) -> some Publisher<Output, any Error> & Sendable {
    let filtered = Publishers.TryFilter(upstream: self, isIncluded: isIncluded)
    return SendableShell<Publishers.TryFilter<Self>>(_manuallyProven_Sendable__: filtered)
  }

  @export(implementation)
  public func removeDuplicates(by predicate: @Sendable @escaping (Output, Output) -> Bool) -> some Publisher<Output, Failure> & Sendable {
    let removedDuplicates = Publishers.RemoveDuplicates(upstream: self, predicate: predicate)
    return SendableShell<Publishers.RemoveDuplicates<Self>>(_manuallyProven_Sendable__: removedDuplicates)
  }

  @export(implementation)
  public func removeDuplicates() -> some Publisher<Output, Failure> & Sendable where Output: Equatable & Sendable {
    let isEqual: @Sendable (Output, Output) -> Bool = { $0 == $1 }
    return removeDuplicates(by: isEqual)
  }

  @export(implementation)
  public func ignoreOutput() -> some Publisher<Never, Failure> & Sendable {
    let ignoreOutput = self.Combine::ignoreOutput()
    return SendableShell<Publishers.IgnoreOutput<Self>>(_manuallyProven_Sendable__: ignoreOutput)
  }

  @export(implementation)
  public func prefix(_ maxLength: Int) -> some Publisher<Output, Failure> & Sendable {
    let prefixed = self.Combine::prefix(maxLength)

    return SendableShell<Publishers.Output<Self>>(_manuallyProven_Sendable__: prefixed)
  }

  @export(implementation)
  public func prefix(while predicate: @Sendable @escaping (Output) -> Bool) -> some Publisher<Output, Failure> & Sendable {
    let prefixed = Publishers.PrefixWhile(upstream: self, predicate: predicate)
    return SendableShell<Publishers.PrefixWhile<Self>>(_manuallyProven_Sendable__: prefixed)
  }

  @export(implementation)
  public func prefix<P: Publisher & Sendable>(untilOutputFrom publisher: P) -> some Publisher<Output, Failure> & Sendable {
    let prefixUntilOutputFrom = self.Combine::prefix(untilOutputFrom: publisher)
    return SendableShell<Publishers.PrefixUntilOutput<Self, P>>(_manuallyProven_Sendable__: prefixUntilOutputFrom)
  }

  @export(implementation)
  public func dropFirst(_ count: Int) -> some Publisher<Output, Failure> & Sendable {
    let skipped = self.Combine::dropFirst(count)
    return SendableShell<Publishers.Drop<Self>>(_manuallyProven_Sendable__: skipped)
  }

  @export(implementation)
  public func drop(while predicate: @Sendable @escaping (Output) -> Bool) -> some Publisher<Output, Failure> & Sendable {
    let dropped = Publishers.DropWhile(upstream: self, predicate: predicate)
    return SendableShell<Publishers.DropWhile<Self>>(_manuallyProven_Sendable__: dropped)
  }

  @export(implementation)
  public func drop<P: Publisher & Sendable>(untilOutputFrom publisher: P)
    -> some Publisher<Output, Failure> & Sendable where Self.Failure == P.Failure{
    let dropUntilOutputFrom = self.Combine::drop(untilOutputFrom: publisher)
    return SendableShell<Publishers.DropUntilOutput<Self, P>>(_manuallyProven_Sendable__: dropUntilOutputFrom)
  }
}
