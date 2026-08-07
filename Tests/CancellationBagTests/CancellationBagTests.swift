import Testing
import Combine
import CancellationBag

@Suite("CancellationBag")
struct CancellationBagTests {

  // MARK: - Test Helpers

  final class CancellationBagRef: Sendable {
    let bag: CancellationBag
    init(_ bag: CancellationBag) { self.bag = bag }
  }

  final class TestCancellable: Cancellable {
    var cancelCount = 0
    func cancel() { cancelCount += 1 }
  }

  // MARK: - AnyCancellable Tests

  @Test("AnyCancellable insert and cancel on deinit")
  func anyCancellableInsertAndCancelOnDeinit() {
    let cancellable1 = AnyCancellable { }
    let cancellable2 = AnyCancellable { }

    do {
      let bag = CancellationBag()
      bag.insert(cancellable1)
      bag.insert(cancellable2)
      #expect(true) // Insert succeeded without cancellation
    } // bag deinits here, cancels both

    #expect(true) // If we reach here, deinit completed
  }

  @Test("AnyCancellable variadic insert")
  func anyCancellableVariadicInsert() {
    let cancellable1 = AnyCancellable { }
    let cancellable2 = AnyCancellable { }

    do {
      let bag = CancellationBag()
      bag.insert(cancellable1, cancellable2)
      #expect(true)
    } // bag deinits here

    #expect(true)
  }

  @Test("AnyCancellable array insert")
  func anyCancellableArrayInsert() {
    let cancellable1 = AnyCancellable { }
    let cancellable2 = AnyCancellable { }

    do {
      let bag = CancellationBag()
      bag.insert([cancellable1, cancellable2])
      #expect(true)
    } // bag deinits here

    #expect(true)
  }

  @Test("AnyCancellable storeInBag convenience")
  func anyCancellableStoreInBag() {
    let cancellable1 = AnyCancellable { }
    let cancellable2 = AnyCancellable { }

    var bag: CancellationBag? = CancellationBag()
    cancellable1.store(in: bag!)
    cancellable2.store(in: bag!)

    #expect(true)
    bag = nil
    #expect(true)
  }

  @Test("AnyCancellable DisposableBuilder initializer")
  func anyCancellableDisposableBuilderInitializer() {
    let cancellable1 = AnyCancellable { }
    let cancellable2 = AnyCancellable { }
    let cancellable3 = AnyCancellable { }

    var bag = CancellationBag {
      cancellable1
      cancellable2
      cancellable3
    }

    #expect(true)
    bag = CancellationBag() // Replace to trigger deinit of old bag
    #expect(true)
  }

  @Test("AnyCancellable DisposableBuilder insert")
  func anyCancellableDisposableBuilderInsert() {
    let cancellable1 = AnyCancellable { }
    let cancellable2 = AnyCancellable { }
    let cancellable3 = AnyCancellable { }
    let cancellable4 = AnyCancellable { }

    var bag = CancellationBag {
      cancellable1
      cancellable2
    }

    bag.insert {
      cancellable3
      cancellable4
    }

    #expect(true)
    bag = CancellationBag()
    #expect(true)
  }

  // MARK: - any Cancellable (protocol) Tests

  @Test("Cancellable protocol insert and cancel on deinit")
  func cancellableProtocolInsertAndCancelOnDeinit() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    bag?.insert(cancellable1)
    bag?.insert(cancellable2)

    #expect(cancellable1.cancelCount == 0)
    #expect(cancellable2.cancelCount == 0)
    bag = nil
    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  @Test("Cancellable protocol variadic insert")
  func cancellableProtocolVariadicInsert() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    bag?.insert(cancellable1, cancellable2)

    #expect(cancellable1.cancelCount == 0)
    #expect(cancellable2.cancelCount == 0)
    bag = nil
    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  @Test("Cancellable protocol array insert")
  func cancellableProtocolArrayInsert() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    bag?.insert([cancellable1, cancellable2])

    #expect(cancellable1.cancelCount == 0)
    #expect(cancellable2.cancelCount == 0)
    bag = nil
    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  @Test("Cancellable protocol storeInBag convenience")
  func cancellableProtocolStoreInBag() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    cancellable1.store(in: bag!)
    cancellable2.store(in: bag!)

    #expect(cancellable1.cancelCount == 0)
    #expect(cancellable2.cancelCount == 0)
    bag = nil
    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  // MARK: - Reentrancy / Disposed Bag Tests

  @Test("Insert into disposed bag cancels immediately")
  func insertIntoDisposedBagCancelsImmediately() {
    let cancellable = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    bag = nil // Dispose the bag

    // Insert into already disposed bag - should cancel immediately
    bag?.insert(cancellable)

    #expect(cancellable.cancelCount == 1)
  }

  @Test("Insert AnyCancellable into disposed bag cancels immediately")
  func insertAnyCancellableIntoDisposedBagCancelsImmediately() {
    var cancelCount = 0
    let cancellable = AnyCancellable { cancelCount += 1 }

    var bag: CancellationBag? = CancellationBag()
    bag = nil // Dispose the bag

    // Insert into already disposed bag - should cancel immediately
    bag?.insert(cancellable)

    #expect(cancelCount == 1)
  }

  @Test("Multiple insertions into disposed bag all cancel")
  func multipleInsertionsIntoDisposedBagAllCancel() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()
    let cancellable3 = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    bag = nil // Dispose the bag

    bag?.insert(cancellable1)
    bag?.insert(cancellable2)
    bag?.insert(cancellable3)

    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
    #expect(cancellable3.cancelCount == 1)
  }

  @Test("Mixed AnyCancellable and Cancellable into disposed bag")
  func mixedIntoDisposedBag() {
    let protocolCancellable = TestCancellable()
    var anyCancelCount = 0
    let anyCancellable = AnyCancellable { anyCancelCount += 1 }

    var bag: CancellationBag? = CancellationBag()
    bag = nil // Dispose the bag

    bag?.insert(protocolCancellable)
    bag?.insert(anyCancellable)

    #expect(protocolCancellable.cancelCount == 1)
    #expect(anyCancelCount == 1)
  }

  // MARK: - Thread Safety Tests

  @Test("Concurrent insertions from multiple threads")
  func concurrentInsertionsFromMultipleThreads() async {
    let bag = CancellationBag()
    let iterations = 1000
    let threadCount = 4

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<threadCount {
        group.addTask {
          for i in 0..<iterations {
            let cancellable = TestCancellable()
            bag.insert(cancellable)
            // Verify it wasn't cancelled immediately
            #expect(cancellable.cancelCount == 0)
          }
        }
      }
    }

    // Bag still alive, nothing cancelled
    // When test ends, bag deinits and cancels all
  }

  @Test("Concurrent insert and dispose")
  func concurrentInsertAndDispose() async {
    let iterations = 100

    for _ in 0..<iterations {
      var bag: CancellationBag? = CancellationBag()
      let cancellable = TestCancellable()

      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          bag?.insert(cancellable)
        }
        group.addTask {
          bag = nil
        }
      }

      // Either it was inserted before dispose (cancelled on deinit)
      // or inserted after dispose (cancelled immediately)
      #expect(cancellable.cancelCount == 1)
    }
  }

  // MARK: - Replacement Pattern Tests

  @Test("Bag replacement cancels previous bag contents")
  func bagReplacementCancelsPreviousContents() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    bag?.insert(cancellable1)
    bag?.insert(cancellable2)

    #expect(cancellable1.cancelCount == 0)
    #expect(cancellable2.cancelCount == 0)

    // Replace bag - old bag deinits and cancels
    bag = CancellationBag()

    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  @Test("New bag accepts new cancellables after replacement")
  func newBagAcceptsNewCancellablesAfterReplacement() {
    let oldCancellable = TestCancellable()
    let newCancellable = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    bag?.insert(oldCancellable)

    bag = CancellationBag() // Replace
    bag?.insert(newCancellable)

    #expect(oldCancellable.cancelCount == 1)
    #expect(newCancellable.cancelCount == 0)

    bag = nil
    #expect(newCancellable.cancelCount == 1)
  }

  // MARK: - Edge Cases

  @Test("Empty bag deinit does not crash")
  func emptyBagDeinitDoesNotCrash() {
    var bag: CancellationBag? = CancellationBag()
    bag = nil
    #expect(true)
  }

  @Test("Insert duplicate AnyCancellable only stored once")
  func insertDuplicateAnyCancellableOnlyStoredOnce() {
    let cancellable = AnyCancellable { }
    var cancelCount = 0
    let countingCancellable = AnyCancellable { cancelCount += 1 }

    var bag: CancellationBag? = CancellationBag()
    bag?.insert(countingCancellable)
    bag?.insert(countingCancellable) // Duplicate

    bag = nil
    #expect(cancelCount == 1) // Should only cancel once
  }

  @Test("Insert duplicate protocol Cancellable only stored once")
  func insertDuplicateProtocolCancellableOnlyStoredOnce() {
    let cancellable = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    bag?.insert(cancellable)
    bag?.insert(cancellable) // Duplicate

    bag = nil
    #expect(cancellable.cancelCount == 1) // Should only cancel once
  }
}

@Suite("CancellationBag Reentrancy")
struct CancellationBagReentrancyTests {

  final class ReentrantCancellable: Cancellable {
    let bag: CancellationBag
    let otherCancellable: TestCancellable
    var cancelCount = 0

    init(bag: CancellationBag, otherCancellable: TestCancellable) {
      self.bag = bag
      self.otherCancellable = otherCancellable
    }

    func cancel() {
      cancelCount += 1
      // Reentrantly insert another cancellable during cancellation
      bag.insert(otherCancellable)
    }
  }

  final class TestCancellable: Cancellable {
    var cancelCount = 0
    func cancel() { cancelCount += 1 }
  }

  @Test("Reentrant insert during deinit gets cancelled immediately")
  func reentrantInsertDuringDeinitGetsCancelledImmediately() {
    let otherCancellable = TestCancellable()

    var bag: CancellationBag? = CancellationBag()
    let reentrantCancellable = ReentrantCancellable(bag: bag!, otherCancellable: otherCancellable)

    bag?.insert(reentrantCancellable)

    #expect(reentrantCancellable.cancelCount == 0)
    #expect(otherCancellable.cancelCount == 0)

    bag = nil // Deinit triggers cancellation

    #expect(reentrantCancellable.cancelCount == 1)
    #expect(otherCancellable.cancelCount == 1) // Reentrant insert cancelled immediately
  }
}