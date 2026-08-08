import Testing
import Combine
import CancellationBag

// MARK: - Test Helpers

final class CancellationBagRef: Sendable {
  let bag = CancellationBag()
  init() {}
}

final class TestCancellable: Cancellable, @unchecked Sendable {
  nonisolated(unsafe) var cancelCount = 0
  func cancel() { cancelCount += 1 }
}

/// A value-typed `Cancellable`: each copied value shares the same `TestCancellable`
/// reference, so the test can observe how many copies were stored and cancelled.
struct TestStructCancellable: Cancellable {
  let cancellableObject = TestCancellable()
  func cancel() { cancellableObject.cancel() }
}

@Suite("CancellationBag")
struct CancellationBagTests {

  // MARK: - AnyCancellable Tests

  @Test("AnyCancellable insert and cancel on deinit")
  func anyCancellableInsertAndCancelOnDeinit() {
    var isCancelled1 = false
    var isCancelled2 = false
    let cancellable1 = AnyCancellable { isCancelled1 = true }
    let cancellable2 = AnyCancellable { isCancelled2 = true }

    do {
      let bag = CancellationBag()
      bag.insert(cancellable1)
      bag.insert(cancellable2)
      #expect(isCancelled1 == false)
      #expect(isCancelled2 == false)
    } // bag deinits here, cancels both

    #expect(isCancelled1 == true)
    #expect(isCancelled2 == true)
  }

  @Test("AnyCancellable variadic insert")
  func anyCancellableVariadicInsert() {
    var isCancelled1 = false
    var isCancelled2 = false
    let cancellable1 = AnyCancellable { isCancelled1 = true }
    let cancellable2 = AnyCancellable { isCancelled2 = true }

    do {
      let bag = CancellationBag()
      bag.insert(cancellable1, cancellable2)
      #expect(isCancelled1 == false)
      #expect(isCancelled2 == false)
    } // bag deinits here

    #expect(isCancelled1 == true)
    #expect(isCancelled2 == true)
  }

  @Test("AnyCancellable array insert")
  func anyCancellableArrayInsert() {
    var isCancelled1 = false
    var isCancelled2 = false
    let cancellable1 = AnyCancellable { isCancelled1 = true }
    let cancellable2 = AnyCancellable { isCancelled2 = true }

    do {
      let bag = CancellationBag()
      bag.insert([cancellable1, cancellable2])
      #expect(isCancelled1 == false)
      #expect(isCancelled2 == false)
    } // bag deinits here

    #expect(isCancelled1 == true)
    #expect(isCancelled2 == true)
  }

  @Test("AnyCancellable storeInBag convenience")
  func anyCancellableStoreInBag() {
    var isCancelled1 = false
    var isCancelled2 = false
    let cancellable1 = AnyCancellable { isCancelled1 = true }
    let cancellable2 = AnyCancellable { isCancelled2 = true }

    do {
      let bag = CancellationBag()
      cancellable1.store(in: bag)
      cancellable2.store(in: bag)
      #expect(isCancelled1 == false)
      #expect(isCancelled2 == false)
    } // bag deinits here

    #expect(isCancelled1 == true)
    #expect(isCancelled2 == true)
  }

  @Test("AnyCancellable DisposableBuilder insert")
  func anyCancellableDisposableBuilderInsert() {
    var isCancelled1 = false
    var isCancelled2 = false
    var isCancelled3 = false
    var isCancelled4 = false
    let cancellable1 = AnyCancellable { isCancelled1 = true }
    let cancellable2 = AnyCancellable { isCancelled2 = true }
    let cancellable3 = AnyCancellable { isCancelled3 = true }
    let cancellable4 = AnyCancellable { isCancelled4 = true }

    do {
      let bag = CancellationBag()

      bag.insert {
        cancellable1
        cancellable2
      }

      bag.insert {
        cancellable3
        cancellable4
      }

      #expect(isCancelled1 == false)
      #expect(isCancelled2 == false)
      #expect(isCancelled3 == false)
      #expect(isCancelled4 == false)
    } // bag deinits, cancels all

    #expect(isCancelled1 == true)
    #expect(isCancelled2 == true)
    #expect(isCancelled3 == true)
    #expect(isCancelled4 == true)
  }

  // MARK: - any Cancellable (protocol) Tests

  @Test("Cancellable protocol insert and cancel on deinit")
  func cancellableProtocolInsertAndCancelOnDeinit() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    do {
      let bag = CancellationBag()
      bag.insert(cancellable1)
      bag.insert(cancellable2)
      #expect(cancellable1.cancelCount == 0)
      #expect(cancellable2.cancelCount == 0)
    } // bag deinits here

    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  @Test("Cancellable protocol variadic insert")
  func cancellableProtocolVariadicInsert() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    do {
      let bag = CancellationBag()
      bag.insert([cancellable1, cancellable2] as [any Cancellable])
      #expect(cancellable1.cancelCount == 0)
      #expect(cancellable2.cancelCount == 0)
    } // bag deinits here

    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  @Test("Cancellable protocol array insert")
  func cancellableProtocolArrayInsert() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    do {
      let bag = CancellationBag()
      bag.insert([cancellable1, cancellable2])
      #expect(cancellable1.cancelCount == 0)
      #expect(cancellable2.cancelCount == 0)
    } // bag deinits here

    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  @Test("Cancellable protocol storeInBag convenience")
  func cancellableProtocolStoreInBag() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    do {
      let bag = CancellationBag()
      cancellable1.store(in: bag)
      cancellable2.store(in: bag)
      #expect(cancellable1.cancelCount == 0)
      #expect(cancellable2.cancelCount == 0)
    } // bag deinits here

    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  // MARK: - Thread Safety Tests

  @Test("Concurrent insertions from multiple threads")
  func concurrentInsertionsFromMultipleThreads() async {
    let ref = CancellationBagRef()
    let iterations = 1000
    let threadCount = 4

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<threadCount {
        group.addTask {
          for _ in 0..<iterations {
            let cancellable = TestCancellable()
            ref.bag.insert(cancellable)
            #expect(cancellable.cancelCount == 0)
          }
        }
      }
    }
  }

  @Test("Concurrent insert and dispose")
  func concurrentInsertAndDispose() async {
    let iterations = 100

    for _ in 0..<iterations {
      let cancellable = TestCancellable()
      let ref = CancellationBagRef()

      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          ref.bag.insert(cancellable)
        }
      }

      #expect(cancellable.cancelCount == 0)
    }
    // All bags deinited here at end of for-loop iteration
  }

  // MARK: - Replacement Pattern Tests

  @Test("Bag replacement cancels previous bag contents")
  func bagReplacementCancelsPreviousContents() {
    let cancellable1 = TestCancellable()
    let cancellable2 = TestCancellable()

    do {
      let firstBag = CancellationBag()
      firstBag.insert(cancellable1)
      firstBag.insert(cancellable2)
      #expect(cancellable1.cancelCount == 0)
      #expect(cancellable2.cancelCount == 0)
    } // firstBag deinits, cancels both

    #expect(cancellable1.cancelCount == 1)
    #expect(cancellable2.cancelCount == 1)
  }

  @Test("New bag accepts new cancellables after replacement")
  func newBagAcceptsNewCancellablesAfterReplacement() {
    let oldCancellable = TestCancellable()
    let newCancellable = TestCancellable()

    do {
      let firstBag = CancellationBag()
      firstBag.insert(oldCancellable)
    } // firstBag deinits

    #expect(oldCancellable.cancelCount == 1)

    do {
      let secondBag = CancellationBag()
      secondBag.insert(newCancellable)
      #expect(newCancellable.cancelCount == 0)
    } // secondBag deinits

    #expect(newCancellable.cancelCount == 1)
  }

  // MARK: - Edge Cases

  @Test("Empty bag deinit does not crash")
  func emptyBagDeinitDoesNotCrash() {
    let bag = CancellationBag()
    _ = bag // suppress unused warning
  }

  @Test("Insert duplicate AnyCancellable only stored once")
  func insertDuplicateAnyCancellableOnlyStoredOnce() {
    let testCancellable = TestCancellable()
    let cancellable = AnyCancellable { testCancellable.cancel() }

    do {
      let bag = CancellationBag()
      bag.insert(cancellable)
      bag.insert(cancellable) // Duplicate
      #expect(testCancellable.cancelCount == 0)
    } // bag deinits

    #expect(testCancellable.cancelCount == 1) // Should only cancel once
  }

  @Test("Insert duplicate class instance as any Cancellable only stored once")
  func insertDuplicateClassCancellableOnlyStoredOnce() {
    let cancellable = TestCancellable()

    do {
      let bag = CancellationBag()
      bag.insert(cancellable as any Cancellable)
      bag.insert(cancellable as any Cancellable) // Duplicate insertion
      #expect(cancellable.cancelCount == 0)
    } // bag deinits

    #expect(cancellable.cancelCount == 1) // Deduped by identity: only one stored and cancelled
  }

  @Test("Duplicate struct instance as any Cancellable stores both copies and cancels each")
  func insertDuplicateStructCancellableStoredAndCancelledTwice() {
    let cancellable = TestStructCancellable()

    do {
      let bag = CancellationBag()
      bag.insert(cancellable as any Cancellable)
      bag.insert(cancellable as any Cancellable) // Duplicate insertion
      #expect(cancellable.cancellableObject.cancelCount == 0)
    } // bag deinits

    // A struct has no stable identity, so each copy counts as a distinct
    // insertion: both stored values are cancelled, i.e. twice in total.
    #expect(cancellable.cancellableObject.cancelCount == 2)
  }
}

@Suite("CancellationBag Reentrancy")
struct CancellationBagReentrancyTests {

  @Test("Reentrant insert during deinit gets cancelled immediately",
        .disabled("""
        Untestable via the public API: weak references to `ref` are already nil when its \
        deinit begins, so the closure below — invoked from `CancellationBag.deinit` — never \
        runs its reentrant insert. A strong capture would retain-cycle and deinit would \
        never run. Kept only as documentation.
        """))
  func reentrantInsertDuringDeinitGetsCancelledImmediately() {
    let otherCancellable = TestCancellable()
    nonisolated(unsafe) var reentrantCancelCount = 0

    do {
      let ref = CancellationBagRef()

      let reentrantCancellable = AnyCancellable { [weak ref] in
        // Weak references to an object are already nil when its deinit begins,
        // and this closure is only ever invoked from `CancellationBag.deinit`,
        // i.e. mid-`ref`-deinit. So this `guard` never passes exactly here
        // (a strong capture would retain-cycle and deinit would never run),
        // which is why this test is `.disabled`.
        guard let ref else { return }
        reentrantCancelCount += 1
        // Reentrantly insert another cancellable during cancellation
        ref.bag.insert(otherCancellable)
      }

      ref.bag.insert(reentrantCancellable)

      #expect(reentrantCancelCount == 0)
      #expect(otherCancellable.cancelCount == 0)
    } // ref deinits here, triggers reentrant insert

    #expect(reentrantCancelCount == 1)
    #expect(otherCancellable.cancelCount == 1) // Reentrant insert cancelled immediately
  }
}
