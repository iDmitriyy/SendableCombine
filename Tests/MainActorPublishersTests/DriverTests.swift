import Testing
@testable import MainActorPublishers
import Combine
import Foundation
import os
import SendablePublishers

// MARK: - Test Timeout Helper

func withTimeout<T: Sendable>(
  _ duration: Duration,
  operation: @Sendable @escaping () async throws -> T
) async throws -> T {
  try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask {
      try await operation()
    }
    group.addTask {
      try await Task.sleep(for: duration, tolerance: .milliseconds(200), clock: ContinuousClock())
      throw TestTimeoutError()
    }
    guard let result = try await group.next() else {
      throw TestTimeoutError()
    }
    group.cancelAll()
    return result
  }
}

private struct TestTimeoutError: Error, CustomStringConvertible {
  var description: String { "Test timed out" }
}

// MARK: - Async Helpers

private final class ResumptionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isResumed = false

  func resume<T: Sendable>(returning output: T, continuation: CheckedContinuation<T, any Error>) {
        lock.lock(); defer { lock.unlock() }
        guard !isResumed else { return }
        isResumed = true
        continuation.resume(returning: output)
    }

  func resume<T: Sendable>(throwing error: any Error, continuation: CheckedContinuation<T, any Error>) {
        lock.lock(); defer { lock.unlock() }
        guard !isResumed else { return }
        isResumed = true
        continuation.resume(throwing: error)
    }
}

public final class OSUnfairLock<State>: @unchecked Sendable {
  private let lock: OSAllocatedUnfairLock<State>

  public init(uncheckedState initialState: State) {
    lock = OSAllocatedUnfairLock(uncheckedState: initialState)
  }

  public final func withLockUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R {
    try lock.withLockUnchecked(body)
  }

  public final func withLock<R: Sendable>(_ body: @Sendable (inout State) throws -> R) rethrows -> R {
    try lock.withLock(body)
  }
}

@available(anyAppleOS 26.0, *)
func collectValues<P: Publisher & Sendable, T: Sendable>(
  publisher: P,
  expectedCount: Int,
  timeout: Duration,
) -> Task<[T], any Error> where P.Output == T, P.Failure == Never {
  // 1. Возвращаем Task, который начинает выполняться НЕМЕДЛЕННО
  Task.immediate {
    let gate = ResumptionGate()
    
    typealias TestState = (received: [T], cancellable: AnyCancellable?)
    let testState = OSUnfairLock<TestState>(uncheckedState: ([], nil))

    // Гарантируем, что подписка живет, пока Task не завершится
    defer {
//      _ = consume cancellable
    }

    return try await withCheckedThrowingContinuation { continuation in
//      print("____ withCheckedThrowingContinuation", Date())
      _debugPrintDate(prefix: "____ withCheckedThrowingContinuation")
      _debugPrintDate(prefix: "____ will make publisher.sink")
      let cancellableInstance = publisher.sink { [weak testState] value in
//            print("____ sink", Date())
        _debugPrintDate(prefix: "____ sink emited " + String(describing: value))
        #expect(Thread.isMainThread)
        MainActor.assumeIsolated { }
        guard let testState else {
          Issue.record("Unexpected nil testState")
          return
        }
        let currentResult = testState.withLock { state in
          state.received.append(value)
          let currentResult = state.received
          return currentResult
        }

        if currentResult.count >= expectedCount {
          gate.resume(returning: currentResult, continuation: continuation)
        }
      }
      
      testState.withLockUnchecked { state in
        state.cancellable = cancellableInstance
      }
      _debugPrintDate(prefix: "____ cancellable retained")
      
      Task {
        _debugPrintDate(prefix: "____ timeout Task started")
        do {
          try await Task.sleep(for: timeout, tolerance: .milliseconds(200), clock: ContinuousClock())
//            print("____ TimeOut", Date())
          _debugPrintDate(prefix: "____ TimeOut")
          gate.resume(throwing: TestTimeoutError(), continuation: continuation)
        } catch {
          gate.resume(throwing: error, continuation: continuation)
        }
      }
    }
  }
}

func _debugPrintDate(prefix: String = "") {
//  print(prefix, _debugPrintDateFormatter.string(from: Date.now))
  let timestamp = Date.now.formatted(
    .verbatim("\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(3))",
                  timeZone: .current,
                  calendar: .current)
  )
  print(prefix, timestamp)
}

// MARK: - Driver Tests

@Suite("Driver Tests")
struct DriverTests {
  // MARK: - Sharing Behavior

  @Suite("testDriverSharing_WhenErroring")
  struct SharingWhenErroring {
    @Test("shares single subscription across multiple observers and resubscribes after error")
    func sharesSingleSubscriptionAndResubscribes() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }
      
      var subscriptionCount = 0
      let subject = PassthroughSubject<Int, Never>()
      let infallible = subject.handleEvents(receiveSubscription: { _ in subscriptionCount += 1 })
      let driver = infallible.asDriver(initialValue: 0)

      let task1 = collectValues(publisher: driver, expectedCount: 3, timeout: .milliseconds(10))
      let task2 = collectValues(publisher: driver, expectedCount: 3, timeout: .milliseconds(10))
      
      subject.send(1)
      subject.send(2)

      let results1 = try await task1.value
      let results2 = try await task2.value
      
      _debugPrintDate(prefix: "____ awaited results")
      #expect(results1 == [0, 1, 2])
      #expect(results2 == [0, 1, 2])
      #expect(subscriptionCount == 1)
    }
  }

  // MARK: - Conversion Tests

  @Suite("testErasedAsDriver_CurrentValueSubject")
  struct ErasedCurrentValueSubjectAsDriver {
    @Test("CurrentValueSubject erased to any Publisher<Int, Never> converts to Driver")
    func convertsErasedCurrentValueSubject() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = CurrentValueSubject<Int, Never>(0)
      let erased: any Publisher<Int, Never> = subject.eraseToAnyPublisher()
      let driver = erased.asDriver(initialValue: 1)

      let task = collectValues(publisher: driver, expectedCount: 3, timeout: .milliseconds(10))

      subject.send(2)
      subject.send(3)

      let results = try await task.value
      _debugPrintDate(prefix: "____ awaited results")
      #expect(results == [0, 2, 3])
    }
  }

  // MARK: - MainActor Drive

  @Suite("testDrive_MainActor")
  struct DriveMainActor {
    @Test("drive(receiveValue:) delivers all values on the main thread without crashing in assumeIsolated")
    func driveDeliversOnMainThread() async throws {
      guard #available(anyAppleOS 26.0, *) else { return }

      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let task = collectValues(publisher: driver, expectedCount: 2, timeout: .milliseconds(500))

      subject.send(1)

      let values = try await task.value

      #expect(values == [0, 1])
    }
  }

//  @Suite("testDriverSharing_WhenCompleted")
//  struct SharingWhenCompleted {
//    @Test("shares single subscription across multiple observers and completes")
//    func sharesSingleSubscriptionAndCompletes() async {
//      let subject = PassthroughSubject<Int, Never>()
//
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//
//      let values1 = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//      subject.send(2)
//
//      #expect(values1 == [0, 1, 2])
//    }
//  }
//
//  // MARK: - Conversion Tests
//
//  @Suite("testAsDriver_onErrorJustReturn")
//  struct AsDriverOnErrorJustReturn {
//    @Test("replaces error with default value")
//    func replacesErrorWithDefault() async {
//      let subject = PassthroughSubject<Int, TestError>()
//
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//      subject.send(completion: .failure(.dummyError))
//
//      #expect(values == [0, 1])
//    }
//  }
//
//  @Suite("testAsDriver_onErrorDriveWith")
//  struct AsDriverOnErrorDriveWith {
//    @Test("replaces error with fallback driver values")
//    func replacesErrorWithFallback() async {
//      let subject = PassthroughSubject<Int, TestError>()
//      let fallback = Driver<Int>(failableUpstream: Just(-1), initialValue: -2)
//
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//      subject.send(completion: .failure(.dummyError))
//
//      _ = fallback
//
//      #expect(values == [0, 1])
//    }
//  }
//
//  @Suite("testAsDriver_onErrorRecover")
//  struct AsDriverOnErrorRecover {
//    @Test("recovers from error with closure")
//    func recoversFromError() async {
//      let subject = PassthroughSubject<Int, TestError>()
//
//      let driver = Driver(failableUpstream: subject, initialValue: 0, catchError: { -1 })
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 3 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//      subject.send(completion: .failure(.dummyError))
//
//      #expect(values == [0, 1, -1])
//    }
//  }
//
//  // MARK: - Synchronous Subscription Order
//
//  @Suite("testDrivingOrderOfSynchronousSubscriptions")
//  struct DrivingOrderOfSynchronousSubscriptions {
//    @Test("emits events in correct insertion order for multiple drivers")
//    func correctOrderForMultipleDrivers() async {
//      let subject = PassthroughSubject<Int, Never>()
//
//      let driver1 = Driver(failableUpstream: subject, initialValue: 0)
//      let driver2 = Driver(failableUpstream: subject, initialValue: 0)
//
//      let results = await withTaskGroup(of: [Int].self) { group in
//        group.addTask {
//          await withCheckedContinuation { continuation in
//            var received = [Int]()
//            var cancellable: AnyCancellable?
//            cancellable = driver1.sink { value in
//              received.append(value)
//              if received.count >= 2 { continuation.resume(returning: received) }
//            }
//            _ = cancellable
//          }
//        }
//
//        group.addTask {
//          await withCheckedContinuation { continuation in
//            var received = [Int]()
//            var cancellable: AnyCancellable?
//            cancellable = driver2.sink { value in
//              received.append(value)
//              if received.count >= 2 { continuation.resume(returning: received) }
//            }
//            _ = cancellable
//          }
//        }
//
//        subject.send(1)
//        subject.send(2)
//
//        var all = [[Int]]()
//        for await result in group { all.append(result) }
//        return all
//      }
//
//      let values1 = results[0]
//      let values2 = results[1]
//
//      #expect(values1 == [0, 1, 2])
//      #expect(values2 == [0, 1, 2])
//    }
//
//    @Test("correct ordering through flatMap chain")
//    func correctOrderingThroughFlatMap() async {
//      let subject = PassthroughSubject<Int, Never>()
//
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver
//          .flatMap { Just($0 * 10) }
//          .sink { value in
//            received.append(value)
//            if received.count >= 3 { continuation.resume(returning: received) }
//          }
//        _ = cancellable
//      }
//
//      subject.send(1)
//      subject.send(2)
//
//      #expect(values == [0, 10, 20])
//    }
//  }
//
//  // MARK: - Drive to Observer
//
//  @Suite("testDriveObserver")
//  struct DriveObserver {
//    @Test("drives a single observer")
//    func drivesSingleObserver() async {
//      let subject = PassthroughSubject<Int, Never>()
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//
//      #expect(values == [0, 1])
//    }
//
//    @Test("drives two observers simultaneously")
//    func drivesTwoObservers() async {
//      let subject = PassthroughSubject<Int, Never>()
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//
//      await withTaskGroup(of: [Int].self) { group in
//        group.addTask {
//          await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//            var received = [Int]()
//            var cancellable: AnyCancellable?
//            cancellable = driver.sink { value in
//              received.append(value)
//              if received.count >= 2 { continuation.resume(returning: received) }
//            }
//            _ = cancellable
//          }
//        }
//
//        group.addTask {
//          await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//            var received = [Int]()
//            var cancellable: AnyCancellable?
//            cancellable = driver.sink { value in
//              received.append(value)
//              if received.count >= 2 { continuation.resume(returning: received) }
//            }
//            _ = cancellable
//          }
//        }
//      }
//
//      subject.send(1)
//    }
//  }
//
//  // MARK: - Type Safety
//
//  @Suite("testDriveOptionalObserver")
//  struct DriveOptionalObserver {
//    @Test("drives non-optional Driver to optional observer")
//    func drivesNonOptionalToOptional() async {
//      let subject = PassthroughSubject<Int, Never>()
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int?], Never>) in
//        var received = [Int?]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { (value: Int) in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//
//      #expect(values == [0, 1])
//    }
//  }
//
//  // MARK: - asDriver Conversion
//
//  @Suite("testBehaviorRelayAsDriver")
//  struct BehaviorRelayAsDriver {
//    @Test("converts CurrentValueSubject to Driver")
//    func convertsCurrentValueSubject() async {
//      let subject = CurrentValueSubject<Int, Never>(0)
//      let driver = subject.asDriver(initialValue: 0)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//
//      #expect(values == [0, 1])
//    }
//  }
//
//  @Suite("testInfallibleAsDriver")
//  struct InfallibleAsDriver {
//    @Test("converts infallible publisher to Driver")
//    func convertsInfallible() async {
//      let subject = PassthroughSubject<Int, Never>()
//      let driver = subject.asDriver(initialValue: 0)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//
//      #expect(values == [0, 1])
//    }
//  }
//
//  // MARK: - Error Handling
//
//  @Suite("testDriveWithError")
//  struct DriveWithError {
//    @Test("ignores error and completes silently")
//    func ignoresError() async {
//      let subject = PassthroughSubject<Int, TestError>()
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//      subject.send(completion: .failure(.dummyError))
//
//      #expect(values == [0, 1])
//    }
//  }
//
//  // MARK: - Driver as Publisher
//
//  @Suite("testDriverAsPublisher")
//  struct DriverAsPublisher {
//    @Test("converts Driver to AnyPublisher and receives values")
//    func convertsToPublisher() async {
//      let subject = PassthroughSubject<Int, Never>()
//      let driver = Driver(failableUpstream: subject, initialValue: 0)
//      let publisher = driver.asPublisher()
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = publisher.sink { value in
//          received.append(value)
//          if received.count >= 2 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//
//      #expect(values == [0, 1])
//    }
//  }
//
//  // MARK: - Initial Value Prepend
//
//  @Suite("testDriverInitialValue")
//  struct DriverInitialValue {
//    @Test("prepends initialValue before upstream values")
//    func prependsInitialValue() async {
//      let subject = PassthroughSubject<Int, Never>()
//      let driver = Driver(failableUpstream: subject, initialValue: 42)
//
//      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
//        var received = [Int]()
//        var cancellable: AnyCancellable?
//        cancellable = driver.sink { value in
//          received.append(value)
//          if received.count >= 3 {
//            continuation.resume(returning: received)
//          }
//        }
//        _ = cancellable
//      }
//
//      subject.send(1)
//      subject.send(2)
//
//      #expect(values == [42, 1, 2])
//    }
//  }
}

// MARK: - Test Helpers

private enum TestError: Error, Hashable {
  case dummyError
  case dummyError1
  case dummyError2
}
