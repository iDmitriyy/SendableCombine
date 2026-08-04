//
//  ErrorHandling.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendablePublisher_ {
  @export(implementation)
  public func `catch`<P: Publisher & Sendable>(
    _ handler: @Sendable @escaping (Failure) -> P
  ) -> SendablePublisher_<Publishers.Catch<Upstream, P>> where P.Output == Output, P.Failure == Failure {
    let caught = Publishers.Catch(upstream: self._base, handler: handler)
    return SendablePublisher_<Publishers.Catch<Upstream, P>>(_unverified_SendablePublisher__: caught)
  }
  
  @export(implementation)
  public func tryCatch<P: Publisher & Sendable>(
    _ handler: @Sendable @escaping (Failure) throws -> P
  ) -> SendablePublisher_<Publishers.TryCatch<Upstream, P>> where P.Output == Output, P.Failure == Failure {
    let caught = Publishers.TryCatch(upstream: self._base, handler: handler)
    return SendablePublisher_<Publishers.TryCatch<Upstream, P>>(_unverified_SendablePublisher__: caught)
  }
  
  @export(implementation)
  public func retry(_ retries: Int) -> SendablePublisher_<Publishers.Retry<Upstream>> {
    let retried = Publishers.Retry(upstream: self._base, retries: retries)
    return SendablePublisher_<Publishers.Retry<Upstream>>(_unverified_SendablePublisher__: retried)
  }
  
  @export(implementation)
  public func replaceError(with output: Output) -> SendablePublisher_<Publishers.ReplaceError<Upstream>> {
    let replaced = Publishers.ReplaceError(upstream: self._base, output: output)
    return SendablePublisher_<Publishers.ReplaceError<Upstream>>(_unverified_SendablePublisher__: replaced)
  }
  
  @export(implementation)
  public func replaceEmpty(with output: Output) -> SendablePublisher_<Publishers.ReplaceEmpty<Upstream>> {
    let replaced = Publishers.ReplaceEmpty(upstream: self._base, output: output)
    return SendablePublisher_<Publishers.ReplaceEmpty<Upstream>>(_unverified_SendablePublisher__: replaced)
  }
  
  @export(implementation)
  public func assertNoFailure(
    _ prefix: String = "",
    file: StaticString = #file,
    line: UInt = #line
  ) -> SendablePublisher_<Publishers.AssertNoFailure<Upstream>> {
    let asserted = Publishers.AssertNoFailure(upstream: self._base, prefix: prefix, file: file, line: line)
    return SendablePublisher_<Publishers.AssertNoFailure<Upstream>>(_unverified_SendablePublisher__: asserted)
  }
}

extension SendablePublisher_ where Upstream.Failure == Never {
  @export(implementation)
  public func setFailureType<E: Error>(to _: E.Type) -> SendablePublisher_<Publishers.SetFailureType<Upstream, E>> {
    let setFailure = Publishers.SetFailureType<Upstream, E>(upstream: self._base)
    return SendablePublisher_<Publishers.SetFailureType<Upstream, E>>(_unverified_SendablePublisher__: setFailure)
  }
}
