import Testing
import Combine
import CancellationBag

// MARK: - Helpers

/// A pending task that keeps running until it is cancelled and then finishes.
/// Cooperative: never spins the scheduler — suspends between cancellation checks.
private func pendingTask() -> Task<Void, Never> {
  Task<Void, Never> {
    while !Task.isCancelled {
      // `Task.yield()` would busy-spin: with nothing else runnable the loop is
      // resumed immediately. A short sleep actually suspends this task, and it
      // aborts right away when cancellation lands (sleep throws on cancel).
      try? await Task.sleep(for: .microseconds(25))
    }
  }
}

/// A pending throwing task that runs until cancelled, then fails with `CancellationError`.
private func pendingThrowingTask() -> Task<Void, any Error> {
  Task<Void, any Error> {
    while true {
      try Task.checkCancellation()
      // Same as above: sleep, not yield, so the loop cannot busy-spin.
      try await Task.sleep(for: .microseconds(25))
    }
  }
}

/// Lets the `.low`-priority cleanup task settle.
///
/// `__withCancellationOnBagDisposal(insert:)` spawns an unstructured
/// `Task(priority: .low) { [weak self, weak taskCanceller] in ... }` whose
/// lifetime is independent of the bag's — it may finish at any time, before or
/// after the bag deinitializes. To give that low-priority task a chance to run,
/// we suspend with a sleep. A suspended task is not runnable, so priority does
/// not matter here: the executor is free to schedule the `.low` cleanup during
/// the sleep regardless of this task's own priority.
private func waitForCleanup() async {
  try? await Task.sleep(for: .milliseconds(50))
}

@Suite("CancellationBag + Tasks")
struct CancellationBagTaskTests {

  // MARK: - Path A1 + B1: cancel pending task on bag deinit

  @Test("Pending task is cancelled when bag deinit runs")
  func cancelPendingTaskOnBagDeinit() async {
    // A1: bag NOT disposed, first insert. `__taskBag_withLock()` takes the
    //     `else` branch and lazily creates the task bag:
    //
    //     let bag = __TaskCancellationBag()
    //     storage.taskCancellationBag = bag
    //     return bag
    //
    // B1: `__withCancellationOnBagDisposal(insert:)` wraps cancellation:
    //
    //     let taskCanceller = AnyCancellable { task.cancel() }
    //     guard __insertOrCancel_withLock(taskCanceller: taskCanceller) else { return }
    //     Task(priority: .low) { [weak self, weak taskCanceller] in ... }
    let task = pendingTask()

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: task)
      #expect(task.isCancelled == false) // bag alive -> not cancelled
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
    //     cancellable.cancel()
    //   }

    #expect(task.isCancelled == true) // cancel() is synchronous inside the AnyCancellable
    await task.value // task finished cooperating; avoids leaking a live task
  }

  // MARK: - Path A2 + B1: multiple tasks with different generic signatures

  @Test("Multiple tasks with different generic signatures are all cancelled on deinit")
  func multipleInsertedTasksAllCancelledOnBagDeinit() async {
    // A2: bag NOT disposed, repeated inserts hit the `if let bag` reuse branch:
    //
    //   if let bag = storage.taskCancellationBag { return bag }
    //
    // B1: each task gets its own `AnyCancellable { task.cancel() }`, all
    //     cancelled in deinit by `toCancel.tasksToCancel._forEach_UsingSpan_`
    let voidTask: Task<Void, Never> = pendingTask()
    let intTask: Task<Int, Never> = Task<Int, Never> {
      while !Task.isCancelled { await Task.yield() }
      return 42
    }
    let stringTask: Task<String, any Error> = Task<String, any Error> {
      while !Task.isCancelled { await Task.yield() }
      return "done"
    }

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: voidTask)
      bag.withCancellationOnBagDisposal(insert: intTask)
      bag.withCancellationOnBagDisposal(insert: stringTask)
      #expect(voidTask.isCancelled == false)
      #expect(intTask.isCancelled == false)
      #expect(stringTask.isCancelled == false)
    }

    #expect(voidTask.isCancelled == true)
    #expect(intTask.isCancelled == true)
    #expect(stringTask.isCancelled == true)

    await voidTask.value
    _ = await intTask.value
    _ = try? await stringTask.value
  }

  // MARK: - Path B1 (negative): task untouched while bag alive

  @Test("Task is not cancelled while the bag is alive")
  func taskNotCancelledWhileBagAlive() async {
    // B1: insert path only stores the task via `storage.tasks.insert(taskCanceller)`;
    //     no `cancel()` call while the bag is alive.
    let task = pendingTask()

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: task)

      #expect(task.isCancelled == false) // bag is still alive here, so the task runs
    } // bag deinit runs at end of this scope -> task cancelled

    #expect(task.isCancelled == true)
    await task.value
  }

  // MARK: - Path end-to-end: cooperative cancellation propagates to the task body

  @Test("Cooperative cancellation reaches the task body (checkCancellation throws)")
  func pendingTaskCancellationIsCooperative() async throws {
    // B1 + deinit (`toCancel.tasksToCancel._forEach_UsingSpan_` cancels the
    // AnyCancellable, which runs `task.cancel()`) + the Task body observes it.
    let task = pendingThrowingTask()

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: task)
      #expect(task.isCancelled == false)
    }

    #expect(task.isCancelled == true)
    // The body's `Task.checkCancellation()` loop now throws CancellationError,
    // proving the cancel() propagated into the running task.
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  // MARK: - Already-cancelled task: expectations from the public API

  @Test("Inserting an already-cancelled task keeps it cancelled; disposal is a harmless no-op")
  func alreadyCancelledTaskStored_ThenBagDeinit_NoCrash() async {
    // Expectations derived from the public API, without looking inside the bag:
    //   1. Inserting an already-cancelled task is valid and must not change
    //      the task's state — it stays cancelled.
    //   2. The bag promises to cancel this task at disposal. The task is
    //      already cancelled, so disposal must be a harmless no-op and must
    //      not crash.
    //   3. Awaiting the task settles on its outcome without errors/leaks.
    let task = pendingTask()
    task.cancel()
    #expect(task.isCancelled == true)

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: task)
      #expect(task.isCancelled == true) // stays cancelled while the bag is alive
    } // bag deinit: no-op re-cancel, must not crash

    #expect(task.isCancelled == true)
    await task.value
  }

  // MARK: - Path C1: completed task removed before bag deinit

  @Test("Disposing a bag that holds an already-finished task does not crash")
  func completedTaskIsReleasedBeforeBagDeinit() async throws {
    // What this can honestly assert: whether the internal `.low` cleanup removed
    // the finished task before deinit, or deinit's `cancel()` fired on it, is not
    // externally observable — `cancel()` on a finished task is a no-op, so the
    // task's outcome is identical either way. The only real guarantee we can
    // check from the public API is that disposing a bag that holds already
    // finished (successful or failed) tasks does not crash.
    let completedTask = Task<Int, Never> { 42 }
    struct TestError: Error {}
    let failedTask = Task<Void, any Error> { throw TestError() }

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: completedTask)
      bag.withCancellationOnBagDisposal(insert: failedTask)
      #expect(await completedTask.value == 42)
      do {
        try await failedTask.value
        Issue.record("expected TestError")
      } catch is TestError {
        // expected
      }
    } // disposal must not crash

    #expect(await completedTask.value == 42)
    do {
      try await failedTask.value
      Issue.record("expected TestError")
    } catch is TestError {
      // expected
    }
  }

  // MARK: - Path A3 + B2: reentrant insert during bag deinit cancels immediately

  @Test("Task inserted reentrantly during bag deinit is cancelled immediately",
        .disabled("""
        Untestable via the public API: weak references to `ref` are already nil when its \
        deinit begins (they are nilled before deinit runs), so the closure below — which \
        is only ever invoked from `CancellationBag.deinit` — never observes a live `ref`. \
        A strong capture would instead retain-cycle (`ref -> bag -> cancellable -> closure \
        -> ref`) and the deinit would never run. Awaiting the never-cancelled task would \
        hang, so the test is kept only as documentation.
        """))
  func reentrantInsertDuringBagDeinitCancelsImmediately() async {
    // A3: during deinit, `storage.isDisposed == true`, so `__taskBag_withLock()`
    //     returns nil:
    //
    //     if storage.isDisposed { return nil }
    //
    //     and the public wrapper takes the `else` branch:
    //
    //     if let taskBag = __taskBag_withLock() {
    //       taskBag.__withCancellationOnBagDisposal(insert: task)
    //     } else {
    //       task.cancel()     // <- immediate cancel
    //     }
    //
    // B2: (reached only if the insert lands on the task bag) `__insertOrCancel_withLock`
    //     returns false and calls `taskCanceller.cancel()` immediately:
    //
    //     guard !storage.isDisposed else { return false }
    //     ...
    //     if !inserted { taskCanceller.cancel() }
    let reentrantTask = pendingTask()

    do {
      let ref = CancellationBagRef() // holds the bag that will deinit at scope end
      let reentrantCancellable = AnyCancellable { [weak ref] in
        // Weak references to an object are already nil when its deinit begins,
        // and this closure is only ever invoked from `CancellationBag.deinit`,
        // i.e. mid-`ref`-deinit. So this `guard` never passes exactly here.
        // A strong capture would instead retain-cycle (`ref -> bag -> cancellable
        // -> closure -> ref`) and deinit would never run. Either way the
        // reentrant insert cannot happen, so A3/B2 are unreachable through the
        // public API and this test is `.disabled` (awaiting the never-cancelled
        // task would hang forever).
        guard let ref else { return }
        // Reentrant insertion while `ref.bag` is being deinitialized.
        // The deinit already set `storage.isDisposed = true`, so the new task
        // must be cancelled immediately.
        ref.bag.withCancellationOnBagDisposal(insert: reentrantTask)
      }
      ref.bag.insert(reentrantCancellable)

      #expect(reentrantTask.isCancelled == false) // bag still alive
    } // bag deinit -> cancels reentrantCancellable -> reentrant insert -> immediate cancel

    #expect(reentrantTask.isCancelled == true)
    await reentrantTask.value
  }

  // MARK: - Path C2 + C3: cleanup races bag deinit (taskCanceller == nil, self == nil)

  @Test("Cleanup task racing bag deinit does not crash (taskCanceller/self released)")
  func cleanupTaskRacingBagDeinit_DoesNotCrash() async throws {
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
    let task = pendingThrowingTask()

    do {
      let bag = CancellationBag()
      bag.withCancellationOnBagDisposal(insert: task)
      // bag deinit happens here, BEFORE the `.low` cleanup task runs,
      // so the cleanup later finds taskCanceller == nil and self == nil.
    }

    #expect(task.isCancelled == true)
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
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
    // Intended scenario: a finished task's cleanup removes its AnyCancellable from
    // the task bag exactly while the bag is being disposed. Not reproducible.
  }

  // MARK: - Two bags must not share underlying state

  @Test("Two bags are independent: disposing one leaves the other bag's task untouched")
  func twoBagsDoNotShareUnderlyingState() async {
    // Logical expectation from the public API: each `CancellationBag()` is a
    // standalone container. Disposing one bag must cancel only the tasks it
    // holds and must not affect tasks held by any other bag.
    let bag1Task = pendingTask()
    let bag2Task = pendingTask()

    do {
      let bag1 = CancellationBag()
      bag1.withCancellationOnBagDisposal(insert: bag1Task)

      do {
        let bag2 = CancellationBag()
        bag2.withCancellationOnBagDisposal(insert: bag2Task)
        #expect(bag1Task.isCancelled == false)
        #expect(bag2Task.isCancelled == false)
      } // bag2 deinits -> bag2Task cancelled

      #expect(bag2Task.isCancelled == true)
      #expect(bag1Task.isCancelled == false) // bag2's deinit must not touch bag1's task
    }

    #expect(bag1Task.isCancelled == true)
    await bag1Task.value
    await bag2Task.value
  }

  // MARK: - The same task inserted into two bags

  @Test("A task shared by two bags is cancelled by whichever bag disposes first")
  func sameTaskInsertedIntoTwoBags() async {
    // Logical expectation from the public API: a task may be governed by
    // several bags at once; each bag independently promises to cancel it.
    // The first bag to dispose cancels the task; the second bag then finds
    // it already cancelled and its disposal is a harmless no-op (no crash).
    let task = pendingTask()

    do {
      let firstBag = CancellationBag()
      firstBag.withCancellationOnBagDisposal(insert: task)

      do {
        let secondBag = CancellationBag()
        secondBag.withCancellationOnBagDisposal(insert: task)
        #expect(task.isCancelled == false) // both bags still alive
      } // secondBag deinits -> task cancelled

      #expect(task.isCancelled == true) // disposed first, so it triggered the cancel
      await task.value // cancel fired; task finished cooperatively

      // firstBag is still alive here — its disposal now finds the task
      // already cancelled: must be a no-op, not a crash.
    } // firstBag deinits -> no-op re-cancel

    #expect(task.isCancelled == true)
    await task.value
  }
}
