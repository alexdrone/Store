import Foundation

public protocol MiddlewareType {

  /** An action is about to be dispatched. */
  func willDispatch(transaction: String, action: ActionType, in store: StoreType)

  /** An action just got dispatched. */
  func didDispatch(transaction: String, action: ActionType, in store: StoreType)
}
