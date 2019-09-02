import Foundation
import Combine

public enum Signal: String {
  case initial = "SIGNAL_INITIAL"
  case serializableModelUpdate = "SIGNAL_SERIALIZABLE_MODEL_UPDATE"
}

// MARK: - SignalTransaction

@available(iOS 13.0, macOS 10.15, *)
public final class SignalTransaction: AnyTransaction {
  public let actionId: String
  /// Randomized identifier for the current transaction that preserve the temporal information.
  public let id: String = PushID.default.make()
  /// - note: This transaction don't have an associated operation..
  public let strategy: Dispatcher.Strategy = .async(nil)
  /// - note: This transaction don't have an associated operation..
  public var error: Dispatcher.TransactionGroupError? = nil
  /// - note: This transaction don't have an associated operation..
  public  var operation: AsyncOperation {
    fatalError("This transaction does not spawn any operation.")
  }
  /// - note: This transaction don't have an associated operation..
  public var opaqueStoreRef: AnyStoreType? = nil
  /// Represents the progress of the transaction.
  public var state: TransactionState = .pending
  
  /// - note: This transaction don't have an associated operation..
  public func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self {
    // No op.
    return self
  }
  
  init(signal: Signal) {
    self.actionId = signal.rawValue
  }

  /// - note: This transaction don't have an associated operation..
  public func perform(operation: AsyncOperation) {
    // No op.
  }

  /// - note: This transaction don't have an associated operation..
  public func run(handler: Dispatcher.TransactionCompletionHandler) {
    // No op.
  }
}
