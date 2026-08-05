//
//  Combining.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

extension SendableShell {
  // MARK: - Merge
  
  @export(implementation)
  public func merge<P: Publisher & Sendable>(with other: P)
    -> SendableShell<Publishers.Merge<Upstream, P>> where P.Output == Output, P.Failure == Failure {
    let merged = Publishers.Merge(self._base, other)
    return SendableShell<Publishers.Merge<Upstream, P>>(_unverified_SendablePublisher__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable>(
    with b: B,
    c: C
  ) -> SendableShell<Publishers.Merge3<Upstream, B, C>>
  where B.Output == Output, B.Failure == Failure,
        C.Output == Output, C.Failure == Failure {
    let merged = Publishers.Merge3(self._base, b, c)
    return SendableShell<Publishers.Merge3<Upstream, B, C>>(_unverified_SendablePublisher__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D
  ) -> SendableShell<Publishers.Merge4<Upstream, B, C, D>>
  where B.Output == Output, B.Failure == Failure,
        C.Output == Output, C.Failure == Failure,
        D.Output == Output, D.Failure == Failure {
    let merged = Publishers.Merge4(self._base, b, c, d)
    return SendableShell<Publishers.Merge4<Upstream, B, C, D>>(_unverified_SendablePublisher__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable, E: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
    e: E
  ) -> SendableShell<Publishers.Merge5<Upstream, B, C, D, E>>
  where B.Output == Output, B.Failure == Failure,
        C.Output == Output, C.Failure == Failure,
        D.Output == Output, D.Failure == Failure,
        E.Output == Output, E.Failure == Failure {
    let merged = Publishers.Merge5(self._base, b, c, d, e)
    return SendableShell<Publishers.Merge5<Upstream, B, C, D, E>>(_unverified_SendablePublisher__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable, E: Publisher & Sendable, F: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
    e: E,
    f: F
  ) -> SendableShell<Publishers.Merge6<Upstream, B, C, D, E, F>>
  where B.Output == Output, B.Failure == Failure,
        C.Output == Output, C.Failure == Failure,
        D.Output == Output, D.Failure == Failure,
        E.Output == Output, E.Failure == Failure,
        F.Output == Output, F.Failure == Failure {
    let merged = Publishers.Merge6(self._base, b, c, d, e, f)
    return SendableShell<Publishers.Merge6<Upstream, B, C, D, E, F>>(_unverified_SendablePublisher__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable, E: Publisher & Sendable, F: Publisher & Sendable, G: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
    e: E,
    f: F,
    g: G
  ) -> SendableShell<Publishers.Merge7<Upstream, B, C, D, E, F, G>>
  where B.Output == Output, B.Failure == Failure,
        C.Output == Output, C.Failure == Failure,
        D.Output == Output, D.Failure == Failure,
        E.Output == Output, E.Failure == Failure,
        F.Output == Output, F.Failure == Failure,
        G.Output == Output, G.Failure == Failure {
    let merged = Publishers.Merge7(self._base, b, c, d, e, f, g)
    return SendableShell<Publishers.Merge7<Upstream, B, C, D, E, F, G>>(_unverified_SendablePublisher__: merged)
  }

  @export(implementation)
  public func merge<B: Publisher & Sendable, C: Publisher & Sendable, D: Publisher & Sendable, E: Publisher & Sendable, F: Publisher & Sendable, G: Publisher & Sendable, H: Publisher & Sendable>(
    with b: B,
    c: C,
    d: D,
    e: E,
    f: F,
    g: G,
    h: H
  ) -> SendableShell<Publishers.Merge8<Upstream, B, C, D, E, F, G, H>>
  where B.Output == Output, B.Failure == Failure,
        C.Output == Output, C.Failure == Failure,
        D.Output == Output, D.Failure == Failure,
        E.Output == Output, E.Failure == Failure,
        F.Output == Output, F.Failure == Failure,
        G.Output == Output, G.Failure == Failure,
        H.Output == Output, H.Failure == Failure {
    let merged = Publishers.Merge8(self._base, b, c, d, e, f, g, h)
    return SendableShell<Publishers.Merge8<Upstream, B, C, D, E, F, G, H>>(_unverified_SendablePublisher__: merged)
  }

  @export(implementation)
  public func merge(with other: SendableShell<Upstream>, _ others: SendableShell<Upstream>...)
    -> SendableShell<Publishers.MergeMany<Upstream>> {
    let merged = Publishers.MergeMany([self._base, other._base] + others.map { $0._base })
    return SendableShell<Publishers.MergeMany<Upstream>>(_unverified_SendablePublisher__: merged)
  }
  
  // MARK: - CombineLatest
  
  @export(implementation)
  public func combineLatest<P: Publisher & Sendable>(
    _ other: P
  ) -> SendableShell<Publishers.CombineLatest<Upstream, P>> where P.Failure == Failure, P.Output: Sendable {
    let combined = Publishers.CombineLatest(self._base, other)
    return SendableShell<Publishers.CombineLatest<Upstream, P>>(_unverified_SendablePublisher__: combined)
  }
  
  @export(implementation)
  public func combineLatest<P1: Publisher & Sendable, P2: Publisher & Sendable>(
    _ other1: P1,
    _ other2: P2
  ) -> SendableShell<Publishers.CombineLatest3<Upstream, P1, P2>>
  where P1.Failure == Failure, P2.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable {
    let combined = Publishers.CombineLatest3(self._base, other1, other2)
    return SendableShell<Publishers.CombineLatest3<Upstream, P1, P2>>(_unverified_SendablePublisher__: combined)
  }
  
  @export(implementation)
  public func combineLatest<P1: Publisher & Sendable, P2: Publisher & Sendable, P3: Publisher & Sendable>(
    _ other1: P1,
    _ other2: P2,
    _ other3: P3
  ) -> SendableShell<Publishers.CombineLatest4<Upstream, P1, P2, P3>>
  where P1.Failure == Failure, P2.Failure == Failure, P3.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable, P3.Output: Sendable {
    let combined = Publishers.CombineLatest4(self._base, other1, other2, other3)
    return SendableShell<Publishers.CombineLatest4<Upstream, P1, P2, P3>>(_unverified_SendablePublisher__: combined)
  }
  
  @export(implementation)
  public func combineLatest<P: Publisher & Sendable, T>(
    _ other: P,
    transform: @Sendable @escaping (Output, P.Output) -> T
  ) -> SendableShell<Publishers.Map<Publishers.CombineLatest<Upstream, P>, T>>
  where P.Failure == Failure, P.Output: Sendable, T: Sendable {
    combineLatest(other).map(transform)
  }
  
  @export(implementation)
  public func combineLatest<P1: Publisher & Sendable, P2: Publisher & Sendable, T>(
    _ other1: P1,
    _ other2: P2,
    transform: @Sendable @escaping (Output, P1.Output, P2.Output) -> T
  ) -> SendableShell<Publishers.Map<Publishers.CombineLatest3<Upstream, P1, P2>, T>>
  where P1.Failure == Failure, P2.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable, T: Sendable {
    combineLatest(other1, other2).map(transform)
  }
  
  @export(implementation)
  public func combineLatest<P1: Publisher & Sendable, P2: Publisher & Sendable, P3: Publisher & Sendable, T>(
    _ other1: P1,
    _ other2: P2,
    _ other3: P3,
    transform: @Sendable @escaping (Output, P1.Output, P2.Output, P3.Output) -> T
  ) -> SendableShell<Publishers.Map<Publishers.CombineLatest4<Upstream, P1, P2, P3>, T>>
  where P1.Failure == Failure, P2.Failure == Failure, P3.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable,
        P3.Output: Sendable, T: Sendable {
    combineLatest(other1, other2, other3).map(transform)
  }
  
  // MARK: - Prepend / Append
  
  @export(implementation)
  public func prepend(_ elements: Output...)
    -> SendableShell<Publishers.Concatenate<Publishers.Sequence<[Output], Failure>, Upstream>> {
    let prepended = self._base.prepend(elements)
    return SendableShell<Publishers.Concatenate<Publishers.Sequence<[Output], Failure>, Upstream>>(_unverified_SendablePublisher__: prepended)
  }
  
  @export(implementation)
  public func prepend<S>(_ elements: S)
    -> SendableShell<Publishers.Concatenate<Publishers.Sequence<S, Upstream.Failure>, Upstream>>
    where S: Sequence, Self.Output == S.Element {
      let prepended = self._base.prepend(elements)
      return SendableShell<Publishers.Concatenate<Publishers.Sequence<S, Upstream.Failure>, Upstream>>(
        _unverified_SendablePublisher__: prepended
      )
  }
  
  @export(implementation)
  public func prepend<P: Publisher & Sendable>(_ publisher: P)
    -> SendableShell<Publishers.Concatenate<P, Upstream>> where P.Output == Output, P.Failure == Failure {
    let prepended = Publishers.Concatenate(prefix: publisher, suffix: self._base)
    return SendableShell<Publishers.Concatenate<P, Upstream>>(_unverified_SendablePublisher__: prepended)
  }
  
  @export(implementation)
  public func append(_ elements: Output...)
    -> SendableShell<Publishers.Concatenate<Upstream, Publishers.Sequence<[Output], Failure>>> {
    let appended = self._base.append(elements)
    return SendableShell<Publishers.Concatenate<Upstream, Publishers.Sequence<[Output], Failure>>>(_unverified_SendablePublisher__: appended)
  }
  
  @export(implementation)
  public func append<S>(_ elements: S)
    -> SendableShell<Publishers.Concatenate<Upstream, Publishers.Sequence<S, Upstream.Failure>>>
    where S: Sequence, Self.Output == S.Element {
      let appended = self._base.append(elements)
      return SendableShell<Publishers.Concatenate<Upstream, Publishers.Sequence<S, Upstream.Failure>>>(
        _unverified_SendablePublisher__: appended
      )
  }
  
  @export(implementation)
  public func append<P: Publisher & Sendable>(_ publisher: P)
    -> SendableShell<Publishers.Concatenate<Upstream, P>> where P.Output == Output, P.Failure == Failure {
    let appended = Publishers.Concatenate(prefix: self._base, suffix: publisher)
    return SendableShell<Publishers.Concatenate<Upstream, P>>(_unverified_SendablePublisher__: appended)
  }
  
  // MARK: - Zip
  
  @export(implementation)
  public func zip<P: Publisher & Sendable>(
    _ other: P
  ) -> SendableShell<Publishers.Zip<Upstream, P>> where P.Failure == Failure, P.Output: Sendable {
    let zipped = Publishers.Zip(self._base, other)
    return SendableShell<Publishers.Zip<Upstream, P>>(_unverified_SendablePublisher__: zipped)
  }
  
  @export(implementation)
  public func zip<P1: Publisher & Sendable, P2: Publisher & Sendable>(
    _ other1: P1,
    _ other2: P2
  ) -> SendableShell<Publishers.Zip3<Upstream, P1, P2>>
  where P1.Failure == Failure, P2.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable {
    let zipped = Publishers.Zip3(self._base, other1, other2)
    return SendableShell<Publishers.Zip3<Upstream, P1, P2>>(_unverified_SendablePublisher__: zipped)
  }
  
  @export(implementation)
  public func zip<P1: Publisher & Sendable, P2: Publisher & Sendable, P3: Publisher & Sendable>(
    _ other1: P1,
    _ other2: P2,
    _ other3: P3
  ) -> SendableShell<Publishers.Zip4<Upstream, P1, P2, P3>>
  where P1.Failure == Failure, P2.Failure == Failure, P3.Failure == Failure, P1.Output: Sendable, P2.Output: Sendable, P3.Output: Sendable {
    let zipped = Publishers.Zip4(self._base, other1, other2, other3)
    return SendableShell<Publishers.Zip4<Upstream, P1, P2, P3>>(_unverified_SendablePublisher__: zipped)
  }
  
  @export(implementation)
  public func zip<P: Publisher & Sendable, T>(
    _ other: P,
    transform: @Sendable @escaping (Output, P.Output) -> T
  ) -> SendableShell<Publishers.Map<Publishers.Zip<Upstream, P>, T>>
  where P.Failure == Failure, P.Output: Sendable {
    zip(other).map(transform)
  }
}
