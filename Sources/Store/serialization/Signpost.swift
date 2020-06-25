import Combine
import Foundation

// MARK: - SigPostTransaction

public final class SignpostTransaction: AnyTransaction {

  /// See `SignpostAction`.
  public let actionId: String
  
  public let id: String = PushID.default.make()
  public let strategy: Executor.Strategy = .async(nil)
  public var error: ErrorRef? = nil
  
  /// - note: Never set because `SignpostTransaction`s do not have a backing operation.
  public var operation: AsyncOperation {
    fatalError("This transaction does not spawn any operation.")
  }
  
  /// No associated store ref.
  public var opaqueStoreRef: AnyStore? = nil
  
  /// Represents the progress of the transaction.
  public var state: TransactionState = .pending

  public func on(_ queueWithStrategy: Executor.Strategy) { }

  public func throttleIfNeeded(_ minimumDelay: TimeInterval) { }

  init(signpost: String) {
    self.actionId = signpost
  }

  public func perform(operation: AsyncOperation) {
    // No op.
  }

  public func run(handler: Executor.TransactionCompletion) {
    // No op.
  }
  
  public func run() -> Future<Void, Error> {
    Future { promise in
      promise(.success(()))
    }
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

public enum SignpostID {
  public static let prior = "_SIGNPOST_PRIOR"
  public static let modelUpdate = "_SIGNPOST_UPDATE"
  public static let undoRedo = "_SIGNPOST_UNDO_REDO"
}
