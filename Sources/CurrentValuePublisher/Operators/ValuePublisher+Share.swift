//
//  ValuePublisher+Share.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

import os
public import SendablePublishers

// MARK: - Share-Replay

extension AnyCurrentValuePublisher where Failure == Never {
  /// Shares the underlying computation chain across multiple subscribers.
  ///
  /// Automatically connects to the upstream upon the first subscription.
  /// Cancels the upstream connection when the active subscriber count drops to zero,
  /// and transparently triggers a new connection while preserving the Replay 1 contract
  /// on any subsequent resubscription.
  @export(implementation)
  public func share() -> Self {
    let pipeline = self.Combine::makeConnectable().Combine::autoconnect()

    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: pipeline.eraseToAnyPublisher())
  }
}

extension AnyCurrentValuePublisher where Output: Sendable, Failure == Never {
  /// Shares the underlying computation chain across multiple subscribers.
  ///
  /// Automatically connects to the upstream upon the first subscription.
  /// Cancels the upstream connection when the active subscriber count drops to zero,
  /// and transparently triggers a new connection while preserving the Replay 1 contract
  /// on any subsequent resubscription.
  @export(implementation)
  public func share() -> Self {
    let pipeline: any Publisher<Output, Failure> & Sendable =
      self.SendablePublishers::makeConnectable().SendablePublishers::autoconnect()
    
    return AnyCurrentValuePublisher(manuallyProven_SemiSendable: pipeline.eraseToAnyPublisher())
  }
}
