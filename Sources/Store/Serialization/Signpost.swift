import Combine
import Foundation

public enum Signpost {
  public static let prior = "__signpost_prior"
  public static let modelUpdate = "__signpost_model_update"
  public static let undoRedo = "__signpost_undo_redo"
}

// MARK: - SigPostTransaction

public final class SignpostTransaction: TransactionProtocol {
  /// See `SignpostAction`.
  public let actionId: String

  public let id: String = PushID.default.make()

  public let strategy: Dispatcher.Strategy = .async(nil)

  /// - note: Never set because `SignpostTransaction`s do not have a backing operation.
  public var error: Dispatcher.TransactionGroupError? = nil

  /// - note: Never set because `SignpostTransaction`s do not have a backing operation.
  public var operation: AsyncOperation {
    fatalError("This transaction does not spawn any operation.")
  }

  /// No associated store ref.
  public var opaqueStoreRef: AnyStoreProtocol? = nil

  /// Represents the progress of the transaction.
  public var state: TransactionState = .pending

  public func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self {
    // No op.
    return self
  }

  public func throttle(_ minimumDelay: TimeInterval) -> Self {
    // No op.
    return self
  }

  init(signpost: String) {
    self.actionId = signpost
  }

  public func perform(operation: AsyncOperation) {
    // No op.
  }

  public func run(handler: Dispatcher.TransactionCompletionHandler) {
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
