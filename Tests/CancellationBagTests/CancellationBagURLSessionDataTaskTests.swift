import Testing
import Combine
import Foundation
import CancellationBag

// MARK: - URL for probe tasks

/// An unreachable address so a data task never makes real network traffic:
/// all tests below create tasks that are never `.resume()`d, keeping them in
/// `.suspended` until the bag (or the test) cancels them.
private let probeURL = URL(string: "http://127.0.0.1:99/cancellation-bag-probe")!

// MARK: - Helpers

/// Creates a `URLSessionDataTask` in `.suspended` state.
///
/// The task is created but never resumed, so it never performs any network
/// I/O and only leaves `.suspended` after `cancel()` is called (state moves
/// to `.canceling` synchronously and then to `.completed`).
private func makeSuspendedDataTask() -> URLSessionDataTask {
  URLSession.shared.dataTask(with: probeURL)
}

private func isTerminalState(_ state: URLSessionTask.State) -> Bool {
  switch state {
  case .canceling, .completed:
    return true
  case .running, .suspended:
    return false
  @unknown default:
    return false
  }
}

/// Polls `dataTask.state` until it reaches `.canceling` or `.completed`.
///
/// The transition to `.canceling` is synchronous with `cancel()`, so in the
/// bag-deinit paths this resolves almost immediately. Returns `false` if the
/// state never becomes terminal within `timeout`.
private func awaitTerminalState(of dataTask: URLSessionDataTask,
                                timeout: Duration) async -> Bool {
  let clock = ContinuousClock()
  let start = clock.now
  while !isTerminalState(dataTask.state) {
    if clock.now - start > timeout {
      return false
    }
    try? await Task.sleep(for: .milliseconds(10))
  }
  return true
}

/// Lets the `.low`-priority cleanup task settle.
///
/// The `__low` task spawned by `__withCancellationOnBagDisposal(insert:)`
/// observes `dataTask.state` and removes its `AnyCancellable` once the task
/// reaches `.canceling`/`.completed`. It runs on an unstructured
/// `Task(priority: .low)`, so give it a chance to complete before asserting
/// on post-deinit bookkeeping.
private func waitForCleanup() async {
  try? await Task.sleep(for: .milliseconds(50))
}

@Suite("CancellationBag + URLSessionDataTasks")
struct CancellationBagURLSessionDataTaskTests {

  // MARK: - Path A1 + B1: cancel pending dataTask on bag deinit

  @Test("Pending dataTask is cancelled when bag deinit runs")
  func cancelPendingDataTaskOnBagDeinit() async {
    // A1: bag NOT disposed, first insert. `__taskBag_withLock()` takes the
    //     `else` branch and lazily creates the task bag:
    //
    //     let bag = __TaskCancellationBag()
    //     storage.taskCancellationBag = bag
    //     return bag
    //
    // B1: `__withCancellationOnBagDisposal(insert:)` wraps cancellation:
    //
    //     let taskCanceller = AnyCancellable { dataTask.cancel() }
    //     guard __insertOrCancel_withLock(taskCanceller: taskCanceller) else { return }
    //     Task(priority: .low) { dataTask.observe(\.state, ...) ... }
    let dataTask = makeSuspendedDataTask()
    #expect(dataTask.state == URLSessionTask.State.suspended) // freshly created, never resumed

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: dataTask)
      #expect(isTerminalState(dataTask.state) == false) // bag alive -> not cancelled
    }
    // deinit calls `__setDisposed_AndConsumeStorage_withLock()`:
    //
    //   storage.isDisposed = true
    //   tasksToCancel = taskBag.__setDisposed_AndConsumeStorage_withLock()
    //   storage.taskCancellationBag = nil
    //
    // then cancels every stored `AnyCancellable`:
    //
    //   toCancel.tasksToCancel._forEach_UsingSpan_ { cancellable in
    //     cancellable.cancel()   // -> dataTask.cancel() -> state -> .canceling
    //   }

    let reachedTerminal = await awaitTerminalState(of: dataTask, timeout: .milliseconds(10))
    #expect(reachedTerminal) // cancel() is synchronous inside the AnyCancellable
    await waitForCleanup()
  }

  // MARK: - Path A2 + B1: multiple dataTasks

  @Test("Multiple different dataTasks are all cancelled on deinit")
  func multipleInsertedDataTasksAllCancelledOnBagDeinit() async {
    // A2: bag NOT disposed, repeated inserts hit the `if let bag` reuse branch:
    //
    //   if let bag = storage.taskCancellationBag { return bag }
    //
    // B1: each dataTask gets its own `AnyCancellable { dataTask.cancel() }`,
    //     all cancelled in deinit by `toCancel.tasksToCancel._forEach_UsingSpan_`.
    let dataTask1 = makeSuspendedDataTask()
    let dataTask2 = makeSuspendedDataTask()
    let dataTask3 = makeSuspendedDataTask()

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: dataTask1)
      bag.withCancellationOnBagDisposal(insert: dataTask2)
      bag.withCancellationOnBagDisposal(insert: dataTask3)
      #expect(isTerminalState(dataTask1.state) == false)
      #expect(isTerminalState(dataTask2.state) == false)
      #expect(isTerminalState(dataTask3.state) == false)
    }

    #expect(await awaitTerminalState(of: dataTask1, timeout: .milliseconds(10)))
    #expect(await awaitTerminalState(of: dataTask2, timeout: .milliseconds(10)))
    #expect(await awaitTerminalState(of: dataTask3, timeout: .milliseconds(10)))
    await waitForCleanup()
  }

  // MARK: - Path B1 (negative): dataTask untouched while bag alive

  @Test("dataTask is not cancelled while the bag is alive")
  func dataTaskNotCancelledWhileBagAlive() async {
    // B1: insert path only stores the task via `storage.tasks.insert(taskCanceller)`;
    //     no `cancel()` call while the bag is alive.
    let dataTask = makeSuspendedDataTask()

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: dataTask)

      #expect(isTerminalState(dataTask.state) == false) // bag still alive here
    } // bag deinit runs at end of this scope -> dataTask cancelled

    #expect(await awaitTerminalState(of: dataTask, timeout: .milliseconds(10)))
    await waitForCleanup()
  }

  // MARK: - Path end-to-end: cancellation propagates to the dataTask state

  @Test("Cooperative cancellation reaches the dataTask (state -> .canceling/.completed)")
  func pendingDataTaskCancellationIsCooperated() async {
    // B1 + deinit (`toCancel.tasksToCancel._forEach_UsingSpan_` cancels the
    // AnyCancellable, which runs `dataTask.cancel()`) + the observed state
    // transitions from `.suspended` to `.canceling` / `.completed`.
    let dataTask = makeSuspendedDataTask()
    #expect(dataTask.state == URLSessionTask.State.suspended)

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: dataTask)
      #expect(isTerminalState(dataTask.state) == false)
    }

    // The `.low` observation task inside the bag also watches `.state`, so the
    // transition proves the cancel() reached the underlying data task.
    #expect(await awaitTerminalState(of: dataTask, timeout: .milliseconds(10)))
    await waitForCleanup()
  }

  // MARK: - Already-cancelled dataTask: expectations from the public API

  @Test("Inserting an already-cancelled dataTask stays cancelled; disposal is a harmless no-op")
  func alreadyCancelledDataTaskStored_ThenBagDeinit_NoCrash() async {
    // Expectations derived from the public API, without looking inside the bag:
    //   1. Inserting an already-cancelled dataTask is valid and must not change
    //      the task's state — it stays cancelled.
    //   2. The bag promises to cancel this task at disposal. The task is
    //      already cancelled, so disposal must be a harmless no-op and must
    //      not crash.
    let dataTask = makeSuspendedDataTask()
    dataTask.cancel()
    #expect(isTerminalState(dataTask.state))

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: dataTask)
      #expect(isTerminalState(dataTask.state)) // stays cancelled while the bag is alive
    } // bag deinit: no-op re-cancel, must not crash

    #expect(isTerminalState(dataTask.state))
    await waitForCleanup()
  }

  // MARK: - Path C1: finished dataTask removed before bag deinit

  @Test("Disposing a bag that holds an already-finished dataTask does not crash")
  func completedDataTaskIsReleasedBeforeBagDeinit() async {
    // The `.low` observation task fires on its `.initial` value for a task
    // that is already terminal, then removes its `AnyCancellable`. Whether the
    // removal happened before deinit or deinit's `cancel()` fired on an already
    // cancelled task is not externally observable — `cancel()` on a finished
    // task is a no-op, so the only guarantee we can check from the public API
    // is that disposing the bag does not crash.
    let dataTask1 = makeSuspendedDataTask()
    dataTask1.resume() // start a real (failing) transfer so it can complete
    let dataTask2 = makeSuspendedDataTask()
    dataTask2.cancel()

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: dataTask1)
      bag.withCancellationOnBagDisposal(insert: dataTask2)
      _ = await awaitTerminalState(of: dataTask1, timeout: .milliseconds(10))
      _ = await awaitTerminalState(of: dataTask2, timeout: .milliseconds(10))
    } // disposal must not crash

    #expect(isTerminalState(dataTask1.state))
    #expect(isTerminalState(dataTask2.state))
    await waitForCleanup()
  }

  // MARK: - Path C2 + C3: cleanup races bag deinit (taskCanceller == nil, self == nil)

  @Test("Cleanup task racing bag deinit does not crash (taskCanceller/self released)")
  func cleanupTaskRacingBagDeinit_DoesNotCrash() async {
    // C2: deinit consumed the task bag:
    //
    //   tasksToCancel = taskBag.__setDisposed_AndConsumeStorage_withLock()
    //   storage.taskCancellationBag = nil
    //
    //     -> the AnyCancellable is released -> cleanup's weak taskCanceller == nil
    //     -> `guard let taskCanceller else { return }` early return.
    //
    // C3: `storage.taskCancellationBag = nil` releases `__TaskCancellationBag`
    //     -> cleanup's weak self == nil -> `self?.__remove_withLock(...)` no-op.
    let dataTask = makeSuspendedDataTask()

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: dataTask)
      // bag deinit happens here, BEFORE the `.low` cleanup task runs,
      // so the cleanup later finds taskCanceller == nil and self == nil.
    }

    #expect(await awaitTerminalState(of: dataTask, timeout: .milliseconds(10)))
    await waitForCleanup() // the stale cleanup task must complete without crashing
  }

  @Test("Cleanup removal racing disposal is a no-op",
        .disabled("""
        Untestable: the `guard !storage.isDisposed else { return }` in `__remove_withLock` \
        fires only if the `.low` cleanup task runs in the instruction window between \
        `taskBag.__setDisposed_AndConsumeStorage_withLock()` (which sets \
        `storage.isDisposed = true`) and `storage.taskCancellationBag = nil` inside \
        `CancellationBag.deinit`. That race cannot be arranged deterministically from a test, \
        and a wrongly-executed removal would only touch an already-emptied set.
        """))
  
  func cleanupRemovalRacingDisposalIsNoOp() {
    // Intended scenario: a finished dataTask's cleanup removes its AnyCancellable
    // from the task bag exactly while the bag is being disposed. Not reproducible.
  }

  // MARK: - Two bags must not share underlying state

  @Test("Two bags are independent: disposing one leaves the other bag's dataTask untouched")
  func twoBagsDoNotShareUnderlyingState() async {
    // Logical expectation from the public API: each `CancellationBag()` is a
    // standalone container. Disposing one bag must cancel only the dataTasks it
    // holds and must not affect tasks held by any other bag.
    let bag1Task = makeSuspendedDataTask()
    let bag2Task = makeSuspendedDataTask()

    do {
      let bag1 = CancellationBag()
      bag1.withCancellationOnBagDisposal(insert: bag1Task)

      do {
        let bag2 = CancellationBag()
        bag2.withCancellationOnBagDisposal(insert: bag2Task)
        #expect(isTerminalState(bag1Task.state) == false)
        #expect(isTerminalState(bag2Task.state) == false)
      } // bag2 deinits -> bag2Task cancelled

      #expect(await awaitTerminalState(of: bag2Task, timeout: .milliseconds(10)))
      #expect(isTerminalState(bag1Task.state) == false) // bag2's deinit must not touch bag1's task
    }

    #expect(await awaitTerminalState(of: bag1Task, timeout: .milliseconds(10)))
    await waitForCleanup()
  }

  // MARK: - The same dataTask inserted into two bags

  @Test("A dataTask shared by two bags is cancelled by whichever bag disposes first")
  func sameDataTaskInsertedIntoTwoBags() async {
    // Logical expectation from the public API: a dataTask may be governed by
    // several bags at once; each bag independently promises to cancel it.
    // The first bag to dispose cancels the task; disposing the second bag then
    // finds it already cancelled and is a harmless no-op (no crash).
    let dataTask = makeSuspendedDataTask()

    do {
      let firstBag = CancellationBag()
      firstBag.withCancellationOnBagDisposal(insert: dataTask)

      do {
        let secondBag = CancellationBag()
        secondBag.withCancellationOnBagDisposal(insert: dataTask)
        #expect(isTerminalState(dataTask.state) == false) // both bags still alive
      } // secondBag deinits -> dataTask cancelled

      #expect(await awaitTerminalState(of: dataTask, timeout: .milliseconds(10))) // disposed first, so it cancelled

      // firstBag is still alive here — its disposal now finds the dataTask
      // already cancelled: must be a no-op, not a crash.
    }

    #expect(isTerminalState(dataTask.state))
    await waitForCleanup()
  }
}
