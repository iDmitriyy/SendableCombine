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

public typealias SendableErrorInfo = [String: any Sendable & Equatable & CustomStringConvertible]

public struct SendableCombineLogEntry: Sendable {
  public let code: Int
  public let codeString: String
  public let message: String
  public let info: SendableErrorInfo

  // TODO: - does file / line needed? seems no as the will reflect file / line inside this library.
  // It might be better by default assert warning with option to disable assertion.
  // Also collect log events in temp buffer to replay them in logger injection. Injection the might happen
  // asynchronously in .lowPriority, no in app delegate.
  // Besides that instead of file / line, it would be better to provide info about Driver / Signal and theier
  // Upstream chain with types.
  @_transparent
  package init(code: SendableCombineInternalErrorCode,
               message: String,
               info: SendableErrorInfo = [:]) {
    self.code = code.rawValue
    codeString = "\(code)"
    self.message = message
    self.info = info
  }
}

// MARK: - Internal Error Codes

package enum SendableCombineInternalErrorCode: Int, Sendable {
  // Enum raw values must remain stable and unchanged over time
  // Modifying them will break backwards compatibility with existing logs or external systems.

  case loggingObserverReinjection = 0

  case driverInitialValueDropped = 10

  case upstreamTerminatedWithCompletion = 31
  case upstreamTerminatedWithFailure = 32

  case unexpectedNilObject = 50
  case unexpectedCodeEntrance = 51
}

// MARK: - Logging

public typealias SendableCombineLoggingObserver =
  @Sendable ((level: SendableCombineLogLevel, entry: SendableCombineLogEntry)) -> Void

package enum SendableCombineLogging {
  fileprivate static let _observer = OSAllocatedUnfairLock<SendableCombineLoggingObserver?>(initialState: nil)

  public static func injectOnce(loggingObserver: sending @escaping SendableCombineLoggingObserver) {
    let conflict = _observer
      .withLockUnchecked { maybeObserver -> (SendableCombineLoggingObserver, SendableCombineLoggingObserver)? in
        if let alreadyInjectedObserver = maybeObserver {
          return (alreadyInjectedObserver, loggingObserver)
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
      assertionFailure("Trying to inject a logging observer more than once is not allowed.")
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
  let logger = SendableCombineLogging._observer.withLockUnchecked { $0 }
  logger?((level: level, entry: entry))
}
