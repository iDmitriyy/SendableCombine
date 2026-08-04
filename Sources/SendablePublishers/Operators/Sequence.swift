//
//  Sequence.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendablePublisher_ {
  @export(implementation)
  public func count() -> SendablePublisher_<Publishers.Count<Upstream>> {
    let count = Publishers.Count(upstream: self._base)
    return SendablePublisher_<Publishers.Count<Upstream>>(_unverified_SendablePublisher__: count)
  }
  
  @export(implementation)
  public func min(by areInIncreasingOrder: @Sendable @escaping (Output, Output) -> Bool) -> SendablePublisher_<Publishers.Comparison<Upstream>> {
    let min = _base.min(by: areInIncreasingOrder)
    return SendablePublisher_<Publishers.Comparison<Upstream>>(_unverified_SendablePublisher__: min)
  }
  
  @export(implementation)
  public func min() -> SendablePublisher_<Publishers.Comparison<Upstream>> where Output: Comparable & Sendable {
    let areInIncreasingOrder: @Sendable (Output, Output) -> Bool = { $0 < $1 }
    return min(by: areInIncreasingOrder)
  }
  
  @export(implementation)
  public func max(by areInIncreasingOrder: @Sendable @escaping (Output, Output) -> Bool) -> SendablePublisher_<Publishers.Comparison<Upstream>> {
    let max = _base.max(by: areInIncreasingOrder)
    return SendablePublisher_<Publishers.Comparison<Upstream>>(_unverified_SendablePublisher__: max)
  }
  
  @export(implementation)
  public func max() -> SendablePublisher_<Publishers.Comparison<Upstream>> where Output: Comparable & Sendable {
    let areInIncreasingOrder: @Sendable (Output, Output) -> Bool = { $0 > $1 }
    return max(by: areInIncreasingOrder)
  }
  
  @export(implementation)
  public func first() -> SendablePublisher_<Publishers.First<Upstream>> {
    let first = Publishers.First(upstream: self._base)
    return SendablePublisher_<Publishers.First<Upstream>>(_unverified_SendablePublisher__: first)
  }
  
  @export(implementation)
  public func first(where predicate: @Sendable @escaping (Output) -> Bool) -> SendablePublisher_<Publishers.FirstWhere<Upstream>> {
    let first = Publishers.FirstWhere(upstream: self._base, predicate: predicate)
    return SendablePublisher_<Publishers.FirstWhere<Upstream>>(_unverified_SendablePublisher__: first)
  }
  
  @export(implementation)
  public func last() -> SendablePublisher_<Publishers.Last<Upstream>> {
    let last = Publishers.Last(upstream: self._base)
    return SendablePublisher_<Publishers.Last<Upstream>>(_unverified_SendablePublisher__: last)
  }
  
  @export(implementation)
  public func last(where predicate: @Sendable @escaping (Self.Output) -> Bool)
    -> SendablePublisher_<Publishers.LastWhere<Upstream>> {
    let lastWhere = Publishers.LastWhere(upstream: self._base, predicate: predicate)
    return SendablePublisher_<Publishers.LastWhere<Upstream>>(_unverified_SendablePublisher__: lastWhere)
  }
  
  @export(implementation)
  public func output(at index: Int) -> SendablePublisher_<Publishers.Output<Upstream>> {
    let outputAt = _base.output(at: index)
    return SendablePublisher_<Publishers.Output<Upstream>>(_unverified_SendablePublisher__: outputAt)
  }
  
  @export(implementation)
  public func output<R>(in range: R) -> SendablePublisher_<Publishers.Output<Upstream>> where R: RangeExpression, R.Bound == Int {
    let outputIn = _base.output(in: range)
    return SendablePublisher_<Publishers.Output<Upstream>>(_unverified_SendablePublisher__: outputIn)
  }
}

// MARK: - Matching

extension SendablePublisher_ {
  @export(implementation)
  public func allSatisfy(_ predicate: @Sendable @escaping (Output) -> Bool) -> SendablePublisher_<Publishers.AllSatisfy<Upstream>> {
    let allSatisfy = Publishers.AllSatisfy(upstream: self._base, predicate: predicate)
    return SendablePublisher_<Publishers.AllSatisfy<Upstream>>(_unverified_SendablePublisher__: allSatisfy)
  }
  
  @export(implementation)
  public func contains(_ output: Output) -> SendablePublisher_<Publishers.Contains<Upstream>> where Output: Equatable & Sendable {
    let contains = Publishers.Contains(upstream: self._base, output: output)
    return SendablePublisher_<Publishers.Contains<Upstream>>(_unverified_SendablePublisher__: contains)
  }
  
  @export(implementation)
  public func contains(where predicate: @Sendable @escaping (Output) -> Bool) -> SendablePublisher_<Publishers.ContainsWhere<Upstream>> {
    let contains = Publishers.ContainsWhere(upstream: self._base, predicate: predicate)
    return SendablePublisher_<Publishers.ContainsWhere<Upstream>>(_unverified_SendablePublisher__: contains)
  }
}
