import Foundation

public typealias DispatchIdentifier = String

/// The dispatcher service is used to forward an action to the stores that responds to it.
public final class DispatchStore {
  /// The threading strategy that should be used for a given action.
  public enum Mode {
    /// The action is dispatched asynchronously on the main thread.
    case mainThread
    /// The action is dispatched synchronously on the main thread.
    case sync
    /// The action is dispatched on a serial background queue.
    case serial
    /// The action is being dispatched on a concurrent queue.
    case async
  }
  /// The global instance.
  public static let `default` = DispatchStore()
  /// All the registered stores.
  private var stores: [StoreType] = []
  /// The background queue used for the .async mode.
  private let queue = OperationQueue()
  /// The serial queue used for the .serial mode.
  private let serialQueue = OperationQueue()
  /// The collection of middleware registered in the dispatcher.
  private var middleware: [MiddlewareType] = []

  /// Store getter function.
  /// - parameter identifier: The identifier of the registered store.
  /// - returns: The store with the given identifier (or *nil* if no store matches  the identifier).
  public func store(with identifier: String) -> StoreType? {
    return stores.filter { $0.identifier == identifier }.first
  }

  /// Register a store in this *ActionDispatch* instance.
  /// - parameter store: The store that will be registered in this dispatcher.
  /// - note: If a store with the same identifier is already registered in this dispatcher,
  /// this function is a no-op.
  public func register(store: StoreType) -> StoreType {
    precondition(Thread.isMainThread)
    if let existingStore = stores.filter({ $0.identifier == store.identifier }).first {
      return existingStore
    }
    stores.append(store)
    return store
  }

  /// Unregister the store with the given identifier from this dispatcher.
  /// - parameter identifier: The identifier of the store.
  public func unregister(identifier: String) {
    precondition(Thread.isMainThread)
    stores = stores.filter { $0.identifier == identifier }
  }

  public func register(middleware: MiddlewareType) {
    precondition(Thread.isMainThread)
    self.middleware.append(middleware)
  }

  /// Dispatch an action and redirects it to the correct store.
  /// - parameter storeIdentifier: Optional, to target a specific store.
  /// - parameter action: The action that will be executed.
  /// - parameter mode: The threading strategy (default is *async*).
  /// - parameter completionBlock: Optional, completion block.
  public func dispatch(
    storeIdentifier: String? = nil,
    action: ActionType,
    mode: DispatchStore.Mode = .async,
    then completionBlock: (() -> (Void))? = nil
  ) -> Void {
    var stores = self.stores
    if let storeIdentifier = storeIdentifier {
      stores = stores.filter { $0.identifier == storeIdentifier }
    }
    for store in stores where store.responds(to: action) {
      run(action: action, mode: mode, store: store, then: completionBlock)
    }
  }

  private func run(
    action: ActionType,
    mode: DispatchStore.Mode = .serial,
    store: StoreType,
    then completionBlock: (() -> (Void))? = nil
  ) -> Void {
    // Create a transaction id for this action dispatch.
    // This is useful for the middleware to track down which action got completed.
    let transactionId = makePushID()
    // Get the operation.
    let operation = store.operation(action: action) {
      for mw in self.middleware {
        mw.didDispatch(transaction: transactionId, action: action, in: store)
      }
      // Dispatch chaining.
      if let completionBlock = completionBlock {
        DispatchQueue.main.async(execute: completionBlock)
      }
    }
    // If the store return a 'nil' operation
    guard let op = operation else { return }
    for mw in self.middleware {
      mw.willDispatch(transaction: transactionId, action: action, in: store)
    }
    // Dispatch the operation on the queue.
    switch mode {
    /// The action is dispatched synchronously on the main thread.
    case .async:
      self.queue.addOperation(op)
    /// The action is dispatched on a serial background queue.
    case .serial:
      self.serialQueue.addOperation(op)
    /// The action is dispatched synchronously on the main thread.
    case .sync:
      op.start()
      op.waitUntilFinished()
    /// The action is dispatched asynchronously on the main thread.
    case .mainThread:
      DispatchQueue.main.async {
        op.start()
        op.waitUntilFinished()
      }
    }
  }

  /// Dispatch an action on the default *ActionDispatcher* and redirects it to the correct store.
  /// - parameter storeIdentifier: Optional, to target a specific store.
  /// - parameter action: The action that will be executed.
  /// - parameter mode: The threading strategy (default is *async*).
  /// - parameter completionBlock: Optional, completion block.
  public static func dispatch(
    storeIdentifier: String? = nil,
    action: ActionType,
    mode: DispatchStore.Mode = .async,
    then completionBlock: (() -> (Void))? = nil
  ) -> Void {
    DispatchStore.default.dispatch(
      storeIdentifier: storeIdentifier,
      action: action,
      mode: mode,
      then: completionBlock)
  }

  /// Dispatch a sequence of actions on the default *ActionDispatcher* and redirects
  /// it to the correct store.
  /// - parameter storeIdentifier: Optional, to target a specific store.
  /// - parameter actions: The actions that will be executed sequentially.
  /// - parameter completionBlock: Optional, completion block.
  public static func dispatch(
    storeIdentifier: String? = nil,
    actions: [ActionType],
    then completionBlock: (() -> (Void))? = nil
  ) -> Void {
    guard let action = actions.first else {
      completionBlock?()
      return
    }
    var newActions = actions
    newActions.remove(at: 0)
    dispatch(storeIdentifier: storeIdentifier, action: action) {
      dispatch(storeIdentifier: storeIdentifier, actions: newActions, then: completionBlock)
    }
  }

  /// Register a store to the default *ActionDispatcher*
  public static func register(store: StoreType) -> StoreType {
    return DispatchStore.default.register(store: store)
  }
}


