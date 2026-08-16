//
//  SendableCombineLogging.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 08.08.2026.
//

#if DEBUG
  import os
#endif
import Synchronization

// MARK: - Log Level

public enum SendableCombineLogLevel: Sendable, Equatable {
  case warning
  case critical
}

// MARK: - Log Entry

public typealias SendableErrorInfo = [String: String]

public final class SendableCombineLogEntry: Sendable {
  public let code: Int
  public let codeString: String
  public let message: String
  public let info: SendableErrorInfo

  // TODO: - collect log events in temp buffer to replay them in logger injection. Injection the might happen
  // asynchronously in .lowPriority, no in app delegate.
  // Besides that instead of file / line, it would be better to provide info about Driver / Signal and theier
  // Upstream chain with types.
  package init(code: SendableCombineInternalErrorCode,
               message: String,
               info: SendableErrorInfo = [:]) {
    self.code = code.intValue
    codeString = "\(code)" // TODO: check String is correct
    self.message = message
    self.info = info
  }
}

// MARK: - Internal Error Codes

package enum SendableCombineInternalErrorCode: Sendable {
  case loggingObserverReinjection

  case driverInitialValueDropped

  case upstreamTerminatedWithCompletion
  case upstreamTerminatedWithFailure

  case unexpectedNilObject
  case unexpectedCodeEntrance

  fileprivate var intValue: Int {
    switch self {
    case .loggingObserverReinjection: 0

    case .driverInitialValueDropped: 10

    case .upstreamTerminatedWithCompletion: 31

    case .upstreamTerminatedWithFailure: 32

    case .unexpectedNilObject: 50

    case .unexpectedCodeEntrance: 51
    }
  }
}

// MARK: - Logging

public typealias SendableCombineLoggingObserver =
  @Sendable (_ level: SendableCombineLogLevel, _ entry: SendableCombineLogEntry) -> Void

package enum SendableCombineLogging {
  fileprivate static let _observer = Mutex<SendableCombineLoggingObserver?>(nil)

  public static func injectOnce(loggingObserver: sending @escaping SendableCombineLoggingObserver,
                                file: StaticString = #file,
                                line: UInt = #line) {
    let existingObserver = _observer.withLock { maybeObserver -> SendableCombineLoggingObserver? in
      if let alreadyInjectedObserver = maybeObserver {
        return alreadyInjectedObserver
      } else {
        maybeObserver = loggingObserver
        return nil
      }
    }

    if let existingObserver {
      let message = "Trying to inject a logging observer more than once."
      let entry = SendableCombineLogEntry(code: .loggingObserverReinjection, message: message)
      existingObserver(.warning, entry)
      loggingObserver(.warning, entry)
      assertionFailure(message, file: file, line: line)
    }
  }

  #if DEBUG
    /// Test-only hook to allow a fresh observer to be injected between serialized tests.
    internal static func _resetObserverForTesting() {
      _observer.withLock { maybeObserver in
        maybeObserver = nil
      }
    }
  #endif

  #if DEBUG
    private static let subsystem = "sdk.SendableCombine"
    private static let category = "General"

    fileprivate static let debugLogger = Logger(subsystem: subsystem, category: category)
  #endif
}

// MARK: - Logging

package func _log(_ level: SendableCombineLogLevel, _ entry: SendableCombineLogEntry) {
  #if DEBUG
    let osLogLevel: OSLogType = switch level {
    case .warning: .error
    case .critical: .fault
    }
    SendableCombineLogging.debugLogger.log(level: osLogLevel, "\(entry.message)")
  #endif

  let logger = SendableCombineLogging._observer.withLock { $0 }
  logger?(level, entry)
}
