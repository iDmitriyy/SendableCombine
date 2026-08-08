import Testing
@testable import MainActorPublishers
@testable import SendableCombineLogging
import Combine
import Foundation

// MARK: - Test Error

private struct FailableError: Error {}

// MARK: - Log Capture

private final class LogRecordCollector: @unchecked Sendable {
  private let lock = NSLock()
  private var records: [SendableCombineLogEntry] = []

  func append(_ payload: (level: SendableCombineLogLevel, entry: SendableCombineLogEntry)) {
    lock.lock(); defer { lock.unlock() }
    records.append(payload.entry)
  }

  func entries() -> [SendableCombineLogEntry] {
    lock.lock(); defer { lock.unlock() }
    return records
  }
}

// MARK: - Failable asDriver Tests

@Suite("Failable asDriver Methods", .serialized)
struct FailableDriverMethodsTests {
  @Test("asDriver with catchError recovers with a fallback value and logs a failure warning")
  func asDriverWithCatchErrorRecoversAndLogs() async throws {
    guard #available(anyAppleOS 26.0, *) else { return }

    SendableCombineLogging._resetObserverForTesting()
    let collector = LogRecordCollector()
    SendableCombineLogging.injectOnce { payload in
      collector.append(payload)
    }

    let subject = PassthroughSubject<Int, FailableError>()
    let driver = subject.asDriver(initialValue: 0, catchError: { _ in -1 })

    let task = collectValues(publisher: driver, expectedCount: 3, timeout: .milliseconds(10))

    subject.send(1)
    subject.send(completion: .failure(FailableError()))

    let results = try await task.value

    #expect(results == [0, 1, -1])

    let codes = collector.entries().map(\.code)
    #expect(codes.contains(SendableCombineInternalErrorCode.driverUpstreamTerminatedWithFailure.rawValue))
  }

  @Test("asDriverIgnoringError drops the error and logs a failure warning")
  func ignoringErrorDropsFailureAndLogs() async throws {
    guard #available(anyAppleOS 26.0, *) else { return }

    SendableCombineLogging._resetObserverForTesting()
    let collector = LogRecordCollector()
    SendableCombineLogging.injectOnce { payloadSample in
      collector.append(payloadSample)
    }

    let subject = PassthroughSubject<Int, FailableError>()
    let driver = subject.asDriverIgnoringError(initialValue: 0)

    let task = collectValues(publisher: driver, expectedCount: 2, timeout: .milliseconds(10))

    subject.send(1)
    subject.send(completion: .failure(FailableError()))

    let results = try await task.value

    #expect(results == [0, 1])

    let codes = collector.entries().map(\.code)
    #expect(codes.contains(SendableCombineInternalErrorCode.driverUpstreamTerminatedWithFailure.rawValue))
  }
}