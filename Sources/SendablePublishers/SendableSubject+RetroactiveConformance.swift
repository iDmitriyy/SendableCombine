//
//  SendableSubject.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 04.08.2026.
//

extension PassthroughSubject: @retroactive @unchecked Sendable where Output: Sendable {}

extension CurrentValueSubject: @retroactive @unchecked Sendable where Output: Sendable {}
