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

//func test(a: any SendablePublisher<String, any Error>,
//          b: any InfalliblePublisher<String>,
//          c: AnyInfalliblePublisher<String>,
//          d: AnySendablePublisher<String, any Error>,
//          e: PassthroughSubject<String, Never>,
//          f: CurrentValueSubject<String, Never>) {
//  let aa = a.map { $0 }
//  let bb = b.map { $0 }
//  let cc = c.map { $0 }
//  let dd = d.map { $0 }
//  let ee = e.map { $0 }
//  let ff = f.map { $0 }
//}
