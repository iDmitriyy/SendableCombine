//
//  Sequence.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func count() -> some Publisher<Int, Failure> & Sendable {
    let count = Publishers.Count(upstream: self)
    return SendableShell<Publishers.Count<Self>>(_manuallyProven_Sendable__: count)
  }

  @export(implementation)
  public func min(by areInIncreasingOrder: @Sendable @escaping (Output, Output) -> Bool) -> some Publisher<Output, Failure> & Sendable {
    let compared = self.Combine::min(by: areInIncreasingOrder)
    return SendableShell<Publishers.Comparison<Self>>(_manuallyProven_Sendable__: compared)
  }

  @export(implementation)
  public func min() -> some Publisher<Output, Failure> & Sendable where Output: Comparable & Sendable {
    let areInIncreasingOrder: @Sendable (Output, Output) -> Bool = { $0 < $1 }
    return min(by: areInIncreasingOrder)
  }

  @export(implementation)
  public func max(by areInIncreasingOrder: @Sendable @escaping (Output, Output) -> Bool) -> some Publisher<Output, Failure> & Sendable {
    let compared = self.Combine::max(by: areInIncreasingOrder)
    return SendableShell<Publishers.Comparison<Self>>(_manuallyProven_Sendable__: compared)
  }

  @export(implementation)
  public func max() -> some Publisher<Output, Failure> & Sendable where Output: Comparable & Sendable {
    let areInIncreasingOrder: @Sendable (Output, Output) -> Bool = { $0 > $1 }
    return max(by: areInIncreasingOrder)
  }

  @export(implementation)
  public func first() -> some Publisher<Output, Failure> & Sendable {
    let first = Publishers.First(upstream: self)
    return SendableShell<Publishers.First<Self>>(_manuallyProven_Sendable__: first)
  }

  @export(implementation)
  public func first(where predicate: @Sendable @escaping (Output) -> Bool) -> some Publisher<Output, Failure> & Sendable {
    let first = Publishers.FirstWhere(upstream: self, predicate: predicate)
    return SendableShell<Publishers.FirstWhere<Self>>(_manuallyProven_Sendable__: first)
  }

  @export(implementation)
  public func last() -> some Publisher<Output, Failure> & Sendable {
    let last = Publishers.Last(upstream: self)
    return SendableShell<Publishers.Last<Self>>(_manuallyProven_Sendable__: last)
  }

  @export(implementation)
  public func last(where predicate: @Sendable @escaping (Self.Output) -> Bool)
    -> some Publisher<Output, Failure> & Sendable {
    let lastWhere = Publishers.LastWhere(upstream: self, predicate: predicate)
    return SendableShell<Publishers.LastWhere<Self>>(_manuallyProven_Sendable__: lastWhere)
  }

  @export(implementation)
  public func output(at index: Int) -> some Publisher<Output, Failure> & Sendable {
    let outputAt = self.Combine::output(at: index)
    return SendableShell<Publishers.Output<Self>>(_manuallyProven_Sendable__: outputAt)
  }

  @export(implementation)
  public func output<R: RangeExpression>(in range: R) -> some Publisher<Output, Failure> & Sendable where R.Bound == Int {
    let outputIn = self.Combine::output(in: range)
    return SendableShell<Publishers.Output<Self>>(_manuallyProven_Sendable__: outputIn)
  }
}

// MARK: - Matching

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func allSatisfy(_ predicate: @Sendable @escaping (Output) -> Bool) -> some Publisher<Bool, Failure> & Sendable {
    let allSatisfy = Publishers.AllSatisfy(upstream: self, predicate: predicate)
    return SendableShell<Publishers.AllSatisfy<Self>>(_manuallyProven_Sendable__: allSatisfy)
  }

  @export(implementation)
  public func contains(_ output: Output) -> some Publisher<Bool, Failure> & Sendable where Output: Equatable & Sendable {
    let contains = Publishers.Contains(upstream: self, output: output)
    return SendableShell<Publishers.Contains<Self>>(_manuallyProven_Sendable__: contains)
  }

  @export(implementation)
  public func contains(where predicate: @Sendable @escaping (Output) -> Bool) -> some Publisher<Bool, Failure> & Sendable {
    let contains = Publishers.ContainsWhere(upstream: self, predicate: predicate)
    return SendableShell<Publishers.ContainsWhere<Self>>(_manuallyProven_Sendable__: contains)
  }
}
