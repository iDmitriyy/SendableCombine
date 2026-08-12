//
//  CancellationBag.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine
import struct os.OSAllocatedUnfairLock
import SendableCombineLogging

// private import struct OrderedCollections.OrderedSet

/// A thread-safe container of Combine cancellables
/// that cancels added cancellables on `deinit`.
///
/// Use `CancellationBag` when you need:
/// - Deterministic cancellation on scope end
/// - Explicit lifecycle boundaries
/// - Thread-safe insertion and disposal
///
/// ## Example
///
/// ```swift
/// let bag = CancellationBag()
///
/// publisher
///     .sink { print($0) }
///     .store(in: bag)
///
/// ```
///
/// ## Comparison with `Set<AnyCancellable>`
///
/// | Feature                              |      `Set<AnyCancellable>`      | `CancellationBag` |
/// |:------------------------------:|:----------------------------------------:|:-------------------------:|
/// | Cancellation trigger           | ARC deinit of each AnyCancellable |  ARC deinit of bag        |
/// | Thread-safe                       | No                                                     | Yes                               |
/// | Reentrancy-safe                | No                                                     | Yes                               |
/// | Ordered / unique storage | N/A                                                    | Yes                               |
/// | Insert during disposal        | Undefined                                        | Cancel immediately     |
/// | RxSwift-style semantics    | No                                                    | Yes                               |
/// ¹ Insertions performed reentrantly during bag deinitialization are
///  cancelled immediately to avoid leaks.
///
/// ## Notes
/// - Cancellation always occurs outside internal locks to avoid reentrancy
///   and deadlocks.
/// - Intended for ViewModels, coordinators, and long-lived services.
/// - There is no public `cancel()` method; cancellation is performed by
///   releasing or replacing the bag.
///
/// ## Example: owner scope
///
/// ```swift
/// final class Owner {
///     let bag = CancellationBag()
///
///     init() {
///         publisher
///             .sink { print($0) }
///             .store(in: bag)
///     }
/// }
/// ```
///
/// ## Example: cancel all subscriptions
///
/// ### Using `Set<AnyCancellable>`
///
/// ```swift
/// final class Service {
///     private var cancellables = Set<AnyCancellable>()
///
///     func start() {
///         publisher
///             .sink { print($0) }
///             .store(in: &cancellables)
///     }
///
///     func stop() {
///         cancellables.removeAll()
///     }
/// }
/// ```
/// Removing all elements drops references, but cancellation occurs only
/// when ARC deallocates each `AnyCancellable`. The timing is not guaranteed.
/// **What you might want:**
/// - Subscriptions are cancelled immediately when stop() is called
/// **What actually happens:**
/// - removeAll() drops references
/// - Cancellation occurs only when ARC deallocates each AnyCancellable
/// - Deallocation timing:
///   - may be immediate
///   - may be deferred
///   - may never happen (if references exist elsewhere)
/// You cannot guarantee that cancellation happens at stop()
///
/// ### Using `CancellationBag`
///
/// ```swift
/// final class Service {
///     private var bag = CancellationBag()
///
///     func start() {
///         publisher
///             .sink { print($0) }
///             .store(in: bag)
///     }
///
///     func stop() {
///         bag = CancellationBag() // deinitializes old bag
///     }
/// }
/// ```
/// Replacing the bag deterministically cancels all stored subscriptions
/// exactly once, on the calling thread, while the service itself remains alive.
/// **What you get:**
/// - destroying of old bag calls `cancel()` immediately
/// - Happens on the calling thread
/// - Happens exactly once
/// - Service remains alive
/// - New subscriptions after `dispose()` are cancelled immediately
///   (via reentrancy or races during deinit).
///
/// Inspired by:
/// https://github.com/ReactiveX/RxSwift/blob/5004a18539bd68905c5939aa893075f578f4f03d/RxSwift/Disposables/DisposeBag.swift
@_staticExclusiveOnly
public struct CancellationBag: ~Copyable, Sendable {
  private let __storage: OSAllocatedUnfairLock<__Storage>

  public init() {
    __storage = OSAllocatedUnfairLock(uncheckedState: __Storage())
  }

  deinit {
    let toCancel = __setDisposed_AndConsumeStorage_withLock()

    toCancel.cancellableObjects.forEach { cancellable in
      cancellable.cancel()
    }

    do {
      let span = toCancel.cancellableExistentials.span
      for index in span.indices {
        span[index].cancel()
      }
    }

    toCancel.tasksToCancel.forEach { cancellable in
      cancellable.cancel()
    }
  }

  @inline(always)
  private func __setDisposed_AndConsumeStorage_withLock() -> sending ConsumedStorage {
    __storage.withLockUnchecked { storage -> sending ConsumedStorage in
      let tasksToCancel: Set<AnyCancellableObj>
      if let taskBag = storage.setDisposedConsumingTaskBag() {
        tasksToCancel = taskBag.__setDisposed_AndConsumeStorage_withLock()
      } else {
        tasksToCancel = Set()
      }
      // TODO: may be just return (ConsumedStorage, tasksToCancel)
      // in here: only make storage.cancellableObjects & cancellableValueTypeExistentials empty)
      // taskCancellationBag = nil
      let cancellableObjects = storage.cancellableObjects
      let cancellableExistentials = storage.cancellableValueTypeExistentials

      storage.cancellableObjects = Set()
      storage.cancellableValueTypeExistentials = ContiguousArray()

      return (cancellableObjects, cancellableExistentials, tasksToCancel)
    }
  }

  // MARK: - Insert single Cancellable

  public func insert(_ cancellable: any Cancellable) {
    let isInserted = __storage.withLockUnchecked { storage -> Bool in
      if storage.isDisposed {
        return false
      } else {
        if let cancellableObject = cancellable as? any Cancellable & AnyObject {
          // Reference type: deduplicated by identity and inserted once
          storage.cancellableObjects.insert(AnyCancellableObj(cancellableObject))
        } else {
          // Value type: each insert stores a copy, so duplicates are value-type duplicates inserted twice.
          storage.cancellableValueTypeExistentials.append(cancellable)
        }
        return true
      }
    }
    
    if !isInserted {
      cancellable.cancel() // Cancel outside the lock to prevent reentrancy.
    }
  }

  // MARK: - Insert multiple Cancellables

  public func insert<C: Collection>(_ anyCancellableObjects: C) where C.Element: Cancellable & AnyObject {
    let isInserted = __storage.withLockUnchecked { storage -> Bool in
      if storage.isDisposed {
        return false
      } else {
        for instance in anyCancellableObjects {
          storage.cancellableObjects.insert(AnyCancellableObj(instance))
        }
        return true
      }
    }
    // Cancel outside the lock to prevent reentrancy
    if !isInserted {
      for instance in anyCancellableObjects {
        instance.cancel()
      }
    }
    
    // FIXME: reuse common func for insertion single and many.
    // May be make in generic for (any Cancellable) & (any Cancellable & AnyObject) and check P.Self is
    // is AnyObject, check bin size. Or @specialize
    // private static func __unprotected_insert<T: AnyCancellable>(_ cancellable: T, to: inout Storage) {}
  }

  // TODO: @_noImplicitCopy _ cancellables
  public func insert<C: Collection>(_ cancellables: C) where C.Element == any Cancellable {
    let isInserted = __storage.withLockUnchecked { storage -> Bool in
      if storage.isDisposed {
        return false
      } else {
        for cancellable in cancellables {
          if let cancellableObject = cancellable as? any Cancellable & AnyObject {
            // Reference type: deduplicated by identity and inserted once
            storage.cancellableObjects.insert(AnyCancellableObj(cancellableObject))
          } else {
            // Value type: each insert stores a copy, so duplicates are value-type duplicates inserted twice.
            storage.cancellableValueTypeExistentials.append(cancellable)
          }
        }
        return true
      }
    }
    // Cancel outside the lock to prevent reentrancy
    if !isInserted {
      for cancellable in cancellables {
        cancellable.cancel()
      }
    }
  }

  private typealias ConsumedStorage = (cancellableObjects: Set<AnyCancellableObj>,
                                       cancellableExistentials: ContiguousArray<any Cancellable>,
                                       tasksToCancel: Set<AnyCancellableObj>)

  // MARK: - Storage

  // TODO: ?make Storage ~Copyable.
  // Also deinit does not need withLock – we can access data directly. But if Storage is moveOnly, then
  // it is needed to be extracted from Mutex. Mutex need to be consumed in deinit which is not possible yet.
  // https://forums.swift.org/t/pitch-2-allowing-for-partial-mutation-and-consumption-inside-of-non-copyable-type-deinit/88437/3
  private struct __Storage {
    var cancellableObjects: Set<AnyCancellableObj> = Set()
    var cancellableValueTypeExistentials: ContiguousArray<any Cancellable> = ContiguousArray()
    private var taskCancellationBag: __TaskCancellationBag?
    
    private(set) var isDisposed: Bool = false
    
    @_transparent
    mutating func setDisposedConsumingTaskBag() -> __TaskCancellationBag? {
      isDisposed = true; return taskCancellationBag.take()
    }
    
    @_transparent
    mutating func taskBag() -> __TaskCancellationBag? {
      if isDisposed { return nil }

      if let bag = taskCancellationBag {
        return bag
      } else {
        let bag = __TaskCancellationBag()
        taskCancellationBag = bag
        return bag
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - CancellationBag + Task

// ══════════════════════════════════════════════════════════════════════════════

extension CancellationBag {
//  /// returns `nil` if `CancellationBag` in disposed state.
  private func __taskBag_withLock() -> __TaskCancellationBag? {
    __storage.withLockUnchecked { storage in
      storage.taskBag()
    }
  }

  public func withCancellationOnBagDisposal(insert task: Task<some Any, some Any>) {
    // taskBag is nil if `CancellationBag` was disposed.
    guard let taskBag = __taskBag_withLock() else {
      task.cancel()
      return
    }

    let taskCanceller = AnyCancellable {
      task.cancel()
    }

    guard taskBag.__insertOrCancel_withLock(taskCanceller: taskCanceller) else { return }

    Task(priority: .low) { [weak taskBag, weak taskCanceller] in
      // taskCanceller is weak because only CancellationBag should retain it.
      _ = await task.result

      guard let taskCanceller else { return }
      // if self == nil or taskCancellable == nil then task was cancelled on bag disposal
      // otherwise clean up resources if bag was not yet disposed / deinited
      // TODO: - cover all branched if self ==/!= nil + taskCanceller ==/!= nil, add logging
      taskBag?.__remove_withLock(taskCanceller: taskCanceller)
      // free up memory (Task-shell itself with Success data, AnyCancellable wrapper)
    }
  }
}

// MARK: - Task Cancellation Bag

extension CancellationBag {
  /// Instance initialized lazily by `CancellationBag` by  on demand
  fileprivate final class __TaskCancellationBag: Sendable {
    private let __taskStorage: OSAllocatedUnfairLock<Storage>

    fileprivate init() {
      __taskStorage = OSAllocatedUnfairLock(uncheckedState: (tasks: Set(), isDisposed: false))
    }

    // deinit {} // Tasks are cancelled by `CancellationBag` in its deinit
    
    fileprivate final func __setDisposed_AndConsumeStorage_withLock() -> sending Set<AnyCancellableObj> {
      __taskStorage.withLockUnchecked { storage in
        storage.isDisposed = true
        let tasksToCancel = storage.tasks
        storage.tasks = Set()
        return tasksToCancel
      }
    }

    // MARK: - Insert / Remove

    fileprivate final func __insertOrCancel_withLock(taskCanceller: AnyCancellable) -> Bool {
      let inserted: Bool = __taskStorage.withLockUnchecked { storage in
        if storage.isDisposed { return false }

        storage.tasks.insert(AnyCancellableObj(taskCanceller))
        return true
      }

      if !inserted {
        taskCanceller.cancel()
      }
      return inserted
    }

    fileprivate final func __remove_withLock(taskCanceller: AnyCancellable) {
      __taskStorage.withLockUnchecked { storage in
        guard !storage.isDisposed else { return }

        storage.tasks.remove(AnyCancellableObj(taskCanceller))
      }
    }

    private typealias Storage = (tasks: Set<AnyCancellableObj>, isDisposed: Bool)
  }
}

//// MARK: - CancellationBag + URLSessionDataTask

public import Foundation
import Synchronization

extension CancellationBag {
  /// Cancel URLSessionDataTask on `CancellationBag` disposal.
  public func withCancellationOnBagDisposal(insert dataTask: URLSessionDataTask) {
    guard let taskBag = __taskBag_withLock() else {
      dataTask.cancel()
      return
    }

    let taskCanceller = AnyCancellable {
      dataTask.cancel()
    }

    guard taskBag.__insertOrCancel_withLock(taskCanceller: taskCanceller) else { return }

    Task(priority: .low) { [weak taskBag, weak taskCanceller] in
      var observation: NSKeyValueObservation?
      let wasResumed = Mutex(false)
      await withCheckedContinuation { continuation in
        let observation_ = dataTask.observe(\.state, options: [.initial, .new]) { dataTask, _ in
          wasResumed.withLock { wasResumed in
            guard !wasResumed else { return }
            switch dataTask.state {
            case .canceling,
                 .completed:
              wasResumed = true
              continuation.resume()
            case .running,
                 .suspended:
              break
            @unknown default:
              let message = "URLSessionDataTask state transitioned to a future, unknown state. " +
                "The observation is being torn down to avoid a dangling continuation. "
                + "Library Need to be updated to properly handle this case."
              _log(.critical, SendableCombineLogEntry(code: .unexpectedCodeEntrance,
                                                      message: message,
                                                      info: ["dataTask.state": "\(dataTask.state)"]))
              wasResumed = true
              continuation.resume()
            }
          }
        }
        observation = observation_
      }

      guard let taskCanceller else { return }
      _ = consume observation
      taskBag?.__remove_withLock(taskCanceller: taskCanceller)
    } // end Task(priority: .low)
  }
}

// ------------------

/// A hashable identity wrapper around a reference-type `Cancellable`, so storage can
/// deduplicate instances via `==` (object identity) and hash them via `ObjectIdentifier`.
fileprivate struct AnyCancellableObj: Hashable {
  let cancellable: any Cancellable & AnyObject

  @_transparent
  init(_ cancellable: any Cancellable & AnyObject) {
    self.cancellable = cancellable
  }

  @_transparent
  func cancel() {
    cancellable.cancel()
  }

  @inlinable
  static func == (lhs: AnyCancellableObj, rhs: AnyCancellableObj) -> Bool {
    lhs.cancellable === rhs.cancellable
  }

  @inlinable
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(cancellable as AnyObject))
  }
}
