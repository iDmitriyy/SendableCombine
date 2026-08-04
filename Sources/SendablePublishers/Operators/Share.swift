//
//  Share.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 05.08.2026.
//

extension SendablePublisher_ {
  @export(implementation)
  public func share() -> SendablePublisher_<Publishers.Share<Upstream>> {
    let shared = Publishers.Share(upstream: self._base)
    return SendablePublisher_<Publishers.Share<Upstream>>(_unverified_SendablePublisher__: shared)
  }
}
