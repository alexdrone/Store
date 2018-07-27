import Foundation

/// Logs all of the dispatched actions.
final public class LoggerMiddleware: MiddlewareType {
  // A map from transactionIds -> timestamp.
  private var queue: [String: TimeInterval] = [:]

  public init() { }

  /// An action is about to be dispatched.
  public func willDispatch(transaction: String, action: ActionType, in store: StoreType) {
    DispatchQueue.main.async {
      self.queue[transaction] = Date().timeIntervalSince1970
    }
  }

  /// An action just got dispatched.
  public func didDispatch(transaction: String, action: ActionType, in store: StoreType) {
    guard let timestamp = queue[transaction] else { return }
    DispatchQueue.main.async {
      let duration = Date().timeIntervalSince1970 - timestamp
      self.queue[transaction] = nil
      print(String(format: "▦ \(store.identifier).\(action) (%1f)ms.", arguments: [duration*1000]))
    }
  }
}
