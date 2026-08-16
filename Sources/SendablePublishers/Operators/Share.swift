//
//  Share.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension Publisher where Self: Sendable, Output: Sendable {
  @export(implementation)
  public func share() -> some Publisher<Output, Failure> & Sendable {
    let shared = Publishers.Share(upstream: self)
    return SendableShell<Publishers.Share<Self>>(_manuallyProven_Sendable__: shared)
  }
}
