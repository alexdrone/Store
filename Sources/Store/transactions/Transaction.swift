import Combine
import Foundation
import os.log

public typealias TransactionOf = Transaction

/// Transaction state.
public enum TransactionState {
  /// The transaction is pending execution.
  case pending

  /// The transaction has started and is ongoing.
  case started

  /// The transaction is completed.
  case completed

  /// The transaction has been canceled.
  case canceled
}

/// Represents an individual execution of a given action.
public protocol TransactionProtocol: class, TransactionConvertible {
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
  var opaqueStoreRef: AnyStoreProtocol? { get set }

  /// Represents the progress of the transaction.
  /// Trackable `@Published` property.
  var state: TransactionState { get set }

  /// Returns the asynchronous operation that is going to be executed with this transaction.
  var operation: AsyncOperation { get }

  /// Dispatch strategy modifier.
  func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self

  /// - note: Performs `ActionType.perform(context:)`.
  func perform(operation: AsyncOperation)

  /// Throttle invocation modifier.
  func throttle(_ minimumDelay: TimeInterval) -> Self

  /// Execute the transaction.
  func run(handler: Dispatcher.TransactionCompletionHandler)

  /// *Optional* Used to implement custom cancellation logic for this action.
  /// E.g. Stop network transfer.
  func cancel()
}

extension TransactionProtocol {
  public var transactions: [TransactionProtocol] { [self] }
  
  /// This transaction will execute after all of the operations in `transactions` are completed.
  public func depend(on transactions: [TransactionProtocol]) {
    transactions.map { $0.operation }.forEach { operation.addDependency($0) }
  }
}

// MARK: - Implementation

public final class Transaction<A: ActionProtocol>: TransactionProtocol, Identifiable {
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  public var actionId: String { action.id }

  /// Randomized identifier for the current transaction that preserve the temporal information.
  public let id: String = PushID.default.make()

  /// The threading strategy that should be used for this transaction.
  public var strategy = Dispatcher.Strategy.async(nil)

  /// Tracks any error that might have been raised in this transaction group.
  public var error: Dispatcher.TransactionGroupError?

  /// Opaque reference to the transaction store.
  public var opaqueStoreRef: AnyStoreProtocol? {
    set {
      guard let newValue = newValue as? A.AssociatedStoreType else { return }
      store = newValue
    }
    get { store }
  }
  
  /// Stored handler.
  private var _handler: Dispatcher.TransactionCompletionHandler = nil

  /// Represents the progress of the transaction.
  @Published public var state: TransactionState = .pending {
    didSet {
      store?.notifyMiddleware(transaction: self)
    }
  }

  /// Returns the asynchronous operation that is going to be executed with this transaction.
  public lazy var operation: AsyncOperation = {
    let operation = TransactionOperation(transaction: self)
    operation._finishBlock = { [weak self] in
      self?.store?.notifyObservers()
    }
    return operation
  }()

  /// The store that is going to be affected.
  public weak var store: A.AssociatedStoreType?

  /// The action associated with this transaction.
  public let action: A

  public init(_ action: A, in store: A.AssociatedStoreType? = nil) {
    self.store = store
    self.action = action
  }

  /// Dispatch strategy modifier.
  @discardableResult
  public func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self {
    self.strategy = queueWithStrategy
    return self
  }

  /// Throttle invocation modifier.
  @discardableResult
  public func throttle(_ minimumDelay: TimeInterval) -> Self {
    Dispatcher.main.throttle(actionId: actionId, minimumDelay: minimumDelay)
    return self
  }

  /// - note: Performs `ActionType.perform(context:)`.
  public func perform(operation: AsyncOperation) {
    guard let store = store, let error = error else {
      os_log(.error, log: OSLog.primary, "context/store is nil - the operation won't be executed.")
      return
    }

    let context = TransactionContext(
      operation: operation,
      store: store,
      error: error,
      transaction: self)
    action.reduce(context: context)
  }

  public func then(handler: Dispatcher.TransactionCompletionHandler) -> Self {
    self._handler = handler
    return self
  }

  /// Execute the transaction.
  public func run(handler: Dispatcher.TransactionCompletionHandler = nil) {
    guard store != nil else {
      os_log(.error, log: OSLog.primary, "store is nil - the operation won't be executed.")
      return
    }
    Dispatcher.main.run(transactions: [self], handler: handler ?? self._handler)
  }

  public func cancel() {
    guard let store = store, let error = error else {
      os_log(.error, log: OSLog.primary, "context/store is nil - the operation won't be cancelled.")
      return
    }
    state = .canceled
    let context = TransactionContext(
      operation: operation,
      store: store,
      error: error,
      transaction: self)
    action.cancel(context: context)
  }
}

extension Array where Element: TransactionProtocol {
  /// Execute all of the transactions.
  public func run(handler: Dispatcher.TransactionCompletionHandler = nil) {
    Dispatcher.main.run(transactions: self, handler: handler)
  }

  /// Cancels all of the transactions.
  public func cancel() {
    for transaction in self {
      transaction.cancel()
    }
  }
}
