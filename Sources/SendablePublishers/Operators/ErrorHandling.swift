//
//  ErrorHandling.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func `catch`<P: Publisher & Sendable>(
    _ handler: @Sendable @escaping (Failure) -> P,
  ) -> some Publisher<P.Output, P.Failure> & Sendable where P.Output == Output, P.Failure == Failure {
    let caught = Publishers.Catch(upstream: self, handler: handler)
    return SendableShell<Publishers.Catch<Self, P>>(_manuallyProven_Sendable__: caught)
  }

  @export(implementation)
  public func tryCatch<P: Publisher & Sendable>(
    _ handler: @Sendable @escaping (Failure) throws -> P,
  ) -> some Publisher<P.Output, any Error> & Sendable where P.Output == Output, P.Failure == Failure {
    let caught = Publishers.TryCatch(upstream: self, handler: handler)
    return SendableShell<Publishers.TryCatch<Self, P>>(_manuallyProven_Sendable__: caught)
  }

  @export(implementation)
  public func retry(_ retries: Int) -> some Publisher<Output, Failure> & Sendable {
    let retried = Publishers.Retry(upstream: self, retries: retries)
    return SendableShell<Publishers.Retry<Self>>(_manuallyProven_Sendable__: retried)
  }

  @export(implementation)
  public func replaceError(with output: Output) -> some Publisher<Output, Never> & Sendable {
    let replaced = Publishers.ReplaceError(upstream: self, output: output)
    return SendableShell<Publishers.ReplaceError<Self>>(_manuallyProven_Sendable__: replaced)
  }

  @export(implementation)
  public func replaceEmpty(with output: Output) -> some Publisher<Output, Failure> & Sendable {
    let replaced = Publishers.ReplaceEmpty(upstream: self, output: output)
    return SendableShell<Publishers.ReplaceEmpty<Self>>(_manuallyProven_Sendable__: replaced)
  }

  @export(implementation)
  public func assertNoFailure(
    _ prefix: String = "",
    file: StaticString = #file,
    line: UInt = #line,
  ) -> some Publisher<Output, Failure> & Sendable where Self.Failure == Never {
    let asserted = Publishers.AssertNoFailure(upstream: self, prefix: prefix, file: file, line: line)
    return SendableShell<Publishers.AssertNoFailure<Self>>(_manuallyProven_Sendable__: asserted)
  }
}

extension Publisher where Self: Sendable, Output: Sendable, Failure == Never {
  @export(implementation)
  public func setFailureType<E: Error>(to _: E.Type) -> some Publisher<Output, E> & Sendable {
    let setFailure = Publishers.SetFailureType<Self, E>(upstream: self)
    return SendableShell<Publishers.SetFailureType<Self, E>>(_manuallyProven_Sendable__: setFailure)
  }
}
