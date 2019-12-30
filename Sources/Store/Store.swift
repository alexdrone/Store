import Combine
import Foundation

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
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
  func notifyMiddleware(transaction: TransactionProtocol)
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public protocol StoreType: AnyStoreType {
  associatedtype ModelType

  /// The current state of this store.
  var model: ModelType { get }

  /// Atomically update the model.
  func reduceModel(transaction: TransactionProtocol?, closure: (inout ModelType) -> (Void))
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
open class Store<M>: StoreType, ObservableObject {
  /// The current state of this store.
  @Published public private(set) var model: M

  /// Opaque reference to the model wrapped by this store.
  public var modelRef: Any { return model }

  /// All of the registered middleware.
  public var middleware: [MiddlewareType] = []

  /// Syncronizes the access to the state object.
  private var _stateLock = SpinLock()

  public init(model: M) {
    self.model = model
  }

  /// Atomically update the model.
  open func reduceModel(transaction: TransactionProtocol? = nil, closure: (inout M) -> (Void)) {
    self._stateLock.lock()
    let old = self.model
    let new = assign(model, changes: closure)
    _onMainThread {
      self.model = new
    }
    didUpdateModel(transaction: transaction, old: old, new: new)
    self._stateLock.unlock()
  }

  open func didUpdateModel(transaction: TransactionProtocol?, old: M, new: M) {
    // Subclasses to override this.
  }

  /// Notify the store observers for the change of this store.
  /// - note: Observers are always notified on the main thread.
  open func notifyObservers() {
    _onMainThread {
      objectWillChange.send()
    }
  }

  /// Notify all of the registered middleware services.
  /// - note: See `MiddlewareType.onTransactionStateChange`.
  public func notifyMiddleware(transaction: TransactionProtocol) {
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
  ) -> Transaction<A> where A.AssociatedStoreType: Store<M> {
    guard let store = self as? A.AssociatedStoreType else {
      fatalError("error: Store type mismatch.")
    }
    return Transaction<A>(action, in: store).on(mode)
  }
  
  /// Shorthand for `transaction(action:mode:)` used in the DSL.
  @discardableResult @inlinable @inline(__always)
  public func transaction<A: ActionType, M>(
    _ action: A,
    _ mode: Dispatcher.Strategy = .async(nil)
  ) -> Transaction<A> where A.AssociatedStoreType: Store<M> {
    transaction(action: action, mode: mode)
  }

  @discardableResult @inlinable @inline(__always)
  public func run<A: ActionType, M>(
    action: A,
    mode: Dispatcher.Strategy = .async(nil),
    throttle: TimeInterval = 0,
    handler: Dispatcher.TransactionCompletionHandler = nil
  ) -> Transaction<A> where A.AssociatedStoreType: Store<M> {
    let tranctionObj = transaction(action: action, mode: mode)
    tranctionObj.run(handler: handler)
    if throttle > TimeInterval.ulpOfOne {
      tranctionObj.throttle(throttle)
    }
    return tranctionObj
  }

  @discardableResult @inlinable @inline(__always)
  public func run<A: ActionType, M>(
    actions: [A],
    mode: Dispatcher.Strategy = .async(nil),
    handler: Dispatcher.TransactionCompletionHandler = nil
  ) -> [Transaction<A>] where A.AssociatedStoreType: Store<M> {
    let transactions = actions.map { transaction(action: $0, mode: mode) }
    transactions.run(handler: handler)
    return transactions
  }
  
  /// Offers a DSL to to run a transaction group.
  /// The syntax is the following:
  /// ```
  /// store.runGroup {
  ///   Transaction(Action.foo)
  ///   Concurrent {
  ///     Transaction(Action.bar)
  ///     Transaction(Action.baz)
  ///   }
  ///   Transaction(Action.foobar)
  /// }
  /// ```
  /// This group results in the transactions being run in the following order:
  /// foo -> [ bar + baz] -> foobar
  @inlinable @inline(__always)
  public func runGroup(@TransactionSequenceBuilder builder: () -> [TransactionProtocol]) {
    let transactions = builder()
    for transaction in transactions {
      transaction.opaqueStoreRef = self
      transaction.run(handler: nil)
    }
  }

  @inline(__always)
  private func _onMainThread(_ closure: () -> Void) {
    if Thread.isMainThread {
      closure()
    } else {
      DispatchQueue.main.sync(execute: closure)
    }
  }
}
