import Foundation

@available(iOS 13.0, macOS 10.15, *)
public protocol MiddlewareType: class {
  /// A transaction has changed its state.
  func onTransactionStateChange(_ transaction: AnyTransaction)
}

@available(iOS 13.0, macOS 10.15, *)
public final class LoggerMiddleware: MiddlewareType {

  public func onTransactionStateChange(_ transaction: AnyTransaction) {
    let id = transaction.transactionIdentifier
    let name = transaction.identifier
    let state = String(describing: transaction.state)
    print("▩ (\(id)) \(name) ⇒ \(state)")
  }

}
