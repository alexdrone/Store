import Foundation
import os.log

public final class Dispatcher {
  /// Shared instance.
  public static let `default` = Dispatcher()
  /// The internal store registry.
  let registry = Registry()
  
  /// Runs an action on a registered store.
  /// - note: This is a no-op if there's no registered store with the given type/identifier.
  @discardableResult
  public func run<A: ActionProtocol, M>(
    on type: Store<M>.Type,
    id: String? = nil,
    action: A,
    mode: Executor.Strategy = .async(nil),
    throttle: TimeInterval = 0,
    handler: Executor.TransactionCompletionHandler = nil
  ) -> Transaction<A>? where A.AssociatedStoreType == Store<M> {
    let storeId = type.makeID(key: id)
    guard let store: Store<M> = registry.retrieve(id: storeId) else {
      os_log(.error, log: OSLog.primary, "No store found with id %s.", storeId)
      return nil
    }
    return store.run(action: action, mode: mode, throttle: throttle, handler: handler)
  }
  
  /// Performs a block with the desired store.
  /// - note: This is a no-op if there's no registered store with the given type/identifier.
  public func perform<M>(on type: Store<M>.Type, id: String? = nil, perform: (Store<M>) -> Void) {
    let storeId = type.makeID(key: id)
    guard let store: Store<M> = registry.retrieve(id: storeId) else {
      os_log(.error, log: OSLog.primary, "No store found with id %s.", storeId)
      return
    }
    perform(store)
  }
}

// MARK: - Internal registry.

final class Registry {
  /// Store reference wrapper.
  private struct StoreRef {
    weak var store: AnyStoreProtocol?
  }

  private var _lock = SpinLock()
  private var _stores: [String: StoreRef] = [:]
    
  func register(store: AnyStoreProtocol) {
    _lock.lock()
    _stores = _stores.filter { _, value in value.store != nil }
    _stores[store.id] = StoreRef(store: store)
    _lock.unlock()
  }
  
  func retrieve<M>(id: String) -> Store<M>? {
    var store: Store<M>? = nil
    _lock.lock()
    store = _stores[id]?.store as? Store<M>
    _lock.unlock()
    return store
  }
}
