import Foundation

public typealias DispatchIdentifier = String

public final class Dispatcher {

  public enum Mode {
    case sync
    case serial
    case async
  }

  public static let `default` = Dispatcher()

  /** All the registered stores. */
  private var stores: [AnyStore] = []

  private var middleware: [Middleware] = []

  /** Returns the store with the given identifier. */
  public func store(with identifier: String) -> AnyStore? {
    return self.stores.filter { $0.identifier == identifier }.first
  }

  public func register(store: AnyStore) {
    precondition(Thread.isMainThread)
    self.stores.append(store)
  }

  public func unregister(identifier: String) {
    precondition(Thread.isMainThread)
    self.stores = self.stores.filter { $0.identifier == identifier }
  }

  public func register(middleware: Middleware) {
    precondition(Thread.isMainThread)
    self.middleware.append(middleware)
  }

  /** Dispatch an action and redirects it to the correct store. */
  public func dispatch<A: AnyAction>(storeIdentifier: String? = nil,
                                     action: A,
                                     mode: Dispatcher.Mode = .serial) {
    var stores = self.stores
    if let storeIdentifier = storeIdentifier {
      stores = self.stores.filter { $0.identifier == storeIdentifier }
    }
    for store in stores where store.responds(to: action) {

      // The unique identifier for this dispatch transaction.
      let transactionId = NSUUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")

      self.middleware.willDispatch(transaction: transactionId, action: action, in: store)
      store.dispatch(action: action, mode: mode) {
        self.middleware.didDispatch(transaction: transactionId, action: action, in: store)
      }
    }
  }
}


