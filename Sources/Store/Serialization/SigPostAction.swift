import Foundation
import Combine

public enum SigPostAction: String {
  case initial = "SIGPOST_INITIAL"
  case serializableModelUpdate = "SIGPOST_SERIALIZABLE_MODEL_UPDATE"
}

// MARK: - SigPostTransaction

@available(iOS 13.0, macOS 10.15, *)
public final class SigPostTransaction: AnyTransaction {
  /// See `SigPostAction`.
  public let actionId: String
  /// Randomized identifier for the current transaction that preserve the temporal information.
  public let id: String = PushID.default.make()

  public let strategy: Dispatcher.Strategy = .async(nil)

  public var error: Dispatcher.TransactionGroupError? = nil
  /// - note: This transaction don't have an associated operation..
  public  var operation: AsyncOperation {
    fatalError("This transaction does not spawn any operation.")
  }
  /// No associated store ref.
  public var opaqueStoreRef: AnyStoreType? = nil
  /// Represents the progress of the transaction.
  public var state: TransactionState = .pending
  
  public func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self {
    // No op.
    return self
  }
  
  init(signal: SigPostAction) {
    self.actionId = signal.rawValue
  }

  public func perform(operation: AsyncOperation) {
    // No op.
  }

  public func run(handler: Dispatcher.TransactionCompletionHandler) {
    // No op.
  }
}
