import Testing
import MainActorPublishers
import Combine
import Foundation

// MARK: - Driver Operator Tests

@Suite("Driver Operator Tests")
struct DriverOperatorTests {
  // MARK: - Map

  @Suite("testAsDriver_map")
  struct AsDriverMap {
    @Test("transforms values with map operator")
    func transformsValues() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
        var received = [String]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .map { "\($0)" }
          .sink { value in
            received.append(value)
            if received.count >= 2 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send(1)

      #expect(values == ["0", "1"])
    }
  }

  // MARK: - CompactMap

  @Suite("testAsDriver_compactMap")
  struct AsDriverCompactMap {
    @Test("filters nil results with compactMap")
    func filtersNilResults() async {
      let subject = PassthroughSubject<String, Never>()
      let driver = subject.asDriver(initialValue: "0")

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .compactMap { Int($0) }
          .sink { value in
            received.append(value)
            if received.count >= 2 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send("1")
      subject.send("abc")

      #expect(values == [0, 1])
    }
  }

  // MARK: - Filter

  @Suite("testAsDriver_filter")
  struct AsDriverFilter {
    @Test("retains only even numbers")
    func retainsOnlyEvenNumbers() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .filter { $0 % 2 == 0 }
          .sink { value in
            received.append(value)
            if received.count >= 3 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send(1)
      subject.send(2)
      subject.send(3)
      subject.send(4)

      #expect(values == [0, 2, 4])
    }
  }

  // MARK: - DistinctUntilChanged

  @Suite("testAsDriver_distinctUntilChanged")
  struct AsDriverDistinctUntilChanged {
    @Test("removes consecutive duplicate values")
    func removesConsecutiveDuplicates() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .removeDuplicates()
          .sink { value in
            received.append(value)
            if received.count >= 3 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send(1)
      subject.send(1)
      subject.send(2)
      subject.send(2)
      subject.send(3)

      #expect(values == [0, 1, 2, 3])
    }

    @Test("removes duplicates with key selector")
    func removesDuplicatesWithKeySelector() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .removeDuplicates { abs($0) == abs($1) }
          .sink { value in
            received.append(value)
            if received.count >= 3 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send(1)
      subject.send(-1)
      subject.send(2)
      subject.send(-2)
      subject.send(3)

      #expect(values == [0, 1, 2, 3])
    }
  }

  // MARK: - Scan

  @Suite("testAsDriver_scan")
  struct AsDriverScan {
    @Test("accumulates values with scan operator")
    func accumulatesValues() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 1)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .scan(0, +)
          .sink { value in
            received.append(value)
            if received.count >= 3 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send(1)
      subject.send(2)
      subject.send(3)

      #expect(values == [1, 2, 4, 7])
    }
  }

  // MARK: - Debounce

  @Suite("testAsDriver_debounce")
  struct AsDriverDebounce {
    @Test("debounces rapid values")
    func debouncesRapidValues() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
          .sink { value in
            received.append(value)
            if received.count >= 1 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send(1)
      subject.send(2)
      subject.send(3)

      #expect(values == [3])
    }
  }

  // MARK: - Throttle

  @Suite("testAsDriver_throttle")
  struct AsDriverThrottle {
    @Test("throttles rapid values with latest")
    func throttlesRapidValues() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
          .sink { value in
            received.append(value)
            if received.count >= 1 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send(1)
      subject.send(2)
      subject.send(3)

      #expect(values == [3])
    }
  }

  // MARK: - Skip

  @Suite("testAsDriver_skip")
  struct AsDriverSkip {
    @Test("skips specified number of elements")
    func skipsElements() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .dropFirst(1)
          .sink { value in
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

  // MARK: - StartWith

  @Suite("testAsDriver_startWith")
  struct AsDriverStartWith {
    @Test("prepends specified element")
    func prependsElement() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .prepend(-1)
          .sink { value in
            received.append(value)
            if received.count >= 2 {
              continuation.resume(returning: received)
            }
          }
        _ = cancellable
      }

      subject.send(1)

      #expect(values == [-1, 0, 1])
    }
  }

  // MARK: - Delay

  @Suite("testAsDriver_delay")
  struct AsDriverDelay {
    @Test("delays value delivery")
    func delaysValue() async {
      let subject = PassthroughSubject<Int, Never>()
      let driver = subject.asDriver(initialValue: 0)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = driver
          .delay(for: .milliseconds(100), scheduler: DispatchQueue.main)
          .sink { value in
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

  // MARK: - Merge

  @Suite("testAsDriver_merge")
  struct AsDriverMerge {
    @Test("merges multiple drivers")
    func mergesDrivers() async {
      let subject1 = PassthroughSubject<Int, Never>()
      let subject2 = PassthroughSubject<Int, Never>()

      let driver1 = subject1.asDriver(initialValue: 0)
      let driver2 = subject2.asDriver(initialValue: 10)

      let merged = driver1.merge(with: driver2)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
        var received = [Int]()
        var cancellable: AnyCancellable?
        cancellable = merged.sink { value in
          received.append(value)
          if received.count >= 2 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject1.send(1)
      subject2.send(2)

      #expect(values.contains(1))
      #expect(values.contains(2))
    }
  }

  // MARK: - CombineLatest

  @Suite("testAsDriver_combineLatest")
  struct AsDriverCombineLatest {
    @Test("combines latest values from two drivers")
    func combinesLatestValues() async {
      let subject1 = PassthroughSubject<Int, Never>()
      let subject2 = PassthroughSubject<String, Never>()

      let driver1 = subject1.asDriver(initialValue: 0)
      let driver2 = subject2.asDriver(initialValue: "a")

      let combined = driver1.combineLatest(driver2)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[(Int, String)], Never>) in
        var received = [(Int, String)]()
        var cancellable: AnyCancellable?
        cancellable = combined.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject1.send(1)
      subject2.send("b")

      #expect(values.last?.0 == 1)
      #expect(values.last?.1 == "b")
    }
  }

  // MARK: - Zip

  @Suite("testAsDriver_zip")
  struct AsDriverZip {
    @Test("zips values from two drivers")
    func zipsValues() async {
      let subject1 = PassthroughSubject<Int, Never>()
      let subject2 = PassthroughSubject<String, Never>()

      let driver1 = subject1.asDriver(initialValue: 0)
      let driver2 = subject2.asDriver(initialValue: "a")

      let zipped = driver1.zip(driver2)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[(Int, String)], Never>) in
        var received = [(Int, String)]()
        var cancellable: AnyCancellable?
        cancellable = zipped.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject1.send(1)
      subject2.send("b")

      #expect(values.last?.0 == 1)
      #expect(values.last?.1 == "b")
    }
  }

  // MARK: - withLatestFrom

  @Suite("testAsDriver_withLatestFrom")
  struct AsDriverWithLatestFrom {
    @Test("combines with latest value from another driver")
    func combinesWithLatestValue() async {
      let subject1 = PassthroughSubject<Int, Never>()
      let subject2 = PassthroughSubject<String, Never>()

      let driver1 = subject1.asDriver(initialValue: 0)
      let driver2 = subject2.asDriver(initialValue: "a")

      let combined = driver1.combineLatest(driver2)

      let values = await withCheckedContinuation { (continuation: CheckedContinuation<[(Int, String)], Never>) in
        var received = [(Int, String)]()
        var cancellable: AnyCancellable?
        cancellable = combined.sink { value in
          received.append(value)
          if received.count >= 1 {
            continuation.resume(returning: received)
          }
        }
        _ = cancellable
      }

      subject1.send(1)

      #expect(values.last?.0 == 1)
    }
  }
}
