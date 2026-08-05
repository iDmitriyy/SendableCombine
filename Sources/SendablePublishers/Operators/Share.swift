//
//  Share.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendableShell {
  @export(implementation)
  public func share() -> SendableShell<Publishers.Share<Upstream>> {
    let shared = Publishers.Share(upstream: self._base)
    return SendableShell<Publishers.Share<Upstream>>(_unverified_SendablePublisher__: shared)
  }
}
