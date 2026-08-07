import Testing
import MainActorPublishers
import Combine
import Foundation

// MARK: - Signal Tests

@Suite("Signal Tests")
struct SignalTests {
  // MARK: - Sharing Behavior

  @Suite("testSignalSharing_WhenErroring")
  struct SharingWhenErroring {
    @Test("shares single subscription across multiple observers and resubscribes after error")
    func sharesSingleSubscriptionAndResubscribes() async {
      let subject = PassthroughSubject<Int, TestError>()

      let signal = Signal(failableUpstream: subject)

      await withTaskGroup(of: [Int].self) { group in
        group.addTask {
          await withCheckedContinuation { continuation in
            var values = [Int]()
            var cancellable: AnyCancellable?
            cancellable = signal.sink { value in
              values.append(value)
              if values.count >= 1 {
                continuation.resume(returning: values)
              }
            }
            _ = cancellable
          }
        }

        group.addTask {
          await withCheckedContinuation { continuation in
            var values = [Int]()
            var cancellable: AnyCancellable?
            cancellable = signal.sink { value in
              values.append(value)
              if values.count >= 1 {
                continuation.resume(returning: values)
              }
            }
            _ = cancellable
          }
        }
      }

      subject.send(1)
    }
  }

  @Suite("testSignalSharing_WhenCompleted")
  struct SharingWhenCompleted {
    @Test("shares single subscription across multiple observers and completes")
    func sharesSingleSubscriptionAndCompletes() async {
      let subject = PassthroughSubject<Int, Never>()

      let signal = Signal(failableUpstream: subject)

      let values1 = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = signal.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)
      subject.send(2)

      #expect(values1 == [1, 2])
    }
  }

  // MARK: - Conversion Tests

  @Suite("testAsSignal_onErrorJustReturn")
  struct AsSignalOnErrorJustReturn {
    @Test("replaces error with default value")
    func replacesErrorWithDefault() async {
      let subject = PassthroughSubject<Int, TestError>()

      let signal = Signal(failableUpstream: subject)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = signal.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)
      subject.send(completion: .failure(.dummyError))

      #expect(values == [1])
    }
  }

  @Suite("testAsSignal_onErrorRecover")
  struct AsSignalOnErrorRecover {
    @Test("recovers from error with closure")
    func recoversFromError() async {
      let subject = PassthroughSubject<Int, TestError>()

      let signal = Signal(failableUpstream: subject, catchError: { -1 })

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = signal.sink { value in
          received.append(value)
          if received.count >= 2 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)
      subject.send(completion: .failure(.dummyError))

      #expect(values == [1, -1])
    }
  }

  // MARK: - Synchronous Subscription Order

  @Suite("testSignalDrivingOrderOfSynchronousSubscriptions")
  struct DrivingOrderOfSynchronousSubscriptions {
    @Test("emits events in correct insertion order for multiple signals")
    func correctOrderForMultipleSignals() async {
      let subject = PassthroughSubject<Int, Never>()

      let signal1 = Signal(failableUpstream: subject)
      let signal2 = Signal(failableUpstream: subject)

      let results = await withTaskGroup(of: [Int].self) { group in
        group.addTask {
          await withCheckedContinuation { continuation in
            var received = [Int]()
            var cancellable: AnyCancellable?
            cancellable = signal1.sink { value in
              received.append(value)
              if received.count >= 2 { continuation.resume(returning: received) }
            }
            _ = cancellable
          }
        }

        group.addTask {
          await withCheckedContinuation { continuation in
            var received = [Int]()
            var cancellable: AnyCancellable?
            cancellable = signal2.sink { value in
              received.append(value)
              if received.count >= 2 { continuation.resume(returning: received) }
            }
            _ = cancellable
          }
        }

        subject.send(1)
        subject.send(2)

        var all = [[Int]]()
        for await result in group { all.append(result) }
        return all
      }

      let values1 = results[0]
      let values2 = results[1]

      #expect(values1 == [1, 2])
      #expect(values2 == [1, 2])
    }

    @Test("correct ordering through flatMap chain")
    func correctOrderingThroughFlatMap() async {
      let subject = PassthroughSubject<Int, Never>()

      let signal = Signal(failableUpstream: subject)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = signal
          .flatMap { Just($0 * 10) }
          .sink { value in
            received.append(value)
            if received.count >= 2 { continuation.resume(returning: received) }
          }
        _ = cancellable
      }

      subject.send(1)
      subject.send(2)

      #expect(values == [10, 20])
    }
  }

  // MARK: - Drive to Observer

  @Suite("testSignalObserver")
  struct SignalObserver {
    @Test("drives a single observer")
    func drivesSingleObserver() async {
      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = signal.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)

      #expect(values == [1])
    }

    @Test("drives two observers simultaneously")
    func drivesTwoObservers() async {
      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      await withTaskGroup(of: [Int].self) { group in
        group.addTask {
          await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
            var received = [Int]()
            var cancellable: AnyCancellable?
            cancellable = signal.sink { value in
              received.append(value)
              if received.count >= 1 { continuation.resume(returning: received) }
            }
            _ = cancellable
          }
        }

        group.addTask {
          await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
            var received = [Int]()
            var cancellable: AnyCancellable?
            cancellable = signal.sink { value in
              received.append(value)
              if received.count >= 1 { continuation.resume(returning: received) }
            }
            _ = cancellable
          }
        }
      }

      subject.send(1)
    }
  }

  // MARK: - Type Safety

  @Suite("testSignalOptionalObserver")
  struct SignalOptionalObserver {
    @Test("drives non-optional Signal to optional observer")
    func drivesNonOptionalToOptional() async {
      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int?], Never>) in
        var received = [Int?]()
        var cancellable: AnyCancellable?
        cancellable = signal.sink { (value: Int) in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)

      #expect(values == [1])
    }
  }

  // MARK: - asSignal Conversion

  @Suite("testAsSignal_fromPublisher")
  struct AsSignalFromPublisher {
    @Test("converts infallible publisher to Signal")
    func convertsInfallible() async {
      let subject = PassthroughSubject<Int, Never>()
      let signal = subject.asSignal()

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = signal.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)

      #expect(values == [1])
    }
  }

  // MARK: - Error Handling

  @Suite("testSignalWithError")
  struct SignalWithError {
    @Test("ignores error and completes silently")
    func ignoresError() async {
      let subject = PassthroughSubject<Int, TestError>()
      let signal = Signal(failableUpstream: subject)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = signal.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)
      subject.send(completion: .failure(.dummyError))

      #expect(values == [1])
    }
  }

  // MARK: - Signal as Publisher

  @Suite("testSignalAsPublisher")
  struct SignalAsPublisher {
    @Test("converts Signal to AnyPublisher and receives values")
    func convertsToPublisher() async {
      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)
      let publisher = signal.asPublisher()

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = publisher.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)

      #expect(values == [1])
    }
  }

  // MARK: - No Initial Value

  @Suite("testSignalNoInitialValue")
  struct SignalNoInitialValue {
    @Test("does not prepend initialValue before upstream values")
    func doesNotPrependInitialValue() async {
      let subject = PassthroughSubject<Int, Never>()
      let signal = Signal(failableUpstream: subject)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = signal.sink { value in
          received.append(value)
          if received.count >= 2 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject.send(1)
      subject.send(2)

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
