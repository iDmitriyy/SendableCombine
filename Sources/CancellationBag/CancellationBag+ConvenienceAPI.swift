//
//  CancellationBag+ConvenienceAPI.swift
//  SendableCombine
//
//  Created by Dmitriy Ignatyev on 07.08.2026.
//

public import Combine

extension CancellationBag {
  /// Convenience function allows a list of cancellables to be gathered for disposal.
  @export(implementation) @_transparent
  public func insert(_ anyCancellableObjects: AnyCancellable...) {
    insert(anyCancellableObjects)
  }

  /// Convenience function allows a list of cancellables to be gathered for disposal.
  @export(implementation) @_transparent
  public func insert(@DisposableBuilder builder: () -> [AnyCancellable]) {
    insert(builder())
  }

  /// A function builder accepting a list of cancellables and returning them as an array.
  @resultBuilder
  public enum DisposableBuilder {
    @export(implementation) @_transparent
    public static func buildBlock(_ anyCancellableObjects: AnyCancellable...) -> [AnyCancellable] {
      anyCancellableObjects
    }
  }
}

// MARK: - AnyCancellable + Bag

extension AnyCancellable {
  @export(implementation) @_transparent
  public final func store(in bag: borrowing CancellationBag) {
    bag.insert(self)
  }
}

extension Cancellable {
  @export(implementation) @_transparent
  public func store(in bag: borrowing CancellationBag) {
    bag.insert(self)
  }
}
