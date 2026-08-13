//
//  Share.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendableShell {
  @export(implementation)
  public func share() -> SendableShell<Publishers.Share<Upstream>> {
    let shared = Publishers.Share(upstream: _base)
    return SendableShell<Publishers.Share<Upstream>>(_manuallyProven_Sendable__: shared)
  }
}
