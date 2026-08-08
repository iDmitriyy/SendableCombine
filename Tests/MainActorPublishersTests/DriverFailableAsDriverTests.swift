import Testing
@testable import MainActorPublishers
@testable import SendableCombineLogging
import Combine
import Foundation
import Synchronization

// MARK: - Test Error

private struct FailableError: Error {}

// MARK: - Log Capture

private final class LogRecordCollector: Sendable {
  private let lock = Mutex<[SendableCombineLogEntry]>([])

  func append(_ payload: (level: SendableCombineLogLevel, entry: SendableCombineLogEntry)) {
    lock.withLock { records in
      records.append(payload.entry)
    }
  }

  func entries() -> [SendableCombineLogEntry] {
    lock.withLock { records in
      records
    }
  }

  func makeClosureObserver() -> SendableCombineLoggingObserver {
    { [self] payload in self.append(payload) }
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
    SendableCombineLogging.injectOnce(loggingObserver: collector.makeClosureObserver())

    let subject = PassthroughSubject<Int, FailableError>()
    let driver = subject.asDriver(initialValue: 0, catchError: { _ in -1 })

    let task = collectValues(publisher: driver, expectedCount: 3, timeout: .milliseconds(10))

    subject.send(1)
    subject.send(completion: .failure(FailableError()))

    let results = try await task.value

    #expect(results == [0, 1, -1])

    let codes = collector.entries().map(\.code)
    #expect(codes.contains(SendableCombineInternalErrorCode.upstreamTerminatedWithFailure.rawValue))
  }

  @Test("asDriverIgnoringError drops the error and logs a failure warning")
  func ignoringErrorDropsFailureAndLogs() async throws {
    guard #available(anyAppleOS 26.0, *) else { return }

    SendableCombineLogging._resetObserverForTesting()
    let collector = LogRecordCollector()
    SendableCombineLogging.injectOnce(loggingObserver: collector.makeClosureObserver())

    let subject = PassthroughSubject<Int, FailableError>()
    let driver = subject.asDriverIgnoringError(initialValue: 0)

    let task = collectValues(publisher: driver, expectedCount: 2, timeout: .milliseconds(10))

    subject.send(1)
    subject.send(completion: .failure(FailableError()))

    let results = try await task.value

    #expect(results == [0, 1])

    let codes = collector.entries().map(\.code)
    #expect(codes.contains(SendableCombineInternalErrorCode.upstreamTerminatedWithFailure.rawValue))
  }
}
