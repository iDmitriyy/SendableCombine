import Testing
import MainActorPublishers
import Combine
import Foundation
import SendableCombineLogging

// MARK: - Signal Tests

@Suite("Signal Tests")
struct SignalTests {
  // MARK: - Sharing Behavior

  @Suite("testSignalSharing_WhenErroring")
  struct SharingWhenErroring {
    @Test("shares single subscription across multiple observers and resubscribes after error")
    func sharesSingleSubscriptionAndResubscribes() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, TestError>()
      let signal = Signal(failableUpstream: subject)

      let task1 = collectValues(publisher: signal, expectedCount: 2, timeout: .milliseconds(100))
      let task2 = collectValues(publisher: signal, expectedCount: 2, timeout: .milliseconds(100))

      subject.send(1)

      let values1 = try await task1.value
      let values2 = try await task2.value

      #expect(values1 == [1])
      #expect(values2 == [1])
    }
  }

  @Suite("testSignalSharing_WhenCompleted")
  struct SharingWhenCompleted {
    @Test("shares single subscription across multiple observers and completes")
    func sharesSingleSubscriptionAndCompletes() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let task = collectValues(publisher: signal, expectedCount: 2, timeout: .milliseconds(100))

      subject.send(1)
      subject.send(2)

      let values = try await task.value
      #expect(values == [1, 2])
    }
  }

  // MARK: - Conversion Tests

  @Suite("testAsSignal_onErrorJustReturn")
  struct AsSignalOnErrorJustReturn {
    @Test("replaces error with default value")
    func replacesErrorWithDefault() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, TestError>()
      let signal = Signal(failableUpstream: subject)

      let task = collectValues(publisher: signal, expectedCount: 1, timeout: .milliseconds(100))

      subject.send(1)
      subject.send(completion: .failure(.dummyError))

      let values = try await task.value
      #expect(values == [1])
    }
  }

  @Suite("testAsSignal_onErrorRecover")
  struct AsSignalOnErrorRecover {
    @Test("recovers from error with closure")
    func recoversFromError() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, TestError>()
      let signal = Signal(failableUpstream: subject, catchError: { -1 })

      let task = collectValues(publisher: signal, expectedCount: 2, timeout: .milliseconds(100))

      subject.send(1)
      subject.send(completion: .failure(.dummyError))

      let values = try await task.value
      #expect(values == [1, -1])
    }
  }

  // MARK: - Synchronous Subscription Order

  @Suite("testSignalDrivingOrderOfSynchronousSubscriptions")
  struct DrivingOrderOfSynchronousSubscriptions {
    @Test("emits events in correct insertion order for multiple signals")
    func correctOrderForMultipleSignals() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let signal1 = Signal(failableUpstream: subject)
      let signal2 = Signal(failableUpstream: subject)

      let task1 = collectValues(publisher: signal1, expectedCount: 2, timeout: .milliseconds(100))
      let task2 = collectValues(publisher: signal2, expectedCount: 2, timeout: .milliseconds(100))

      subject.send(1)
      subject.send(2)

      let values1 = try await task1.value
      let values2 = try await task2.value

      #expect(values1 == [1, 2])
      #expect(values2 == [1, 2])
    }

  }

  // MARK: - Drive to Observer

  @Suite("testSignalObserver")
  struct SignalObserver {
    @Test("drives a single observer")
    func drivesSingleObserver() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let task = collectValues(publisher: signal, expectedCount: 1, timeout: .milliseconds(100))

      subject.send(1)

      let values = try await task.value
      #expect(values == [1])
    }

    @Test("drives two observers simultaneously")
    func drivesTwoObservers() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let task1 = collectValues(publisher: signal, expectedCount: 1, timeout: .milliseconds(100))
      let task2 = collectValues(publisher: signal, expectedCount: 1, timeout: .milliseconds(100))

      subject.send(1)

      let values1 = try await task1.value
      let values2 = try await task2.value

      #expect(values1 == [1])
      #expect(values2 == [1])
    }
  }

  // MARK: - Type Safety

  @Suite("testSignalOptionalObserver")
  struct SignalOptionalObserver {
    @Test("drives non-optional Signal to optional observer")
    func drivesNonOptionalToOptional() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let task = collectValues(publisher: signal, expectedCount: 1, timeout: .milliseconds(100)) as Task<[Int], any Error>

      subject.send(1)

      let values = try await task.value
      #expect(values == [1])
    }
  }

  // MARK: - asSignal Conversion

  @Suite("testAsSignal_fromPublisher")
  struct AsSignalFromPublisher {
    @Test("converts infallible publisher to Signal")
    func convertsInfallible() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let signal = subject.asSignal()

      let task = collectValues(publisher: signal, expectedCount: 1, timeout: .milliseconds(100))

      subject.send(1)

      let values = try await task.value
      #expect(values == [1])
    }
  }

  // MARK: - Error Handling

  @Suite("testSignalWithError")
  struct SignalWithError {
    @Test("ignores error and completes silently")
    func ignoresError() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, TestError>()
      let signal = Signal(failableUpstream: subject)

      let task = collectValues(publisher: signal, expectedCount: 1, timeout: .milliseconds(100))

      subject.send(1)
      subject.send(completion: .failure(.dummyError))

      let values = try await task.value
      #expect(values == [1])
    }
  }

  // MARK: - Signal as Publisher

  @Suite("testSignalAsPublisher")
  struct SignalAsPublisher {
    @Test("converts Signal to AnyPublisher and receives values")
    func convertsToPublisher() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let task = collectValues(publisher: signal, expectedCount: 1, timeout: .milliseconds(100))

      subject.send(1)

      let values = try await task.value
      #expect(values == [1])
    }
  }

  // MARK: - No Initial Value

  @Suite("testSignalNoInitialValue")
  struct SignalNoInitialValue {
    @Test("does not prepend initialValue before upstream values")
    func doesNotPrependInitialValue() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let task = collectValues(publisher: signal, expectedCount: 2, timeout: .milliseconds(100))

      subject.send(1)
      subject.send(2)

      let values = try await task.value
      #expect(values == [1, 2])
    }
  }
}

// MARK: - Test Helpers

private enum TestError: Error, Hashable {
  case dummyError
  case dummyError1
  case dummyError2
}
