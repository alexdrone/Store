import Foundation

/** Logs all of the dispatched actions. */
public class LoggerMiddleware: Middleware {

  // A map from transactionIds -> timestamp.
  private var queue: [String: TimeInterval] = [:]

  /** An action is about to be dispatched. */
  open override func willDispatch(transaction: String, action: AnyAction, in store: AnyStore) {
    DispatchQueue.main.async {
      self.queue[transaction] = Date().timeIntervalSince1970
    }
  }

  /** An action just got dispatched. */
  open override func didDispatch(transaction: String, action: AnyAction, in store: AnyStore) {
    guard let timestamp = queue[transaction] else {
      return
    }
    DispatchQueue.main.async {
      let duration = Date().timeIntervalSince1970 - timestamp
      self.queue[transaction] = nil
      print(String(format: "▦ \(store.identifier).\(action) (%1f)ms.", arguments: [duration*1000]))
    }
  }
}
