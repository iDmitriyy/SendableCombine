//
//  SendablePublisherAliases.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 14.08.2026.
//

@_exported public import Combine

// MARK: - Protocol

public typealias SendablePublisher<Output: Sendable, Failure> = Publisher<Output, Failure> & Sendable

public typealias InfalliblePublisher<Output> = Publisher<Output, Never> & Sendable

public typealias AnyInfalliblePublisher<Output> = AnySendablePublisher<Output, Never>


// 1. ?? Shell Protocol

public protocol PublisherShell<Output, Failure>: Publisher {
  associatedtype Output
  associatedtype Failure
}

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func map<T>(_ transform: @Sendable @escaping (Output) -> T) -> Publishers.Map<Self, T> {
    Publishers.Map(upstream: self, transform: transform)
  }
}

extension Publishers {
  public struct MapSendable<Upstream, Output: Sendable>: Publisher, Sendable where Upstream: Publisher & Sendable {
    public typealias Failure = Upstream.Failure
    
    public let upstream: Upstream
    
    public let transform: @Sendable (Upstream.Output) -> Output
    
    public init(upstream: Upstream, transform: @Sendable @escaping (Upstream.Output) -> Output) {
      self.upstream = upstream
      self.transform = transform
    }
    
    public func receive<S>(subscriber: S) where S: Subscriber, Upstream.Failure == S.Failure, Output == S.Input {
      Publishers.Map(upstream: upstream, transform: transform).receive(subscriber: subscriber)
    }
  }
}

func test(a: any SendablePublisher<String, any Error>,
          b: any InfalliblePublisher<String>,
          c: AnyInfalliblePublisher<String>,
          d: AnySendablePublisher<String, any Error>,
          e: PassthroughSubject<String, Never>,
          f: PassthroughSubject<String, Never>) {
//  let aa = a.map2 { $0 }
//  b.map2 { $0 }
  let cc = c.map { $0 }
  let dd = d.map { $0 }
  let ee = e.map { $0 }
  let ff = f.map { $0 }
}

// PassthroughSubject + func asSendablePublisher() -> SendableShell<PassthroughSubject<Output, Failure>>
// currently subject need to call asSendablePublisher() before it allow to use SendableShell
// may be, instead of SendableShell, we reimplement the operators (using combine imps under the hood)?
// then we make extension to SendablePublisher protocol, and all kinds of sendable publishers get operators
// Driver / Signal can not conform to Publisher protocol, so they do not inherit list of Publisher protocols.
// But is there a harm of making Driver / Signal publishers? Can they overload concrete publishers with specific and
// inherit others? seems it is an overload-mess, and it would be better to use asPublisher() or
// asCurrentValuePublisher() to get full list of operators that Sendable publishers has.

// AnyCurrentValuePublisher seems don't need a shell, as shell might be omited at all.
// AnyCurrentValuePublisher can pass its __base to operators, and should share its operator imps with Driver
// (may via an internal protocol, but functions are defined as public which satisfies internal protocol conformance).
// Driver has also additional specific operators.

// 2. type-erasure Protocol (Driver, Signal)

// AnySendablePublisher AnyInfalliblePublisher InfalliblePublisher SendablePublisher

// AnyCurrentValuePublisher

//protocol ErasurePublisherProtocol {
//  associatedtype
//}

// so the main problem is that SendableShell has a set of operators that preserve sendability, while
// SendablePublisher, InfalliblePublisher & AnySendablePublisher do not preserve sendability.
