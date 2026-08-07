//
//  InfalliblePublisher.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public typealias InfalliblePublisher<Output> = Publisher<Output, Never>

public typealias AnyInfalliblePublisher<Output> = AnyPublisher<Output, Never>
