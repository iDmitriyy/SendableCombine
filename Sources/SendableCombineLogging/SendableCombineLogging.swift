//
//  SendableCombineLogging.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 08.08.2026.
//

import os

// MARK: - Log Level

package enum SendableCombineLogLevel: Sendable, Equatable {
  case warning
  case critical
}

// MARK: - Log Entry

package typealias SendableCombineErrorInfo = [String: any Sendable & Equatable & CustomStringConvertible]

package struct SendableCombineLogEntry: Sendable {
  package let code: Int
  package let codeString: String
  package let message: String
  package let info: SendableCombineErrorInfo
  package let file: StaticString
  package let line: UInt

  package init(code: Int,
               codeString: String,
               message: String,
               info: SendableCombineErrorInfo = [:],
               file: StaticString = #fileID,
               line: UInt = #line) {
    self.code = code
    self.codeString = codeString
    self.message = message
    self.info = info
    self.file = file
    self.line = line
  }
}

extension SendableCombineLogEntry {
  package init(code: SendableCombineInternalErrorCode,
               message: String,
               info: SendableCombineErrorInfo = [:],
               file: StaticString = #fileID,
               line: UInt = #line) {
    self.init(code: code.rawValue, codeString: "\(code)", message: message, info: info, file: file, line: line)
  }
}

// MARK: - Internal Error Codes

package enum SendableCombineInternalErrorCode: Int, Sendable {
  case loggingObserverReinjection = 0
  case unexpectedNilObject = 1

  case driverUpstreamTerminatedWithCompletion = 20
  case driverUpstreamTerminatedWithFailure
  case driverInitialValueDropped

  case signalUpstreamTerminatedWithCompletion = 30
  case signalUpstreamTerminatedWithFailure

  case unexpectedCodeEntrance
}

// MARK: - Logging

package typealias SendableCombineLoggingObserver =
  @Sendable ((level: SendableCombineLogLevel, entry: SendableCombineLogEntry)) -> Void

package enum SendableCombineLogging {
  fileprivate static let _observer = OSAllocatedUnfairLock<SendableCombineLoggingObserver?>(uncheckedState: nil)

  package static func injectOnce(loggingObserver: sending @escaping SendableCombineLoggingObserver) {
    let conflict = _observer.withLockUnchecked { maybeObserver -> (SendableCombineLoggingObserver, SendableCombineLoggingObserver)? in
      if let injectedObserver = maybeObserver {
        return (injectedObserver, loggingObserver)
      } else {
        maybeObserver = loggingObserver
        return nil
      }
    }

    if let (existingObserver, newObserver) = conflict {
      let entry = SendableCombineLogEntry(code: .loggingObserverReinjection,
                                          message: "Trying to inject a logging observer more than once.")
      existingObserver((level: .warning, entry: entry))
      newObserver((level: .warning, entry: entry))
      assertionFailure("Trying to inject a logging observer more than once.")
    }
  }

  #if DEBUG
  /// Test-only hook to allow a fresh observer to be injected between tests.
  internal static func _resetObserverForTesting() {
    _observer.withLockUnchecked { maybeObserver in
      maybeObserver = nil
    }
  }
  #endif
}

// MARK: - Logging

package func _log(_ level: SendableCombineLogLevel, _ entry: SendableCombineLogEntry) {
  SendableCombineLogging._observer.withLockUnchecked { $0 }?((level: level, entry: entry))

  if level == .critical {
    let message = "SendableCombine error – code: \(entry.code) (\(entry.codeString)), message: \(entry.message)"
    assertionFailure(message)
  }
}
