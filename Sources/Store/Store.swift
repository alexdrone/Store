import Foundation
import Combine

/// Models that are going to accessed through a store must conform to this protocol.
public protocol ModelType {
  /// Mandatory empty constructor.
  init()
}

/// Mark a store model as immutable.
/// - note: If you implement your model using structs, conform to this protocol.
public protocol ImmutableModelType: ModelType { }

/// This function is used to copy the values of all enumerable own properties from one or more
/// source struct to a target struct. It will return the target struct.
/// - note: This is analogous to Object.assign in Javascript and should be used to update
/// ImmutableModelTypes.
public func assign<T>(_ value: T, changes: (inout T) -> Void) -> T {
  guard Mirror(reflecting: value).displayStyle == .struct else {
    fatalError("'value' must be a struct.")
  }
  var copy = value
  changes(&copy)
  return copy
}

public protocol StoreType: class {
  /// Opaque reference to the model wrapped by this store.
  var modelRef: ModelType { get }
  /// Notify the store observers for the change of this store.
  /// - note: Observers are always notified on the main thread.
  func notifyObservers()
}

@available(iOS 13.0, macOS 10.15, *)
open class Store<M: ModelType>: StoreType, ObservableObject {
  /// The current state for the Store.
  public private(set) var model: M
  /// Opaque reference to the model wrapped by this store.
  public var modelRef: ModelType { return model }
  // Syncronizes the access tp the state object.
  private let stateLock = NSRecursiveLock()

  public init(model: M = M()) {
    self.model = model
  }

  /// Called from the reducer to update the store state.
  public func updateModel(closure: (inout M) -> (Void)) {
    self.stateLock.lock()
    self.model = assign(model, changes: closure)
    self.stateLock.unlock()
  }

  /// Notify the store observers for the change of this store.
  /// - note: Observers are always notified on the main thread.
  open func notifyObservers() {
    func notify() {
      objectWillChange.send()
    }
    // Makes sure the observers are notified on the main thread.
    if Thread.isMainThread {
      notify()
    } else {
      DispatchQueue.main.sync(execute: notify)
    }
  }

}
