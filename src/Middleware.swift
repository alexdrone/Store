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

public class LoggerMiddleware: Middleware {

  private var queue: [String: TimeInterval] = [:]

  /** An action is about to be dispatched. */
  open override func willDispatch(transaction: String, action: AnyAction, in store: AnyStore) {
    queue[transaction] = Date().timeIntervalSince1970
  }

  /** An action just got dispatched. */
  open override func didDispatch(transaction: String, action: AnyAction, in store: AnyStore) {
    guard let timestamp = queue[transaction] else {
      return
    }
    let duration =  Date().timeIntervalSince1970 - timestamp
    queue[transaction] = nil

    print(String(format: "▦ \(store.identifier).\(action) (%1f)ms.",
                 arguments: [duration*1000]))
  }

}
