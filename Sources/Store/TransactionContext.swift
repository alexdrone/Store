import Combine
import Foundation

// MARK: - Context

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@frozen
public struct TransactionContext<S: StoreProtocol, A: ActionType> {
  /// The operation that is currently running.
  /// - note: Invoke `context.operation.finish` to signal task completion.
  public let operation: AsyncOperation

  /// The target store for this transaction.
  public let store: S

  /// Last recorded error (or side effects) in this dispatch group.
  public let error: Dispatcher.TransactionGroupError

  /// The current transaction.
  public let transaction: Transaction<A>

  /// Atomically update the store's model.
  @inlinable @inline(__always)
  public func reduceModel(closure: (inout S.ModelType) -> (Void)) {
    store.reduceModel(transaction: transaction, closure: closure)
  }

  /// Terminates the operation if there was an error raised by a previous action in the following
  /// transaction group.
  @inlinable @inline(__always)
  public func rejectOnGroupError() -> Bool {
    guard error.lastError != nil else {
      return false
    }
    operation.finish()
    return true
  }

  /// Terminates this operation with an error.
  @inlinable @inline(__always)
  public func reject(error: Error) {
    self.error.lastError = error
    operation.finish()
  }

  /// Terminates the operation.
  @inlinable @inline(__always)
  public func fulfill() {
    operation.finish()
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
extension ActionType {
  /// Default identifier implementation.
  public var id: String {
    return String(describing: type(of: self))
  }
}
