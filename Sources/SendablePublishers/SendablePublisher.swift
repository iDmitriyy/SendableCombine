//
//  SendablePublisher.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

@_exported public import Combine

// MARK: - Protocol

public typealias SendablePublisher<Output: Sendable, Failure> = Publisher<Output, Failure> & Sendable
