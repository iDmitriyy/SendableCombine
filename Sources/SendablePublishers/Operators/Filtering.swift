//
//  Filtering.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

extension SendablePublisher_ {
  @export(implementation)
  public func filter(_ isIncluded: @Sendable @escaping (Output) -> Bool) -> SendablePublisher_<Publishers.Filter<Upstream>> {
    let filtered = Publishers.Filter(upstream: self._base, isIncluded: isIncluded)
    return SendablePublisher_<Publishers.Filter<Upstream>>(_unverified_SendablePublisher__: filtered)
  }
  
  @export(implementation)
  public func tryFilter(_ isIncluded: @Sendable @escaping (Output) throws -> Bool) -> SendablePublisher_<Publishers.TryFilter<Upstream>> {
    let filtered = Publishers.TryFilter(upstream: self._base, isIncluded: isIncluded)
    return SendablePublisher_<Publishers.TryFilter<Upstream>>(_unverified_SendablePublisher__: filtered)
  }
  
  @export(implementation)
  public func removeDuplicates(by predicate: @Sendable @escaping (Output, Output) -> Bool) -> SendablePublisher_<Publishers.RemoveDuplicates<Upstream>> {
    let removedDuplicates = Publishers.RemoveDuplicates(upstream: self._base, predicate: predicate)
    return SendablePublisher_<Publishers.RemoveDuplicates<Upstream>>(_unverified_SendablePublisher__: removedDuplicates)
  }
  
  @export(implementation)
  public func removeDuplicates() -> SendablePublisher_<Publishers.RemoveDuplicates<Upstream>> where Output: Equatable & Sendable {
    let isEqual: @Sendable (Output, Output) -> Bool = { $0 == $1 }
    return removeDuplicates(by: isEqual)
  }
  
  @export(implementation)
  public func ignoreOutput() -> SendablePublisher_<Publishers.IgnoreOutput<Upstream>> {
    let ignoreOutput = _base.ignoreOutput()
    return SendablePublisher_<Publishers.IgnoreOutput<Upstream>>(_unverified_SendablePublisher__: ignoreOutput)
  }
  
  @export(implementation)
  public func prefix(_ maxLength: Int) -> SendablePublisher_<Publishers.Output<Upstream>> {
    let prefixed = self._base.prefix(maxLength)
    
    return SendablePublisher_<Publishers.Output<Upstream>>(_unverified_SendablePublisher__: prefixed)
  }
  
  @export(implementation)
  public func prefix(while predicate: @Sendable @escaping (Output) -> Bool) -> SendablePublisher_<Publishers.PrefixWhile<Upstream>> {
    let prefixed = Publishers.PrefixWhile(upstream: self._base, predicate: predicate)
    return SendablePublisher_<Publishers.PrefixWhile<Upstream>>(_unverified_SendablePublisher__: prefixed)
  }
  
  @export(implementation)
  public func prefix<P>(untilOutputFrom publisher: P) -> SendablePublisher_<Publishers.PrefixUntilOutput<Upstream, P>>
    where P: Publisher & Sendable {
    let prefixUntilOutputFrom = _base.prefix(untilOutputFrom: publisher)
     return SendablePublisher_<Publishers.PrefixUntilOutput<Upstream, P>>(_unverified_SendablePublisher__: prefixUntilOutputFrom)
  }
  
  @export(implementation)
  public func dropFirst(_ count: Int) -> SendablePublisher_<Publishers.Drop<Upstream>> {
    let skipped = self._base.dropFirst(count)
    return SendablePublisher_<Publishers.Drop<Upstream>>(_unverified_SendablePublisher__: skipped)
  }
  
  @export(implementation)
  public func drop(while predicate: @Sendable @escaping (Output) -> Bool) -> SendablePublisher_<Publishers.DropWhile<Upstream>> {
    let dropped = Publishers.DropWhile(upstream: self._base, predicate: predicate)
    
    return SendablePublisher_<Publishers.DropWhile<Upstream>>(_unverified_SendablePublisher__: dropped)
  }
  
  @export(implementation)
  public func drop<P>(untilOutputFrom publisher: P) -> SendablePublisher_<Publishers.DropUntilOutput<Upstream, P>>
    where P: Publisher & Sendable {
    let dropUntilOutputFrom = _base.drop(untilOutputFrom: publisher)
     return SendablePublisher_<Publishers.DropUntilOutput<Upstream, P>>(_unverified_SendablePublisher__: dropUntilOutputFrom)
  }
}
