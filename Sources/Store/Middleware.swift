import Foundation

@available(iOS 13.0, macOS 10.15, *)
public protocol MiddlewareType {
  /// A transaction has changed its state.
  func onTransactionStateChange(_ transaction: AnyTransaction)
}
