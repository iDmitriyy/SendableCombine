//
//  Filtering.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

extension SendableShell {
  @export(implementation)
  public func filter(_ isIncluded: @Sendable @escaping (Output) -> Bool) -> SendableShell<Publishers.Filter<Upstream>> {
    let filtered = Publishers.Filter(upstream: self._base, isIncluded: isIncluded)
    return SendableShell<Publishers.Filter<Upstream>>(_unverified_SendablePublisher__: filtered)
  }
  
  @export(implementation)
  public func tryFilter(_ isIncluded: @Sendable @escaping (Output) throws -> Bool) -> SendableShell<Publishers.TryFilter<Upstream>> {
    let filtered = Publishers.TryFilter(upstream: self._base, isIncluded: isIncluded)
    return SendableShell<Publishers.TryFilter<Upstream>>(_unverified_SendablePublisher__: filtered)
  }
  
  @export(implementation)
  public func removeDuplicates(by predicate: @Sendable @escaping (Output, Output) -> Bool) -> SendableShell<Publishers.RemoveDuplicates<Upstream>> {
    let removedDuplicates = Publishers.RemoveDuplicates(upstream: self._base, predicate: predicate)
    return SendableShell<Publishers.RemoveDuplicates<Upstream>>(_unverified_SendablePublisher__: removedDuplicates)
  }
  
  @export(implementation)
  public func removeDuplicates() -> SendableShell<Publishers.RemoveDuplicates<Upstream>> where Output: Equatable & Sendable {
    let isEqual: @Sendable (Output, Output) -> Bool = { $0 == $1 }
    return removeDuplicates(by: isEqual)
  }
  
  @export(implementation)
  public func ignoreOutput() -> SendableShell<Publishers.IgnoreOutput<Upstream>> {
    let ignoreOutput = _base.ignoreOutput()
    return SendableShell<Publishers.IgnoreOutput<Upstream>>(_unverified_SendablePublisher__: ignoreOutput)
  }
  
  @export(implementation)
  public func prefix(_ maxLength: Int) -> SendableShell<Publishers.Output<Upstream>> {
    let prefixed = self._base.prefix(maxLength)
    
    return SendableShell<Publishers.Output<Upstream>>(_unverified_SendablePublisher__: prefixed)
  }
  
  @export(implementation)
  public func prefix(while predicate: @Sendable @escaping (Output) -> Bool) -> SendableShell<Publishers.PrefixWhile<Upstream>> {
    let prefixed = Publishers.PrefixWhile(upstream: self._base, predicate: predicate)
    return SendableShell<Publishers.PrefixWhile<Upstream>>(_unverified_SendablePublisher__: prefixed)
  }
  
  @export(implementation)
  public func prefix<P>(untilOutputFrom publisher: P) -> SendableShell<Publishers.PrefixUntilOutput<Upstream, P>>
    where P: Publisher & Sendable {
    let prefixUntilOutputFrom = _base.prefix(untilOutputFrom: publisher)
     return SendableShell<Publishers.PrefixUntilOutput<Upstream, P>>(_unverified_SendablePublisher__: prefixUntilOutputFrom)
  }
  
  @export(implementation)
  public func dropFirst(_ count: Int) -> SendableShell<Publishers.Drop<Upstream>> {
    let skipped = self._base.dropFirst(count)
    return SendableShell<Publishers.Drop<Upstream>>(_unverified_SendablePublisher__: skipped)
  }
  
  @export(implementation)
  public func drop(while predicate: @Sendable @escaping (Output) -> Bool) -> SendableShell<Publishers.DropWhile<Upstream>> {
    let dropped = Publishers.DropWhile(upstream: self._base, predicate: predicate)
    
    return SendableShell<Publishers.DropWhile<Upstream>>(_unverified_SendablePublisher__: dropped)
  }
  
  @export(implementation)
  public func drop<P>(untilOutputFrom publisher: P) -> SendableShell<Publishers.DropUntilOutput<Upstream, P>>
    where P: Publisher & Sendable {
    let dropUntilOutputFrom = _base.drop(untilOutputFrom: publisher)
     return SendableShell<Publishers.DropUntilOutput<Upstream, P>>(_unverified_SendablePublisher__: dropUntilOutputFrom)
  }
}
