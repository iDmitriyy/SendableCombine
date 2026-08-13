//
//  ErrorHandling.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendableShell {
  @export(implementation)
  public func `catch`<P: Publisher & Sendable>(
    _ handler: @Sendable @escaping (Failure) -> P,
  ) -> SendableShell<Publishers.Catch<Upstream, P>> where P.Output == Output, P.Failure == Failure {
    let caught = Publishers.Catch(upstream: _base, handler: handler)
    return SendableShell<Publishers.Catch<Upstream, P>>(_manuallyProven_Sendable__: caught)
  }

  @export(implementation)
  public func tryCatch<P: Publisher & Sendable>(
    _ handler: @Sendable @escaping (Failure) throws -> P,
  ) -> SendableShell<Publishers.TryCatch<Upstream, P>> where P.Output == Output, P.Failure == Failure {
    let caught = Publishers.TryCatch(upstream: _base, handler: handler)
    return SendableShell<Publishers.TryCatch<Upstream, P>>(_manuallyProven_Sendable__: caught)
  }

  @export(implementation)
  public func retry(_ retries: Int) -> SendableShell<Publishers.Retry<Upstream>> {
    let retried = Publishers.Retry(upstream: _base, retries: retries)
    return SendableShell<Publishers.Retry<Upstream>>(_manuallyProven_Sendable__: retried)
  }

  @export(implementation)
  public func replaceError(with output: Output) -> SendableShell<Publishers.ReplaceError<Upstream>> {
    let replaced = Publishers.ReplaceError(upstream: _base, output: output)
    return SendableShell<Publishers.ReplaceError<Upstream>>(_manuallyProven_Sendable__: replaced)
  }

  @export(implementation)
  public func replaceEmpty(with output: Output) -> SendableShell<Publishers.ReplaceEmpty<Upstream>> {
    let replaced = Publishers.ReplaceEmpty(upstream: _base, output: output)
    return SendableShell<Publishers.ReplaceEmpty<Upstream>>(_manuallyProven_Sendable__: replaced)
  }

  @export(implementation)
  public func assertNoFailure(
    _ prefix: String = "",
    file: StaticString = #file,
    line: UInt = #line,
  ) -> SendableShell<Publishers.AssertNoFailure<Upstream>> {
    let asserted = Publishers.AssertNoFailure(upstream: _base, prefix: prefix, file: file, line: line)
    return SendableShell<Publishers.AssertNoFailure<Upstream>>(_manuallyProven_Sendable__: asserted)
  }
}

extension SendableShell where Upstream.Failure == Never {
  @export(implementation)
  public func setFailureType<E: Error>(to _: E.Type) -> SendableShell<Publishers.SetFailureType<Upstream, E>> {
    let setFailure = Publishers.SetFailureType<Upstream, E>(upstream: _base)
    return SendableShell<Publishers.SetFailureType<Upstream, E>>(_manuallyProven_Sendable__: setFailure)
  }
}
