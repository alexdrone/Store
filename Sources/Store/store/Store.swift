import Foundation
import Combine

// MARK: - Protocols

/// Represents a opaque reference to a store object.
/// `Store` and `CodableStore` are the concrete instances.
public protocol AnyStore: class {

  // MARK: Observation
  
  /// Notify the store observers for the change of this store.
  /// `Store` and `CodableStore` are `ObservableObject`s and they automatically call this
  /// function (that triggers a `objectWillChange` publlisher) every time the model changes.
  /// - note: Observers are always scheduled on the main run loop.
  func notifyObservers()
  
  /// The block passed as argument does not trigger any notification for the Store observers.
  /// e.g. By calling `reduceModel(transaction:closure:)` inside the `perform` block the store
  /// won't pubblish any update.
  func performWithoutNotifyingObservers(_ perform: () -> Void)
  
  // MARK: Middleware

  /// Returns all of the registered middleware.
  var middleware: [Middleware] { get }
  
  /// Register a new middleware service.
  /// Middleware objects are notified whenever a transaction running in this store changes its
  /// state.
  func register(middleware: Middleware)
  
  /// Unregister a middleware service.
  func unregister(middleware: Middleware)

  /// Manually notify all of the registered middleware services.
  /// - note: See `MiddlewareType.onTransactionStateChange`.
  func notifyMiddleware(transaction: AnyTransaction)
  
  // MARK: Parent Store
  
  /// Recursively traverse the parents until it founds one that matches the specified model type.
  func parent<T>(type: T.Type) -> Store<T>?

  /// Wraps a reference to its parent store (if applicable) and describes how this store should
  /// be merged back.
  /// This is done by running `reconcile()` every time the model wrapped by this store changes.
  var combine: AnyCombineStore? { get }
}

/// Represents a store that has an typed associated model.
/// A reducible store can perform updates to its model by calling the
/// `reduceModel(transaction:closure:)` function.
public protocol ReducibleStore: AnyStore {
  associatedtype ModelType
  
  /// The associated model object.
  /// -note: This is typically a value type.
  var model: ModelType { get }
  
  /// Atomically update the model and notifies all of the observers.
  func reduceModel(transaction: AnyTransaction?, closure: (inout ModelType) -> Void)
}

// MARK: - Concrete Store

/// This class is the default implementation of the `ReducibleStore` protocol.
/// A store wraps a value-type model, synchronizes its mutations, and emits notifications to its
/// observers any time the model changes.
///
/// Model mutations are performed through `Action`s: These are operation-based, cancellable and
/// abstract the concurrency execution mode.
/// Every invokation of `run(action:)` spawns a new transaction object that can be logged,
/// rolled-back and used to inspect the model diffs (see `TransactionDiff`).
///
/// It's recommendable not to define a custom subclass (you can use `CodableStore` if you want
/// diffing and store serialization capabilities).
/// Domain-specific functions can be added to this class by writing an extension that targets the
/// user-defined model type.
/// e.g.
/// ```
/// let store = Store(model: Todo())
/// [...]
/// extension Store where M == Todo {
///   func upload() -> Future<Void, Error> {
///     run(action: TodoAction.uploadAndSynchronizeTodo, throttle: 1)
///   }
/// }
/// ```
open class Store<M>: ReducibleStore, ObservableObject, Identifiable {
  /// A publisher that emits when the model has changed.
  public let objectWillChange = ObservableObjectPublisher()
  
  // See `AnyStore`.
  public let combine: AnyCombineStore?
  public var middleware: [Middleware] = []
  // See `ReducibleStore`.
  public private(set) var model: M
  // Private.
  private var _stateLock = SpinLock()
  private var _performWithoutNotifyingObservers: Bool = false
  
  /// Constructs a new Store instance with a given initial model.
  public init(model: M) {
    self.model = model
    self.combine = nil
    register(middleware: LoggerMiddleware())
  }
  
  /// Constructs a new Store instance with a given initial model.
  ///
  /// - parameter model: The initial model state.
  /// - parameter combine: A associated parent store. Useful whenever it is desirable to merge
  ///                      back changes from a child store to its parent.
  public init<P>(model: M, combine: CombineStore<P, M>) {
    self.model = model
    self.combine = combine
    register(middleware: LoggerMiddleware())
    combine.child = self
  }

  // MARK: Model updates

  open func reduceModel(transaction: AnyTransaction? = nil, closure: (inout M) -> Void) {
    self._stateLock.lock()
    let old = self.model
    let new = assign(model, changes: closure)
    self.model = new
    self._stateLock.unlock()
    didUpdateModel(transaction: transaction, old: old, new: new)
  }

  /// Emits the `objectWillChange` event and propage the changes to its parent.
  /// - note: Call `super` implementation if you override this function.
  open func didUpdateModel(transaction: AnyTransaction?, old: M, new: M) {
    combine?.reconcile()
    notifyObservers()
  }

  open func notifyObservers() {
    guard !_performWithoutNotifyingObservers else { return }
    RunLoop.main.schedule {
      self.objectWillChange.send()
    }
  }
  
  public func performWithoutNotifyingObservers(_ perform: () -> Void) {
    _performWithoutNotifyingObservers = true
    perform()
    _performWithoutNotifyingObservers = false
  }
  
  // MARK: Middleware

  public func notifyMiddleware(transaction: AnyTransaction) {
    for mid in middleware {
      mid.onTransactionStateChange(transaction)
    }
  }

  public func register(middleware: Middleware) {
    guard self.middleware.filter({ $0 === middleware }).isEmpty else {
      return
    }
    self.middleware.append(middleware)
  }

  public func unregister(middleware: Middleware) {
    self.middleware.removeAll { $0 === middleware }
  }
  
  // MARK: Parent Store
  
  public func makeChildStore<C>(keyPath: WritableKeyPath<M, C>) -> Store<C> {
    Store<C>(model: model[keyPath: keyPath], combine: CombineStore(
      parent: self,
      notify: true,
      merge: .keyPath(keyPath: keyPath)))
  }
  
  public func parent<T>(type: T.Type) -> Store<T>? {
    if let parent = combine?.parentStore as? Store<T> {
      return parent
    }
    if let parent = combine?.parentStore {
      return parent.parent(type: type)
    }
    return nil
  }

  // MARK: Transactions
  
  /// Builds a transaction object for the action passed as argument.
  /// This can be executed by calling the `run` function on it.
  /// Transactions can depend on each other's completion by calling the `depend(on:)` function.
  /// e.g.
  /// ```
  /// let t1 = store.transaction(.addItem(cost: 125))
  /// let t2 = store.transaction(.checkout)
  /// let t3 = store.transaction(.showOrdern)
  /// t2.depend(on: [t1])
  /// t3.depend(on: [t2])
  /// [t1, t2, t3].run()
  /// ```
  ///
  /// - parameter action: The action that is going to be executed on this store.
  /// - parameter mode: The execution strategy (*sync*/*aysnc*).
  @discardableResult public func transaction<A: Action, M>(
    action: A,
    mode: Executor.Strategy = .async(nil)
  ) -> Transaction<A> where A.AssociatedStoreType: Store<M> {
    
    guard let store = self as? A.AssociatedStoreType else {
      fatalError("error: Store type mismatch.")
    }
    let transaction = Transaction<A>(action, in: store)
    transaction.on(mode)
    return transaction
  }
  
  // MARK: Running actions

  /// Runs the action passed as argument on this store.
  ///
  /// - parameter action: The action that is going to be executed on this store.
  /// - parameter mode: The execution strategy (*sync*/*aysnc*).
  /// - parameter throttle: If greater that 0, the action will only be triggered at most once
  ///                       during a given window of time.
  /// - parameter handler: Invoked when the action has finished running.
  /// - returns: The transaction associated to this action execution.
  @discardableResult public func run<A: Action, M>(
    action: A,
    mode: Executor.Strategy = .async(nil),
    throttle: TimeInterval = 0,
    handler: Executor.TransactionCompletion = nil
  ) -> Transaction<A> where A.AssociatedStoreType: Store<M> {
    
    let transaction = self.transaction(action: action, mode: mode)
    transaction.throttleIfNeeded(throttle)
    transaction.run(handler: handler)
    return transaction
  }

  /// Runs all of the actions passed as argument sequentially.
  /// This means that `actions[1]` will run after `actions[0]` has completed its execution,
  /// `actions[2]` after `actions[1]` and so on.
  @discardableResult public func run<A: Action, M>(
    actions: [A],
    mode: Executor.Strategy = .async(nil),
    handler: Executor.TransactionCompletion = nil
  ) -> [Transaction<A>] where A.AssociatedStoreType: Store<M> {
    
    let transactions = actions.map { transaction(action: $0, mode: mode) }
    for (idx, _) in transactions.reversed().enumerated() {
      guard idx < transactions.count - 1 else { break }
      transactions[idx].depend(on: [transactions[idx + 1]])
    }
    transactions.run(handler: handler)
    return transactions
  }
  
  // MARK: Running actions (Futures)
  
  /// Runs the action passed as argument on this store.
  ///
  /// - parameter action: The action that is going to be executed on this store.
  /// - parameter mode: The execution strategy (*sync*/*aysnc*).
  /// - parameter throttle: If greater that 0, the action will only be triggered at most once
  ///                       during a given window of time.
  /// - returns: A future that is resolved whenever the action has completed its execution.
  @discardableResult public func futureOf<A: Action, M>(
    action: A,
    mode: Executor.Strategy = .async(nil),
    throttle: TimeInterval = 0
  ) -> Future<Void, Error> where A.AssociatedStoreType: Store<M> {
    
    let transaction = self.transaction(action: action, mode: mode)
    transaction.throttleIfNeeded(throttle)
    return transaction.run()
  }
}

