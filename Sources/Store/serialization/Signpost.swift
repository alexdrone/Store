import Combine
import Foundation

// MARK: - SigPostTransaction

public final class SignpostTransaction: TransactionProtocol {
  /// See `SignpostAction`.
  public let actionId: String
  /// Randomized identifier for the current transaction that preserve the temporal information.
  public let id: String = PushID.default.make()
  /// The threading strategy that should be used to dispatch this transaction.
  public let strategy: Executor.Strategy = .async(nil)
  /// - note: Never set because `SignpostTransaction`s do not have a backing operation.
  public var error: Executor.TransactionGroupError? = nil
  /// - note: Never set because `SignpostTransaction`s do not have a backing operation.
  public var operation: AsyncOperation {
    fatalError("This transaction does not spawn any operation.")
  }
  /// No associated store ref.
  public var opaqueStoreRef: AnyStoreProtocol? = nil
  /// Represents the progress of the transaction.
  public var state: TransactionState = .pending

  public func on(_ queueWithStrategy: Executor.Strategy) -> Self { self }

  public func throttle(_ minimumDelay: TimeInterval) -> Self { self }

  init(signpost: String) {
    self.actionId = signpost
  }

  public func perform(operation: AsyncOperation) {
    // No op.
  }

  public func run(handler: Executor.TransactionCompletionHandler) {
    // No op.
  }

  public func cancel() {
    // No op.
  }

  public func pause() {
    // No op.
  }

  public func resume() {
    // No op.
  }
}

// MARK: - IDs

public enum Signpost {
  public static let prior = "_SIGNPOST_PRIOR"
  public static let modelUpdate = "_SIGNPOST_UPDATE"
  public static let undoRedo = "_SIGNPOST_UNDO_REDO"
}
