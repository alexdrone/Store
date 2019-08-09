import Foundation
import Combine

/// The transaction state.
public enum TransactionState {
  case pending
  case started
  case completed
}

@available(iOS 13.0, macOS 10.15, *)
public protocol AnyTransaction: class {
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  /// - note: See `ActionType.identifier`.
  var identifier: String { get }
  /// Randomized identifier for the current transaction that preserve the temporal information.
  /// - note: see `PushID`.
  var transactionIdentifier: String { get }
  /// The threading strategy that should be used for a given transaction.
  var strategy: Dispatcher.Strategy { get }
  /// The error context for this transaction group.
  var error: Dispatcher.DispatchGroupError? { get set }
  /// Represents the progress of the transaction.
  /// Trackable `@Published` property.
  var state: TransactionState { get set }
  /// Returns the aynchronous operation that is going to be executed with this transaction.
  var operation: AsyncOperation { get }
  /// Opaque reference to the transaction store.
  var opaqueStoreRef: StoreType? { get }
  /// Dispatch strategy modifier.
  func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self
  /// - note: Performs `ActionType.perform(operation:store:error)`.
  func perform(operation: AsyncOperation)
  /// Execute the transaction.
  func run(handler: Dispatcher.TransactionCompletionHandler)
}

@available(iOS 13.0, macOS 10.15, *)
public extension AnyTransaction {
  /// This transaction will execute after all of the operations in `transactions` are completed.
  func dependOn(transactions: [AnyTransaction]) {
    transactions.map { $0.operation }.forEach { operation.addDependency($0) }
  }
}

// MARK: - ActionType

@available(iOS 13.0, macOS 10.15, *)
public protocol ActionType {
  associatedtype AssociatedStoreType: StoreType
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  var identifier: String { get }
  /// The execution body for this action.
  /// - note: Invoke `context.operation.finish` to signal task completion.
  func perform(context: TransactionContext<AssociatedStoreType, Self>)
}

@available(iOS 13.0, macOS 10.15, *)
public struct TransactionContext<S: StoreType, A: ActionType> {
  /// The operation that is currently running.
  /// - note: Invoke `context.operation.finish` to signal task completion.
  public let operation: AsyncOperation
  /// The target store for this transaction.
  public let store: S
  /// Last recorded error (or side effects) in this dispatch group.
  public let error: Dispatcher.DispatchGroupError
  /// The current transaction.
  public let transaction: Transaction<A>
}

@available(iOS 13.0, macOS 10.15, *)
public extension ActionType {
  /// Default identifier implementation.
  var identifier: String {
    return String(describing:type(of:self))
  }
}


// MARK: - Implementation

@available(iOS 13.0, macOS 10.15, *)
public final class Transaction<A: ActionType>: AnyTransaction {
  public var identifier: String {
    action.identifier
  }
  public let transactionIdentifier: String = PushID.default.make()
  public var strategy = Dispatcher.Strategy.async(nil);
  public var error: Dispatcher.DispatchGroupError?
  @Published public var state: TransactionState = .pending

  public lazy var operation: AsyncOperation = {
    let operation = TransactionOperation(transaction: self)
    operation.finishBlock = { [weak self] in
      self?.store?.notifyObservers()
      self?.state = .completed
    }
    return operation
  }()

  public var opaqueStoreRef: StoreType? {
    return store
  }

  /// The store that is going to be affected.
  public weak var store: A.AssociatedStoreType?
  /// The associated action.
  public let action: A

  init(_ action: A, in store: A.AssociatedStoreType?) {
    self.store = store
    self.action = action
  }

  public func on(_ queueWithStrategy: Dispatcher.Strategy) -> Transaction<A> {
    self.strategy = queueWithStrategy
    return self
  }

  public func perform(operation: AsyncOperation) {
    guard let store = store, let error = error else {
      print("warning: DispatchGroupError context is nil - the operation won't be executed.")
      return
    }

    let context = TransactionContext(
      operation: operation,
      store: store,
      error: error,
      transaction: self)
    action.perform(context: context)
  }

  public func run(handler: Dispatcher.TransactionCompletionHandler = nil) {
    Dispatcher.main.run(transactions: [self], handler: handler)
  }
}

@available(iOS 13.0, macOS 10.15, *)
extension Array where Element: AnyTransaction {
  /// Execute all of the transactions.
  public func run(then handler: Dispatcher.TransactionCompletionHandler = nil) {
    Dispatcher.main.run(transactions: self, handler: handler)
  }
}
