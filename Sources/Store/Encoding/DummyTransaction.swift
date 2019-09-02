import Foundation
import Combine

// MARK: - SerializableUpdateModelTransaction

@available(iOS 13.0, macOS 10.15, *)
public final class SerializableUpdateModelTransaction: AnyTransaction {
  /// Every access to `SerializableStore.updateModel` without a transaction argument results in
  /// a `SERIALIZABLE_UPDATE_MODEL` transaction.
  public let actionId: String = "SERIALIZABLE_UPDATE_MODEL"
  /// Randomized identifier for the current transaction that preserve the temporal information.
  public let id: String = PushID.default.make()
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public let strategy: Dispatcher.Strategy = .async(nil)
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public var error: Dispatcher.TransactionGroupError? = nil
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public  var operation: AsyncOperation {
    fatalError("SERIALIZABLE_UPDATE_MODEL transaction does not spawn any operation.")
  }
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public var opaqueStoreRef: AnyStoreType? = nil
  /// Represents the progress of the transaction.
  public var state: TransactionState = .pending
  
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self {
    // No op.
    return self
  }

  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public func perform(operation: AsyncOperation) {
    // No op
  }

  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public func run(handler: Dispatcher.TransactionCompletionHandler) {
    // No op
  }
}
