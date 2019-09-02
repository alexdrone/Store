import Foundation
import Combine

/// This function is used to copy the values of all enumerable own properties from one or more
/// source struct to a target struct. It will return the target struct.
/// - note: This is analogous to Object.assign in Javascript and should be used to update
/// immutabel model types.
public func assign<T>(_ value: T, changes: (inout T) -> Void) -> T {
  guard Mirror(reflecting: value).displayStyle == .struct else {
    fatalError("'value' must be a struct.")
  }
  var copy = value
  changes(&copy)
  return copy
}

@available(iOS 13.0, macOS 10.15, *)
public protocol AnyStoreType: class {
  /// Opaque reference to the model wrapped by this store.
  var modelRef: Any { get }
  /// All of the registered middleware.
  var middleware: [MiddlewareType] { get }
  /// Register a new middleware service.
  func register(middleware: MiddlewareType)
  /// Unregister a middleware service.
  func unregister(middleware: MiddlewareType)
  /// Notify the store observers for the change of this store.
  /// - note: Observers are always notified on the main thread.
  func notifyObservers()
  /// Notify all of the registered middleware services.
  /// - note: See `MiddlewareType.onTransactionStateChange`.
  func notifyMiddleware(transaction: AnyTransaction)
}

@available(iOS 13.0, macOS 10.15, *)
public protocol StoreType: AnyStoreType {
  associatedtype ModelType
  /// The current state of this store.
  var model: ModelType { get }
  /// Atomically update the model.
  func updateModel(transaction: AnyTransaction?, closure: (inout ModelType) -> (Void))
}

@available(iOS 13.0, macOS 10.15, *)
open class Store<M>: StoreType, ObservableObject {
  /// The current state of this store.
  public private(set) var model: M
  /// Opaque reference to the model wrapped by this store.
  public var modelRef: Any { return model }
  /// All of the registered middleware.
  public var middleware: [MiddlewareType] = []
  // Syncronizes the access to the state object.
  private let stateLock = Lock()

  public init(model: M) {
    self.model = model
  }

  /// Atomically update the model.
  open func updateModel(transaction: AnyTransaction? = nil, closure: (inout M) -> (Void)) {
    self.stateLock.lock()
    let old = self.model
    let new = assign(model, changes: closure)
    self.model = new
    didUpdateModel(transaction: transaction, old: old, new: new)
    self.stateLock.unlock()
  }

  open func didUpdateModel(transaction: AnyTransaction?, old: M, new: M) {
    // Subclasses to override this.
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

  /// Notify all of the registered middleware services.
  /// - note: See `MiddlewareType.onTransactionStateChange`.
  public func notifyMiddleware(transaction: AnyTransaction) {
    for mid in middleware {
      mid.onTransactionStateChange(transaction)
    }
  }

  /// Register a new middleware service.
  public func register(middleware: MiddlewareType) {
    guard self.middleware.filter({ $0 === middleware }).isEmpty else {
      return
    }
    self.middleware.append(middleware)
  }

  /// Unregister a middleware service.
  public func unregister(middleware: MiddlewareType) {
    self.middleware.removeAll { $0 === middleware }
  }

  public func transaction<A: ActionType, M>(
    action: A,
    mode: Dispatcher.Strategy = .async(nil)
  ) -> Transaction<A> where A.AssociatedStoreType : Store<M> {
    guard let store = self as? A.AssociatedStoreType else {
      fatalError("error: Store type mismatch.")
    }
    return Transaction<A>(action, in: store).on(mode)
  }

  @discardableResult
  public func run<A: ActionType, M>(
    action: A,
    mode: Dispatcher.Strategy = .async(nil),
    handler: Dispatcher.TransactionCompletionHandler = nil
  ) -> Transaction<A> where A.AssociatedStoreType : Store<M> {
    let tranctionObj = transaction(action: action, mode: mode)
    tranctionObj.run(handler: handler)
    return tranctionObj
  }

  @discardableResult
  public func run<A: ActionType, M>(
    actions: [A],
    mode: Dispatcher.Strategy = .async(nil),
    handler: Dispatcher.TransactionCompletionHandler = nil
  ) -> [Transaction<A>] where A.AssociatedStoreType : Store<M> {
    let transactions = actions.map { transaction(action: $0, mode: mode) }
    transactions.run(handler: handler)
    return transactions
  }
}
