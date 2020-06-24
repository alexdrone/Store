import Combine
import Foundation
import os.log

public enum TransactionError: Error {
  /// The transaction failed because of user cancellation.
  case canceled;
}

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
public protocol TransactionProtocol: class {
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  /// - note: See `ActionType.id`.
  var actionId: String { get }
  /// Randomized identifier for the current transaction that preserve the temporal information.
  /// - note: see `PushID`.
  var id: String { get }
  /// The threading strategy that should be used to dispatch this transaction.
  var strategy: Executor.Strategy { get }
  /// Tracks any error that might have been raised in this transaction group.
  var error: ErrorRef? { get set }
  /// Opaque reference to the transaction store.
  var opaqueStoreRef: AnyStoreProtocol? { get set }
  /// Represents the progress of the transaction.
  /// Trackable `@Published` property.
  var state: TransactionState { get set }
  /// Returns the asynchronous operation that is going to be executed with this transaction.
  var operation: AsyncOperation { get }
  /// Dispatch strategy modifier.
  func on(_ queueWithStrategy: Executor.Strategy)
  /// - note: Performs `ActionType.perform(context:)`.
  func perform(operation: AsyncOperation)
  /// Throttle invocation modifier.
  func throttleIfNeeded(_ minimumDelay: TimeInterval)
  /// Execute the transaction.
  func run(handler: Executor.TransactionCompletionHandler)
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
  public var strategy = Executor.Strategy.async(nil)
  /// Tracks any error that might have been raised in this transaction group.
  public var error: ErrorRef?
  /// Opaque reference to the transaction store.
  public var opaqueStoreRef: AnyStoreProtocol? {
    set {
      guard let newValue = newValue as? A.AssociatedStoreType else { return }
      store = newValue
    }
    get { store }
  }
  /// Stored handler.
  private var _handler: Executor.TransactionCompletionHandler = nil
  /// Represents the progress of the transaction.
  @Published public var state: TransactionState = .pending {
    didSet {
      store?.notifyMiddleware(transaction: self)
      switch state {
      case .canceled, .completed: TransactionDisposeBag.shared.dispose(transaction: self)
      default: break
      }
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
    TransactionDisposeBag.shared.register(transaction: self)
  }

  /// Dispatch strategy modifier.
  public func on(_ queueWithStrategy: Executor.Strategy) {
    strategy = queueWithStrategy
  }

  /// Throttle invocation modifier.
  /// - note: No-op when minimumDelay is 0.
  public func throttleIfNeeded(_ minimumDelay: TimeInterval) {
    guard minimumDelay > TimeInterval.ulpOfOne else { return  }
    Executor.main.throttle(actionId: actionId, minimumDelay: minimumDelay)
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
      errorRef: error,
      transaction: self)
    action.reduce(context: context)
  }

  /// Execute the transaction and runs the handler passed as argument.
  public func run(handler: Executor.TransactionCompletionHandler = nil) {
    guard store != nil else {
      os_log(.error, log: OSLog.primary, "store is nil - the operation won't be executed.")
      return
    }
    Executor.main.run(transactions: [self], handler: handler ?? self._handler)
  }
  
  /// Returns a future with the result coming from the execution of this transaction.
  public func run() -> Future<Transaction<A>, Error> {
    Future { promise in
      self.run { error in
        if let error = error {
          promise(.failure(error))
        } else if self.state == .canceled {
          promise(.failure(TransactionError.canceled))
        } else {
          promise(.success(self))
        }
      }
    }
  }

  /// Cancel the operation associated with this transaction.
  public func cancel() {
    guard let store = store, let error = error else {
      os_log(.error, log: OSLog.primary, "context/store is nil - the operation won't be cancelled.")
      return
    }
    state = .canceled
    let context = TransactionContext(
      operation: operation,
      store: store,
      errorRef: error,
      transaction: self)
    action.cancel(context: context)
  }
}

extension Array where Element: TransactionProtocol {
  /// Execute all of the transactions.
  public func run(handler: Executor.TransactionCompletionHandler = nil) {
    Executor.main.run(transactions: self, handler: handler)
  }
  
  /// Returns a future associated with the execution of all the transaction contained in this
  /// array.
  public func run() -> Future<Self, Error> {
    Future { promise in
      self.run { error in
        if let error = error {
          promise(.failure(error))
        } else if !self.filter({ $0.state == .canceled }).isEmpty {
          promise(.failure(TransactionError.canceled))
        } else {
          promise(.success(self))
        }
      }
    }
  }

  /// Cancels all of the transactions.
  public func cancel() {
    for transaction in self {
      transaction.cancel()
    }
  }
}

// MARK: - TransactionDisposeBag (Internal)

final class TransactionDisposeBag {
  /// Shared instance.
  static let shared = TransactionDisposeBag()
  /// All of the ongoing transactions.
  private var _ongoingTransactions: [String: TransactionProtocol] = [:]
  private var _collectionLock = SpinLock()

  private init() { }
  
  func register(transaction: TransactionProtocol) {
    _collectionLock.lock()
    _ongoingTransactions[transaction.id] = transaction
    _collectionLock.unlock()
  }
  
  func dispose(transaction: TransactionProtocol) {
    _collectionLock.lock()
    _ongoingTransactions[transaction.id] = nil
    _collectionLock.unlock()
  }
}
