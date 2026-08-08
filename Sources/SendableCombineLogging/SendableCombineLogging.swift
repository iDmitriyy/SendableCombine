//
//  SendableCombineLogging.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 08.08.2026.
//

import os

// MARK: - Log Level

public enum SendableCombineLogLevel: Sendable, Equatable {
  case warning
  case critical
}

// MARK: - Log Entry

public typealias SendableCombineErrorInfo = [String: any Sendable & Equatable & CustomStringConvertible]

public struct SendableCombineLogEntry: Sendable {
  public let code: Int
  public let codeString: String
  public let message: String
  public let info: SendableCombineErrorInfo
  public let file: StaticString
  public let line: UInt
  
  // TODO: - does file / line needed? seems no
  @_transparent
  package init(code: SendableCombineInternalErrorCode,
               message: String,
               info: SendableCombineErrorInfo = [:],
               file: StaticString = #fileID,
               line: UInt = #line) {
    self.code = code.rawValue
    codeString = "\(code)"
    self.message = message
    self.info = info
    self.file = file
    self.line = line
  }
}

// MARK: - Internal Error Codes

package enum SendableCombineInternalErrorCode: Int, Sendable {
  case loggingObserverReinjection
  case unexpectedNilObject

  case driverInitialValueDropped

  case upstreamTerminatedWithCompletion
  case upstreamTerminatedWithFailure

  case unexpectedCodeEntrance
}

// MARK: - Logging

public typealias SendableCombineLoggingObserver =
  @Sendable ((level: SendableCombineLogLevel, entry: SendableCombineLogEntry)) -> Void

package enum SendableCombineLogging {
  fileprivate static let _observer = OSAllocatedUnfairLock<SendableCombineLoggingObserver?>(uncheckedState: nil)

  public static func injectOnce(loggingObserver: sending @escaping SendableCombineLoggingObserver) {
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
    /// Test-only hook to allow a fresh observer to be injected between serialized tests.
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
