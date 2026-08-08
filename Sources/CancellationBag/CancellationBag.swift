//
//  CancellationBag.swift
//  SendablePublishers
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine
import SendableCombineLogging
import struct os.OSAllocatedUnfairLock

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
  private let __storage: OSAllocatedUnfairLock<Storage>
  
  public init() {
    __storage = OSAllocatedUnfairLock(uncheckedState: Storage())
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
  
  private func __setDisposed_AndConsumeStorage_withLock() -> sending ConsumedStorage {
    __storage.withLockUnchecked { storage -> sending ConsumedStorage in
      storage.isDisposed = true
      
      let tasksToCancel: Set<AnyCancellableObj>
      if let taskBag = storage.taskCancellationBag {
        tasksToCancel = taskBag.__setDisposed_AndConsumeStorage_withLock()
        storage.taskCancellationBag = nil
      } else {
        tasksToCancel = Set()
      }
      
      let cancellableObjects = storage.cancellableObjects
      let cancellableExistentials = storage.cancellableValueTypeExistentials
      
      storage.cancellableObjects = Set()
      storage.cancellableValueTypeExistentials = ContiguousArray()

      return (cancellableObjects, cancellableExistentials, tasksToCancel)
    }
  }

  // MARK: - Insert single Cancellable

  public func insert(_ cancellableObject: any Cancellable & AnyObject) {
    __storage.withLockUnchecked { storage -> (any Cancellable & AnyObject)? in
      if storage.isDisposed {
        return cancellableObject
      } else {
        storage.cancellableObjects.insert(AnyCancellableObj(cancellableObject))
        return nil
      }
    }?.cancel()
  }

  public func insert(_ cancellable: any Cancellable) {
    if let cancellableObject = cancellable as? any Cancellable & AnyObject {
      // Reference type: deduplicated by identity and inserted once
      insert(cancellableObject)
    } else {
      // Value type: each insert stores a fresh copy, so duplicates are allowed.
      // Cancel outside the lock to prevent reentrancy.
      __storage.withLockUnchecked { storage -> (any Cancellable)? in
        if storage.isDisposed {
          return cancellable
        } else {
          storage.cancellableValueTypeExistentials.append(cancellable)
          return nil
        }
      }?.cancel()
    }
  }

  // MARK: - Insert multiple Cancellables
  
  public func insert<C: Collection>(_ anyCancellableObjects: C) where C.Element: Cancellable & AnyObject {
    let toCancel = __storage.withLockUnchecked { storage -> C? in
      if storage.isDisposed {
        return anyCancellableObjects
      } else {
        let wrapped = anyCancellableObjects.map { AnyCancellableObj($0 as any Cancellable & AnyObject) }
        storage.cancellableObjects.formUnion(wrapped)
        return nil
      }
    }

    // Cancel outside the lock to prevent reentrancy
    toCancel?.forEach { $0.cancel() }
  }
  
  public func insert(_ cancellables: some Collection<any Cancellable>) {
    var cancellableObjects: [any Cancellable & AnyObject] = []
    var cancellableValueTypeExistentials: [any Cancellable] = []

    // Split reference-type vs value-type Cancellables
    for cancellable in cancellables {
      if let cancellableObject = cancellable as? any Cancellable & AnyObject {
        cancellableObjects.append(cancellableObject)
      } else {
        cancellableValueTypeExistentials.append(cancellable)
      }
    }

    let toCancelExistentials = __storage.withLockUnchecked { storage -> [any Cancellable]? in
      if storage.isDisposed {
        return cancellableValueTypeExistentials
      } else {
        storage.cancellableValueTypeExistentials += cancellableValueTypeExistentials
        return nil
      }
    }
    // Cancel outside the lock to prevent reentrancy
    toCancelExistentials?.forEach { $0.cancel() }

    if !cancellableObjects.isEmpty {
      // FIXME: - now it is recursion, func above not called
      insert(cancellableObjects) // re-use the previous function
    }
  }

  private typealias ConsumedStorage = (cancellableObjects: Set<AnyCancellableObj>,
                                       cancellableExistentials: ContiguousArray<any Cancellable>,
                                       tasksToCancel: Set<AnyCancellableObj>)
  
  // TODO: ?make Storage ~Copyable.
  // Also deinit does not need withLock – we can access data directly. But if Storage is moveOnly, then
  // it is needed to be extracted from Mutex. Mutex need to be consumed in deinit which is not possible yet.
  // https://forums.swift.org/t/pitch-2-allowing-for-partial-mutation-and-consumption-inside-of-non-copyable-type-deinit/88437/3
  private struct Storage {
    var cancellableObjects: Set<AnyCancellableObj> = Set()
    var cancellableValueTypeExistentials: ContiguousArray<any Cancellable> = ContiguousArray()
    var taskCancellationBag: __TaskCancellationBag?
    
    var isDisposed: Bool = false
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - CancellationBag + Task

// ══════════════════════════════════════════════════════════════════════════════

//public import Foundation

extension CancellationBag {
  /// returns `nil` if `TaskCancellationBag` in disposed state.
  private func __taskBag_withLock() -> __TaskCancellationBag? {
    __storage.withLockUnchecked { storage in
      if storage.isDisposed {
        return nil
      }
      
      if let bag = storage.taskCancellationBag {
        return bag
      } else {
        let bag = __TaskCancellationBag()
        storage.taskCancellationBag = bag
        return bag
      }
    }
  }
  
  public func withCancellationOnBagDisposal<Success, Failure>(insert task: Task<Success, Failure>) {
    // taskBag is nil if `CancellationBag` was disposed.
    if let taskBag = __taskBag_withLock() {
      taskBag.__withCancellationOnBagDisposal(insert: task)
    } else {
      task.cancel()
    }
  }
}

// MARK: - Task Cancellation Bag

extension CancellationBag {
  /// Instance initialized lazily by `CancellationBag` by  on demand
  fileprivate final class __TaskCancellationBag: Sendable {
    private let __storage: OSAllocatedUnfairLock<Storage>

    internal init() {
      __storage = OSAllocatedUnfairLock(uncheckedState: (tasks: Set(), isDisposed: false))
    }

    // deinit {} // Tasks are cancelled by `CancellationBag` in its deinit

    fileprivate final func __setDisposed_AndConsumeStorage_withLock() -> sending Set<AnyCancellableObj> {
      __storage.withLockUnchecked { storage in
        storage.isDisposed = true
        let tasksToCancel = storage.tasks
        storage.tasks = Set()
        return tasksToCancel
      }
    }

    // MARK: - Insert / Remove

    private final func __insertOrCancel_withLock(taskCanceller: AnyCancellable) -> Bool {
      let inserted: Bool = __storage.withLockUnchecked { storage in
        guard !storage.isDisposed else { return false }
        
        storage.tasks.insert(AnyCancellableObj(taskCanceller))
        return true
      }
      
      if !inserted {
        taskCanceller.cancel()
      }
      return inserted
    }

    private final func __remove_withLock(taskCanceller: AnyCancellable) {
      __storage.withLockUnchecked { storage -> Void in
        guard !storage.isDisposed else { return }
        
        storage.tasks.remove(AnyCancellableObj(taskCanceller))
      }
    }

    private typealias Storage = (tasks: Set<AnyCancellableObj>, isDisposed: Bool)
  }
}

// MARK: - CancellationBag + Swift.Task

extension CancellationBag.__TaskCancellationBag {
  fileprivate final func __withCancellationOnBagDisposal(insert task: Task<some Any, some Any>) {
    let taskCanceller = AnyCancellable {
      task.cancel()
    }

    guard __insertOrCancel_withLock(taskCanceller: taskCanceller) else { return }

    Task(priority: .low) { [weak self, weak taskCanceller] in
      // taskCanceller is weak because only CancellationBag should store it.
      _ = await task.result

      guard let taskCanceller else { return }
      // if self == nil or taskCancellable == nil then task was cancelled on bag disposal
      // otherwise clean up resources if bag was not yet disposed / deinited
      // TODO: - cover all branched if self ==/!= nil + taskCanceller ==/!= nil, add logging
      self?.__remove_withLock(taskCanceller: taskCanceller)
      // free up memory (Task-shell itself with Success data, AnyCancellable wrapper)
    }
  }
}

//// MARK: - CancellationBag + URLSessionDataTask

public import Foundation
import Synchronization

extension CancellationBag {
  public func withCancellationOnBagDisposal(insert dataTask: URLSessionDataTask) {
    if let taskBag = __taskBag_withLock() {
      taskBag.__withCancellationOnBagDisposal(insert: dataTask)
    } else {
      dataTask.cancel()
    }
  }
}

extension CancellationBag.__TaskCancellationBag {
  /// Cancel URLSessionDataTask on `CancellationBag` disposal.
  fileprivate final func __withCancellationOnBagDisposal(insert dataTask: URLSessionDataTask) {
    let taskCanceller = AnyCancellable {
      dataTask.cancel()
    }

    guard __insertOrCancel_withLock(taskCanceller: taskCanceller) else { return }

    Task(priority: .low) { [weak self, weak taskCanceller] in
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
      self?.__remove_withLock(taskCanceller: taskCanceller)
    }
  }
}

// ------------------

/// A hashable identity wrapper around a reference-type `Cancellable`, so storage can
/// deduplicate instances via `==` (object identity) and hash them via `ObjectIdentifier`.
fileprivate struct AnyCancellableObj: Hashable {
  let cancellable: any Cancellable & AnyObject

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
