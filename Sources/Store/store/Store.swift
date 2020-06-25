import Combine
import Foundation

public protocol AnyStoreProtocol: class {
  var id: String { get }
  /// In charge of reconciling this store with its parent (if applicable).
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
  public private(set) var id: String
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
  
  public init(id: ModelKey = nil, model: M) {
    self.id = Self.makeID(key: id)
    self.model = model
    self.combine = nil
    register(middleware: LoggerMiddleware())
    Dispatcher.default.registry.register(store: self)
  }
  
  public init<P>(id: ModelKey = nil, model: M, combine: CombineStore<P, M>) {
    self.id = Self.makeID(key: id)
    self.model = model
    self.combine = combine
    register(middleware: LoggerMiddleware())
    combine.child = self
    Dispatcher.default.registry.register(store: self)
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
    id: ModelKey = nil,
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

  // MARK: Constructing transactions

  @discardableResult
  public func transaction<A: ActionProtocol, M>(
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
  
  // MARK: Executing transactions

  @discardableResult
  public func run<A: ActionProtocol, M>(
    action: A,
    mode: Executor.Strategy = .async(nil),
    throttle: TimeInterval = 0,
    handler: Executor.TransactionCompletionHandler = nil
  ) -> Transaction<A> where A.AssociatedStoreType: Store<M> {
    let transaction = self.transaction(action: action, mode: mode)
    transaction.throttleIfNeeded(throttle)
    transaction.run(handler: handler)
    return transaction
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
  
  // MARK: Executing transactions (Futures)
  
  public func future<A: ActionProtocol, M>(
    action: A,
    mode: Executor.Strategy = .async(nil),
    throttle: TimeInterval = 0
  ) -> Future<Transaction<A>, Error> where A.AssociatedStoreType: Store<M> {
    let transaction = self.transaction(action: action, mode: mode)
    transaction.throttleIfNeeded(throttle)
    return transaction.future()
  }

  // MARK: ID
  
  /// Make a new store unique identifier.
  /// - parameter key: Optional store key, useful when your store type is not unique.
  /// - note: The store is prefixed with the model type.
  public static func makeID(key: ModelKey) -> String {
    let type = String(describing: M.self)
    return key != nil ? type + ":" + key!.description : type
  }
}

public typealias ModelKey = CustomStringConvertible?
