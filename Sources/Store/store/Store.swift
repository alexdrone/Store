import Combine
import Foundation

public protocol AnyStoreProtocol: class {
  var id: String { get }
  /// In charge of reconciling this store with its parent one (if applicable).
  var combine: AnyCombineStore? { get }
  /// All of the registered middleware.
  var middleware: [Middleware] { get }
  /// Register a new middleware service.
  func register(middleware: Middleware)
  /// Unregister a middleware service.
  func unregister(middleware: Middleware)
  /// Notify the store observers for the change of this store.
  /// - note: Observers are always notified on the main thread.
  func notifyObservers()
  /// Notify all of the registered middleware services.
  /// - note: See `MiddlewareType.onTransactionStateChange`.
  func notifyMiddleware(transaction: TransactionProtocol)
  /// Recursively traverse the parents until it founds one that matches the specified model type.
  func parent<T>(type: T.Type) -> Store<T>?
  /// The execution body of this block does not trigger any notification for the Store observers.
  func performWithoutNotifyingObservers(_ perform: () -> Void)
}

public protocol StoreProtocol: AnyStoreProtocol {
  associatedtype ModelType
  /// The current state of this store.
  var model: ModelType { get }
  /// Atomically update the model.
  func reduceModel(transaction: TransactionProtocol?, closure: (inout ModelType) -> Void)
}

open class Store<M>: StoreProtocol, ObservableObject, Identifiable {
  /// The stable identity of the entity.
  public var id: String
  /// A publisher that emits before the object has changed.
  public let objectWillChange = ObservableObjectPublisher()
  /// The current state of this store.
  public private(set) var model: M
  /// All of the registered middleware.
  public var middleware: [Middleware] = []
  /// In charge of reconciling this store with its parent one (if applicable).
  public let combine: AnyCombineStore?
  
  private var _stateLock = SpinLock()
  private var _performWithoutNotifyingObservers: Bool = false
  
  public init(id: StoreID = singletonID, model: M) {
    self.id = id.id
    self.model = model
    self.combine = nil
    register(middleware: LoggerMiddleware())
  }
  
  public init<P>(id: StoreID = singletonID, model: M, combine: CombineStore<P, M>) {
    self.id = id.id
    self.model = model
    self.combine = combine
    register(middleware: LoggerMiddleware())
    combine.child = self
  }

  // MARK: Model updates

  /// Atomically update the model.
  open func reduceModel(transaction: TransactionProtocol? = nil, closure: (inout M) -> Void) {
    self._stateLock.lock()
    let old = self.model
    let new = assign(model, changes: closure)
    self.model = new
    self._stateLock.unlock()
    didUpdateModel(transaction: transaction, old: old, new: new)
  }

  /// Emits the `objectWillChange` event and propage the changes to its parent.
  /// - note: Call `super` implementation if you override this function.
  open func didUpdateModel(transaction: TransactionProtocol?, old: M, new: M) {
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

  public func notifyMiddleware(transaction: TransactionProtocol) {
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
  
  // MARK: Child/Parent Store
  
  public func makeChildStore<C>(
    id: StoreID = singletonID,
    keyPath: WritableKeyPath<M, C>
  ) -> Store<C> {
    Store<C>(id: id, model: model[keyPath: keyPath], combine: CombineStore(
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

  // MARK: Executing transactions

  @discardableResult
  public func transaction<A: ActionProtocol, M>(
    action: A,
    mode: Executor.Strategy = .async(nil)
  ) -> Transaction<A> where A.AssociatedStoreType: Store<M> {
    guard let store = self as? A.AssociatedStoreType else {
      fatalError("error: Store type mismatch.")
    }
    return Transaction<A>(action, in: store).on(mode)
  }

  @discardableResult
  public func run<A: ActionProtocol, M>(
    action: A,
    mode: Executor.Strategy = .async(nil),
    throttle: TimeInterval = 0,
    handler: Executor.TransactionCompletionHandler = nil
  ) -> Transaction<A> where A.AssociatedStoreType: Store<M> {
    let transactionObj = transaction(action: action, mode: mode)
    if throttle > TimeInterval.ulpOfOne {
      transactionObj.throttle(throttle)
    }
    transactionObj.run(handler: handler)
    return transactionObj
  }

  @discardableResult
  public func run<A: ActionProtocol, M>(
    actions: [A],
    mode: Executor.Strategy = .async(nil),
    handler: Executor.TransactionCompletionHandler = nil
  ) -> [Transaction<A>] where A.AssociatedStoreType: Store<M> {
    let transactions = actions.map { transaction(action: $0, mode: mode) }
    transactions.run(handler: handler)
    return transactions
  }
  
  /// Returns the store default identifier (applicable for singleton store)
  public static var singletonID: StoreID { StoreID.init(type: self) }
}

// MARK: - ID

public struct StoreID {
  /// The unique identifier for the store.
  public let id: String
  
  init<T>(type: T.Type, id: String = "_singleton") {
    self.id = "\(String(describing: type)):\(id)"
  }
}
