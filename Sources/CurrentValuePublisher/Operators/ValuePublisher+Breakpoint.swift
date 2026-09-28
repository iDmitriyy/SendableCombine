//
//  ValuePublisher+Breakpoint.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 28.09.2026.
//

extension AnyCurrentValuePublisher {
  /// Triggers a debugger breakpoint on each emitted value without altering the stream.
  ///
  /// A side-effect operator useful for debugging: execution pauses at the next value
  /// so you can inspect state. The stream is forwarded unchanged.
  @export(implementation) @_transparent
  public func breakpoint() -> Self {
    handleEvents(receiveOutput: { _ in
      __debugBreakpoint()
    })
  }
}
