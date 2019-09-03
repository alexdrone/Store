import Foundation
import Combine

/// Transaction state.
public enum TransactionState {
  /// The transaction is pending execution.
  case pending
  /// The transaction has started and is ongoing.
  case started
  /// The transaction is completed.
  case completed
}

/// Represents an individual execution of a given action.
@available(iOS 13.0, macOS 10.15, *)
public protocol AnyTransaction: class {
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  /// - note: See `ActionType.id`.
  var actionId: String { get }
  /// Randomized identifier for the current transaction that preserve the temporal information.
  /// - note: see `PushID`.
  var id: String { get }
  /// The threading strategy that should be used to dispatch this transaction.
  var strategy: Dispatcher.Strategy { get }
  /// Tracks any error that might have been raised in this transaction group.
  var error: Dispatcher.TransactionGroupError? { get set }
  /// Opaque reference to the transaction store.
  var opaqueStoreRef: AnyStoreType? { get }
  /// Represents the progress of the transaction.
  /// Trackable `@Published` property.
  var state: TransactionState { get set }
  /// Returns the aynchronous operation that is going to be executed with this transaction.
  var operation: AsyncOperation { get }
  /// Dispatch strategy modifier.
  func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self
  /// - note: Performs `ActionType.perform(context:)`.
  func perform(operation: AsyncOperation)
  /// Execute the transaction.
  func run(handler: Dispatcher.TransactionCompletionHandler)
}

@available(iOS 13.0, macOS 10.15, *)
public extension AnyTransaction {
  /// This transaction will execute after all of the operations in `transactions` are completed.
  func depend(on transactions: [AnyTransaction]) {
    transactions.map { $0.operation }.forEach { operation.addDependency($0) }
  }
}

// MARK: - ActionType

@available(iOS 13.0, macOS 10.15, *)
public protocol ActionType: Identifiable {
  associatedtype AssociatedStoreType: StoreType
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  var id: String { get }
  /// The execution body for this action.
  /// - note: Invoke `context.operation.finish` to signal task completion.
  func perform(context: TransactionContext<AssociatedStoreType, Self>)
}

// MARK: - Implementation

@available(iOS 13.0, macOS 10.15, *)
public final class Transaction<A: ActionType>: AnyTransaction, Identifiable {
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  public var actionId: String { action.id }
  /// Randomized identifier for the current transaction that preserve the temporal information.
  public let id: String = PushID.default.make()
  /// The threading strategy that should be used for this transaction.
  public var strategy = Dispatcher.Strategy.async(nil);
  /// Tracks any error that might have been raised in this transaction group.
  public var error: Dispatcher.TransactionGroupError?
  /// Opaque reference to the transaction store.
  public var opaqueStoreRef: AnyStoreType? { return store }
  /// Represents the progress of the transaction.
  @Published public var state: TransactionState = .pending {
    didSet {
      store?.notifyMiddleware(transaction: self)
    }
  }
  /// Returns the aynchronous operation that is going to be executed with this transaction.
  public lazy var operation: AsyncOperation = {
    let operation = TransactionOperation(transaction: self)
    operation.finishBlock = { [weak self] in
      self?.store?.notifyObservers()
    }
    return operation
  }()
  /// The store that is going to be affected.
  public weak var store: A.AssociatedStoreType?
  /// The action associated with this transaction.
  public let action: A

  init(_ action: A, in store: A.AssociatedStoreType?) {
    self.store = store
    self.action = action
  }

  /// Dispatch strategy modifier.
  public func on(_ queueWithStrategy: Dispatcher.Strategy) -> Transaction<A> {
    self.strategy = queueWithStrategy
    return self
  }

  /// - note: Performs `ActionType.perform(context:)`.
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

  /// Execute the transaction.
  public func run(handler: Dispatcher.TransactionCompletionHandler = nil) {
    Dispatcher.main.run(transactions: [self], handler: handler)
  }
}

@available(iOS 13.0, macOS 10.15, *)
extension Array where Element: AnyTransaction {
  /// Execute all of the transactions.
  public func run(handler: Dispatcher.TransactionCompletionHandler = nil) {
    Dispatcher.main.run(transactions: self, handler: handler)
  }
}
