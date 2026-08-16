//
//  Combining.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  // MARK: - Merge

  @export(implementation)
  public func merge<P: Publisher & Sendable>(with other: P)
    -> some Publisher<Output, Failure> & Sendable where P.Output == Output, P.Failure == Failure {
    let merged = Publishers.Merge(self, other)
    return SendableShell<Publishers.Merge<Self, P>>(_manuallyProven_Sendable__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable>(
    with b: B,
    c: C,
  ) -> some Publisher<Output, Failure> & Sendable
    where B.Output == Output, B.Failure == Failure,
    C.Output == Output, C.Failure == Failure {
    let merged = Publishers.Merge3(self, b, c)
    return SendableShell<Publishers.Merge3<Self, B, C>>(_manuallyProven_Sendable__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
  ) -> some Publisher<Output, Failure> & Sendable
    where B.Output == Output, B.Failure == Failure,
    C.Output == Output, C.Failure == Failure,
    D.Output == Output, D.Failure == Failure {
    let merged = Publishers.Merge4(self, b, c, d)
    return SendableShell<Publishers.Merge4<Self, B, C, D>>(_manuallyProven_Sendable__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable, E: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
    e: E,
  ) -> some Publisher<Output, Failure> & Sendable
    where B.Output == Output, B.Failure == Failure,
    C.Output == Output, C.Failure == Failure,
    D.Output == Output, D.Failure == Failure,
    E.Output == Output, E.Failure == Failure {
    let merged = Publishers.Merge5(self, b, c, d, e)
    return SendableShell<Publishers.Merge5<Self, B, C, D, E>>(_manuallyProven_Sendable__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable, E: Publisher & Sendable, F: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
    e: E,
    f: F,
  ) -> some Publisher<Output, Failure> & Sendable
    where B.Output == Output, B.Failure == Failure,
    C.Output == Output, C.Failure == Failure,
    D.Output == Output, D.Failure == Failure,
    E.Output == Output, E.Failure == Failure,
    F.Output == Output, F.Failure == Failure {
    let merged = Publishers.Merge6(self, b, c, d, e, f)
    return SendableShell<Publishers.Merge6<Self, B, C, D, E, F>>(_manuallyProven_Sendable__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable, E: Publisher & Sendable, F: Publisher & Sendable, G: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
    e: E,
    f: F,
    g: G,
  ) -> some Publisher<Output, Failure> & Sendable
    where B.Output == Output, B.Failure == Failure,
    C.Output == Output, C.Failure == Failure,
    D.Output == Output, D.Failure == Failure,
    E.Output == Output, E.Failure == Failure,
    F.Output == Output, F.Failure == Failure,
    G.Output == Output, G.Failure == Failure {
    let merged = Publishers.Merge7(self, b, c, d, e, f, g)
    return SendableShell<Publishers.Merge7<Self, B, C, D, E, F, G>>(_manuallyProven_Sendable__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable, E: Publisher & Sendable, F: Publisher & Sendable, G: Publisher & Sendable, H: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
    e: E,
    f: F,
    g: G,
    h: H,
  ) -> some Publisher<Output, Failure> & Sendable
    where B.Output == Output, B.Failure == Failure,
    C.Output == Output, C.Failure == Failure,
    D.Output == Output, D.Failure == Failure,
    E.Output == Output, E.Failure == Failure,
    F.Output == Output, F.Failure == Failure,
    G.Output == Output, G.Failure == Failure,
    H.Output == Output, H.Failure == Failure {
    let merged = Publishers.Merge8(self, b, c, d, e, f, g, h)
    return SendableShell<Publishers.Merge8<Self, B, C, D, E, F, G, H>>(_manuallyProven_Sendable__: merged)
  }

  @export(implementation)
  public func merge(with other: Self, _ others: Self...)
    -> some Publisher<Output, Failure> & Sendable {
    let merged = Publishers.MergeMany([self, other] + others)
    return SendableShell<Publishers.MergeMany<Self>>(_manuallyProven_Sendable__: merged)
  }

  // MARK: - CombineLatest

  @export(implementation)
  public func combineLatest<P: Publisher & Sendable>(
    _ other: P,
  ) -> some Publisher<(Output, P.Output), Failure> & Sendable where P.Failure == Failure, P.Output: Sendable {
    let combined = Publishers.CombineLatest(self, other)
    return SendableShell<Publishers.CombineLatest<Self, P>>(_manuallyProven_Sendable__: combined)
  }

  @export(implementation)
  public func combineLatest<P1: Publisher & Sendable, P2: Publisher & Sendable>(
    _ other1: P1,
    _ other2: P2,
  ) -> some Publisher<(Output, P1.Output, P2.Output), Failure> & Sendable
    where P1.Failure == Failure, P2.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable {
    let combined = Publishers.CombineLatest3(self, other1, other2)
    return SendableShell<Publishers.CombineLatest3<Self, P1, P2>>(_manuallyProven_Sendable__: combined)
  }

  @export(implementation)
  public func combineLatest<P1: Publisher & Sendable, P2: Publisher & Sendable, P3: Publisher & Sendable>(
    _ other1: P1,
    _ other2: P2,
    _ other3: P3,
  ) -> some Publisher<(Output, P1.Output, P2.Output, P3.Output), Failure> & Sendable
    where P1.Failure == Failure, P2.Failure == Failure, P3.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable, P3.Output: Sendable {
    let combined = Publishers.CombineLatest4(self, other1, other2, other3)
    return SendableShell<Publishers.CombineLatest4<Self, P1, P2, P3>>(_manuallyProven_Sendable__: combined)
  }

  @export(implementation)
  public func combineLatest<P: Publisher & Sendable, T: Sendable>(
    _ other: P,
    transform: @Sendable @escaping (Output, P.Output) -> T,
  ) -> some Publisher<T, Failure> & Sendable
    where P.Failure == Failure, P.Output: Sendable {
    combineLatest(other).map(transform)
  }

  @export(implementation)
  public func combineLatest<P1: Publisher & Sendable, P2: Publisher & Sendable, T: Sendable>(
    _ other1: P1,
    _ other2: P2,
    transform: @Sendable @escaping (Output, P1.Output, P2.Output) -> T,
  ) -> some Publisher<T, Failure> & Sendable
    where P1.Failure == Failure, P2.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable {
    combineLatest(other1, other2).map(transform)
  }

  @export(implementation)
  public func combineLatest<P1: Publisher & Sendable, P2: Publisher & Sendable, P3: Publisher & Sendable, T: Sendable>(
    _ other1: P1,
    _ other2: P2,
    _ other3: P3,
    transform: @Sendable @escaping (Output, P1.Output, P2.Output, P3.Output) -> T,
  ) -> some Publisher<T, Failure> & Sendable
    where P1.Failure == Failure, P2.Failure == Failure, P3.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable,
    P3.Output: Sendable {
    combineLatest(other1, other2, other3).map(transform)
  }

  // MARK: - Prepend / Append

  @export(implementation)
  public func prepend(_ elements: Output...)
    -> some Publisher<Output, Failure> & Sendable {
    let prepended = self.Combine::prepend(elements)
    return SendableShell<Publishers.Concatenate<Publishers.Sequence<[Output], Failure>, Self>>(_manuallyProven_Sendable__: prepended)
  }

  @export(implementation)
  public func prepend<S: Sequence>(_ elements: S)
    -> some Publisher<Output, Failure> & Sendable
    where Self.Output == S.Element {
    let prepended = self.Combine::prepend(elements)
    return SendableShell<Publishers.Concatenate<Publishers.Sequence<S, Failure>, Self>>(
      _manuallyProven_Sendable__: prepended,
    )
  }

  @export(implementation)
  public func prepend<P: Publisher & Sendable>(_ publisher: P)
    -> some Publisher<Output, Failure> & Sendable where P.Output == Output, P.Failure == Failure {
    let prepended = Publishers.Concatenate(prefix: publisher, suffix: self)
    return SendableShell<Publishers.Concatenate<P, Self>>(_manuallyProven_Sendable__: prepended)
  }

  @export(implementation)
  public func append(_ elements: Output...)
    -> some Publisher<Output, Failure> & Sendable {
    let appended = self.Combine::append(elements)
    return SendableShell<Publishers.Concatenate<Self, Publishers.Sequence<[Output], Failure>>>(_manuallyProven_Sendable__: appended)
  }

  @export(implementation)
  public func append<S: Sequence>(_ elements: S)
    -> some Publisher<Output, Failure> & Sendable
    where Self.Output == S.Element {
    let appended = self.Combine::append(elements)
    return SendableShell<Publishers.Concatenate<Self, Publishers.Sequence<S, Failure>>>(
      _manuallyProven_Sendable__: appended,
    )
  }

  @export(implementation)
  public func append<P: Publisher & Sendable>(_ publisher: P)
    -> some Publisher<Output, Failure> & Sendable where P.Output == Output, P.Failure == Failure {
    let appended = Publishers.Concatenate(prefix: self, suffix: publisher)
    return SendableShell<Publishers.Concatenate<Self, P>>(_manuallyProven_Sendable__: appended)
  }

  // MARK: - Zip

  @export(implementation)
  public func zip<P: Publisher & Sendable>(
    _ other: P,
  ) -> some Publisher<(Output, P.Output), Failure> & Sendable where P.Failure == Failure, P.Output: Sendable {
    let zipped = Publishers.Zip(self, other)
    return SendableShell<Publishers.Zip<Self, P>>(_manuallyProven_Sendable__: zipped)
  }

  @export(implementation)
  public func zip<P1: Publisher & Sendable, P2: Publisher & Sendable>(
    _ other1: P1,
    _ other2: P2,
  ) -> some Publisher<(Output, P1.Output, P2.Output), Failure> & Sendable
    where P1.Failure == Failure, P2.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable {
    let zipped = Publishers.Zip3(self, other1, other2)
    return SendableShell<Publishers.Zip3<Self, P1, P2>>(_manuallyProven_Sendable__: zipped)
  }

  @export(implementation)
  public func zip<P1: Publisher & Sendable, P2: Publisher & Sendable, P3: Publisher & Sendable>(
    _ other1: P1,
    _ other2: P2,
    _ other3: P3,
  ) -> some Publisher<(Output, P1.Output, P2.Output, P3.Output), Failure> & Sendable
    where P1.Failure == Failure, P2.Failure == Failure, P3.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable, P3.Output: Sendable {
    let zipped = Publishers.Zip4(self, other1, other2, other3)
    return SendableShell<Publishers.Zip4<Self, P1, P2, P3>>(_manuallyProven_Sendable__: zipped)
  }

  @export(implementation)
  public func zip<P: Publisher & Sendable, T: Sendable>(
    _ other: P,
    transform: @Sendable @escaping (Output, P.Output) -> T,
  ) -> some Publisher<T, Failure> & Sendable
    where P.Failure == Failure, P.Output: Sendable {
    zip(other).map(transform)
  }
}
