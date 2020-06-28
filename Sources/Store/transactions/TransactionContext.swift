import Combine
import Foundation

public struct TransactionContext<S: ReducibleStore, A: Action> {
  /// The operation that is currently running.
  /// - note: Invoke `context.operation.finish` to signal task completion.
  public let operation: AsyncOperation
  /// The target store for this transaction.
  public let store: S
  /// Error internal storage.
  public var errorStorage = ErrorStorage()
  /// Last recorded error in this dispatch group.
  public var error: Error? { errorStorage.error }
  /// The current transaction.
  public let transaction: Transaction<A>
  
  /// Atomically update the store's model.
  public func reduceModel(closure: (inout S.ModelType) -> (Void)) {
    store.reduceModel(transaction: transaction, closure: closure)
  }

  /// Terminates the operation if there was an error raised by a previous action in the following
  /// transaction group.
  public func rejectOnPreviousError() -> Bool {
    guard error != nil else {
      return false
    }
    operation.finish()
    return true
  }

  /// Terminates this operation with an error.
  public func reject(error: Error) {
    self.errorStorage.error = error
    operation.finish()
  }

  /// Terminates the operation.
  public func fulfill() {
    operation.finish()
  }
}

// MARK: - errorStorage

public final class ErrorStorage {
  public var error: Error?
}
