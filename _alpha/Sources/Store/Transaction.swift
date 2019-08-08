import Foundation
import Combine

/// The transaction state.
public enum TransactionState {
  case pending
  case started
  case completed
}

@available(iOS 13.0, *)
public protocol AnyTransaction {
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  /// - note: See `ActionType.identifier`.
  var identifier: String { get }
  /// Randomized identifier for the current transaction that preserve the temporal information.
  /// - note: see `PushID`.
  var transactionIdentifier: String { get }
  /// The threading strategy that should be used for a given transaction.
  var strategy: Dispatcher.Strategy { get }
  /// The context for this transaction group.
  var context: Dispatcher.Context? { get }
  /// Represents the progress of the transaction.
  /// Trackable `@Published` property.
  var state: TransactionState { get set }
  /// Returns the aynchronous operation that is going to be executed with this transaction.
  var operation: AsyncOperation { get }
  /// Dispatch strategy modifier.
  func withStrategy(_ strategy: Dispatcher.Strategy) -> Self
  /// - note: Performs `ActionType.perform(operation:store:error)`.
  func perform(operation: AsyncOperation)
  /// Execute the transaction.
  func run(handler: Dispatcher.TransactionCompletionHandler)
}

@available(iOS 13.0, *)
public extension AnyTransaction {
  /// This transaction will execute after all of the operations in `transactions` are completed.
  func dependOn(transactions: [AnyTransaction]) {
    transactions.map { $0.operation }.forEach { operation.addDependency($0) }
  }
}

// MARK: - ActionType

@available(iOS 13.0, *)
public protocol ActionType {
  associatedtype AssociatedStoreType: StoreType
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  var identifier: String { get }
  /// The execution body for this action.
  /// - note: Invoke `operation.finish` to signal task completion.
  func perform(
    operation: AsyncOperation,
    store: AssociatedStoreType,
    context: Dispatcher.Context)
}


// MARK: - Implementation

@available(iOS 13.0, *)
public final class Transaction<A: ActionType>: AnyTransaction {
  public var identifier: String { action.identifier }
  public let transactionIdentifier: String = PushID.default.make()
  public var strategy = Dispatcher.Strategy.async(nil);
  public var context: Dispatcher.Context?
  @Published public var state: TransactionState = .pending

  public lazy var operation: AsyncOperation = {
    let operation = TransactionOperation(transaction: self)
    operation.finishBlock = { [weak self] in
      self?.store?.notifyObservers()
      self?.state = .completed
    }
    return operation
  }()

  /// The store that is going to be affected.
  public weak var store: A.AssociatedStoreType?
  /// The associated action.
  public let action: A

  init(store: A.AssociatedStoreType?,  action: A) {
    self.store = store
    self.action = action
  }

  public func withStrategy(_ strategy: Dispatcher.Strategy) -> Transaction<A> {
    self.strategy = strategy
    return self
  }

  public func perform(operation: AsyncOperation) {
    guard let store = store, let context = context else { return }
    action.perform(operation: operation, store: store, context: context)
  }

  public func run(handler: Dispatcher.TransactionCompletionHandler = nil) {
    Dispatcher.main.run(transactions: [self], handler: handler)
  }
}

@available(iOS 13.0, *)
extension Array where Element: AnyTransaction {
  /// Execute all of the transactions.
  public func run(then handler: Dispatcher.TransactionCompletionHandler = nil) {
    Dispatcher.main.run(transactions: self, handler: handler)
  }
}
