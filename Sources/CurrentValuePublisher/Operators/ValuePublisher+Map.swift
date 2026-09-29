//
//  ValuePublisher+Map.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 17.07.2026.
//

extension AnyCurrentValuePublisher {
  @export(implementation) @_transparent
  public func map<T>(_ transform: @Sendable @escaping (Output) -> T) -> AnyCurrentValuePublisher<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return AnyCurrentValuePublisher<T, Failure>(manuallyProven_SemiSendable: map)
  }
}


/*
 ValuePublisher operators:
 map combineLatest prepend scan(and all variants)? merge(if oneOf is ValuePublisher) throttle? flatMap? replaceError? removeDuplicates singleElement
 zip replaceNil(with: T) mapError catch share shareReplay(1) multicast(subject:)
 eraseToAnyPublisher handleEvents breakpoint | all sideEffects
 previousAndCurrent

 HotPublisher operators:
 debounce delay

 при прямой подписке (без share) removeDuplicates всегда немедленно эмитит значение, потому что каждый раз
 создаётся новый оператор без истории
 */
