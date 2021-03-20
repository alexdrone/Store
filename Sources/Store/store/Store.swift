import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
import OpenCombineDispatch
#endif

// MARK: - Protocols

/// Represents a opaque reference to a store object.
/// `Store` and `CodableStore` are the concrete instances.
public protocol AnyStore: class {

  // MARK: Observation
    
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
  
  /// Recursively traverse the parents until it founds one that matches the specified model type.
  func parent<T>(type: T.Type) -> Store<T>?
}

/// Represents a store that has an typed associated model.
/// A reducible store can perform updates to its model by calling the `update(transaction:closure:)`
/// function.
public protocol MutableStore: AnyStore {
  associatedtype ModelType
  
  /// The associated model object.
  /// -note: This is typically a value type.
  var modelStorage: ModelStorageBase<ModelType> { get }
  
  /// Atomically update the model and notifies all of the observers.
  func update(transaction: AnyTransaction?, closure: (inout ModelType) -> Void)
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
open class Store<M>: MutableStore, ObservableObject, Identifiable {

  /// A publisher that emits when the model has changed.
  public let objectWillChange = ObservableObjectPublisher()

  /// Used to have read-write access to the model through `@Binding` in SwiftUI.
  /// e.g.
  /// `Toggle("...", isOn: $store.bindingProxy.someProperty)`.
  /// When the binding set a new value an implicit action is being triggered and the property is
  /// updated.
  public var binding: BindingProxy<M>! = nil
  
  /// Accessor to the wrapped immutable  model.
  public var readOnlyModel: M { modelStorage.model }
  
  // See `AnyStore`.
  public var middleware: [Middleware] = []
  public private(set) var modelStorage: ModelStorageBase<M>
  
  // Internal
  public let parent: AnyStore?
  
  // Private.
  private var performWithoutNotifyingObservers: Bool = false
  private var modelStorageObserver: AnyCancellable?
  
  public var debugDescription: String { "@\(M.self)" }
  
  /// Constructs a new Store instance with a given initial model.
  public convenience init(model: M, parent: AnyStore? = nil) {
    self.init(modelStorage: ModelStorage(model: model))
  }
  
  public init(modelStorage: ModelStorageBase<M>, parent: AnyStore? = nil) {
    self.modelStorage = modelStorage
    self.parent = parent
    self.binding = BindingProxy(store: self)
    
    register(middleware: LoggerMiddleware())
    
    modelStorageObserver = modelStorage.objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        guard let self = self else { return }
        guard !self.performWithoutNotifyingObservers else { return }
        self.objectWillChange.send()
      }
  }
  
  /// Creates a store for a subtree of this store model. e.g.
  /// ```
  /// struct Subject {
  ///   struct Teacher { var name }
  ///   let title: String
  ///   let teacher: Teacher
  /// }
  /// let subjectStore = Store(model: Subject(...))
  /// let teacherStore = subjectStore.makeChild(keyPath: \.teacher)
  /// ```
  /// When the child store is being updated the parent store (this object) will also trigger
  /// a `objectWillChange` notification.
  ///
  ///  - parameter keyPath: The keypath pointing at a subtree of the model object.
  public func makeChildStore<C>(keyPath: WritableKeyPath<M, C>) -> Store<C> {
    let childModelStorage: ModelStorageBase<C> = modelStorage.makeChild(keyPath: keyPath)
    let store = Store<C>(modelStorage: childModelStorage, parent: self)
    return store
  }
  
  public func parent<T>(type: T.Type) -> Store<T>? {
    if let parent = parent as? Store<T> {
      return parent
    }
    return parent?.parent(type: type)
  }

  // MARK: Model updates

  public func update(transaction: AnyTransaction? = nil, closure: (inout M) -> Void) {
    let old = modelStorage.model
    modelStorage.mutate(closure)
    let new = modelStorage.model
    didUpdateModel(transaction: transaction, old: old, new: new)
  }

  /// Emits the `objectWillChange` event and propage the changes to its parent.
  /// - note: Call `super` implementation if you override this function.
  open func didUpdateModel(transaction: AnyTransaction?, old: M, new: M) {
  }
  
  public func performWithoutNotifyingObservers(_ perform: () -> Void) {
    performWithoutNotifyingObservers = true
    perform()
    performWithoutNotifyingObservers = false
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
    mode: Executor.Mode = .async(nil)
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
    mode: Executor.Mode = .async(nil),
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
    mode: Executor.Mode = .async(nil),
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
    mode: Executor.Mode = .async(nil),
    throttle: TimeInterval = 0
  ) -> Future<Void, Error> where A.AssociatedStoreType: Store<M> {
    
    let transaction = self.transaction(action: action, mode: mode)
    transaction.throttleIfNeeded(throttle)
    return transaction.run()
  }
}
