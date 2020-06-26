import Combine
import Foundation
import os.log

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

// MARK: - Protocols

/// Represents an individual execution for a given action.
public protocol AnyTransaction: class {
  
  // MARK: Properties
  
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  /// - note: See `ActionType.id`.
  var actionId: String { get }
  
  /// Randomized identifier for the current transaction that preserve the temporal information.
  /// - note: see `PushID`.
  var id: String { get }
  
  /// The execution strategy (*sync*/*aysnc*).
  var strategy: Executor.Strategy { get }
  
  /// Tracks any error that might have been raised in this transaction group.
  var error: ErrorRef? { get set }

  /// Represents the transaction execution progress.
  /// Trackable `@Published` property.
  var state: TransactionState { get set }
  
  /// Returns the asynchronous operation that is going to be executed with this transaction.
  var operation: AsyncOperation { get }
  
  // MARK: Modifiers
  
  /// The execution strategy (*sync*/*aysnc*).
  func on(_ queueWithStrategy: Executor.Strategy)
  
  /// If greater that 0, the action will only be triggered at most once during a given
  /// window of time.
  func throttleIfNeeded(_ minimumDelay: TimeInterval)
  
  // MARK: Execution
  
  /// Execute the transaction by running the associated action `reduce(context:)` function.
  /// - returns: A Future that is resolved whenever the transaction execution has completed.
  func run() -> Future<Void, Error>


  /// Execute the transaction by running the associated action `reduce(context:)` function.
  func run(handler: Executor.TransactionCompletion)
  
  /// Cancel the transaction by running the associated action `cancel(context:)` function.
  func cancel()
  
  // MARK: Internal
  
  /// Opaque reference to the transaction store.
  var opaqueStoreRef: AnyStore? { get set }
  
  /// - note: Performs `ActionType.perform(context:)`.
  func perform(operation: AsyncOperation)
}

extension AnyTransaction {
  public var transactions: [AnyTransaction] { [self] }
  
  /// This transaction will execute after all of the operations in `transactions` are completed.
  public func depend(on transactions: [AnyTransaction]) {
    transactions.map { $0.operation }.forEach { operation.addDependency($0) }
  }
}

// MARK: - Implementation

public final class Transaction<A: Action>: AnyTransaction, Identifiable {
  // AnyTransaction.
  public var actionId: String { action.id }
  public let id: String = PushID.default.make()
  public var strategy = Executor.Strategy.async(nil)
  public var error: ErrorRef?
  public var opaqueStoreRef: AnyStore? {
    set {
      guard let newValue = newValue as? A.AssociatedStoreType else { return }
      store = newValue
    }
    get { store }
  }
  
  /// Stored handler.
  private var _handler: Executor.TransactionCompletion = nil
  
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

  public func on(_ queueWithStrategy: Executor.Strategy) {
    strategy = queueWithStrategy
  }

  public func throttleIfNeeded(_ minimumDelay: TimeInterval) {
    guard minimumDelay > TimeInterval.ulpOfOne else { return  }
    Executor.main.throttle(actionId: actionId, minimumDelay: minimumDelay)
  }

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
  
  public func run() -> Future<Void, Error> {
    Future { promise in
      self.run { error in
        if let error = error {
          promise(.failure(error))
        } else {
          promise(.success(()))
        }
      }
    }
  }

  public func run(handler: Executor.TransactionCompletion = nil) {
    guard store != nil else {
      os_log(.error, log: OSLog.primary, "store is nil - the operation won't be executed.")
      return
    }
    Executor.main.run(transactions: [self], handler: handler ?? self._handler)
  }
  
  public func cancel() {
    guard let store = store, let error = error else {
      os_log(.error, log: OSLog.primary, "context/store is nil - the operation won't be cancelled.")
      return
    }
    state = .canceled
    error.error = TransactionError.canceled
    let context = TransactionContext(
      operation: operation,
      store: store,
      errorRef: error,
      transaction: self)
    action.cancel(context: context)
    context.reject(error: error.error!)
  }
}

// MARK: - Array Extensions

extension Array where Element: AnyTransaction {
  /// Execute all of the transactions.
  public func run(handler: Executor.TransactionCompletion = nil) {
    Executor.main.run(transactions: self, handler: handler)
  }
  
  /// Returns a future associated with the execution of all the transaction contained in this
  /// array.
  public func run() -> Future<Void, Error> {
    Future { promise in
      self.run { error in
        if let error = error {
          promise(.failure(error))
        } else {
          promise(.success(()))
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

// MARK: - Transaction Dispose Bag (Internal)

final class TransactionDisposeBag {
  static let shared = TransactionDisposeBag()
  
  /// All of the ongoing transactions.
  private var _ongoingTransactions: [String: AnyTransaction] = [:]
  private var _collectionLock = SpinLock()

  private init() { }
  
  func register(transaction: AnyTransaction) {
    _collectionLock.lock()
    _ongoingTransactions[transaction.id] = transaction
    _collectionLock.unlock()
  }
  
  func dispose(transaction: AnyTransaction) {
    _collectionLock.lock()
    _ongoingTransactions[transaction.id] = nil
    _collectionLock.unlock()
  }
}

// MARK: - Errors

public enum TransactionError: Error {
  /// The transaction failed because of user cancellation.
  case canceled;
}
