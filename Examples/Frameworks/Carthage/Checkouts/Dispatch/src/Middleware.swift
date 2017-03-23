import Foundation

open class Middleware {

  public init() { }

  /** An action is about to be dispatched. */
  open func willDispatch(transaction: String, action: AnyAction, in store: AnyStore) { }

  /** An action just got dispatched. */
  open func didDispatch(transaction: String, action: AnyAction, in store: AnyStore) { }
}

extension Array where Element: Middleware {

  /** Propagates the 'willDispatch' callback to all of the elements. */
  func willDispatch(transaction: String, action: AnyAction, in store: AnyStore) {
    for middleware in self {
      middleware.willDispatch(transaction: transaction, action: action, in: store)
    }
  }

  /** Propagates the 'didDispatch' callback to all of the elements. */
  func didDispatch(transaction: String, action: AnyAction, in store: AnyStore) {
    for middleware in self {
      middleware.didDispatch(transaction: transaction, action: action, in: store)
    }
  }
}
