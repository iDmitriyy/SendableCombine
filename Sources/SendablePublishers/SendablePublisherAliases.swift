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
