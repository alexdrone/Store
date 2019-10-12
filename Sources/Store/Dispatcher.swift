import Foundation
import os.log

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public final class Dispatcher {
  /// The threading strategy that should be used for a given action.
  public enum Strategy {
    /// The action is dispatched asynchronously on the main thread.
    case mainThread

    /// The action is dispatched synchronously without changing context.
    case sync

    /// The action is dispatched on a serial background queue.
    case async(_ identifier: String?)
  }

  public final class TransactionGroupError {
    /// The last error logged by an operation in the current dispatch group (if applicable).
    @Atomic var lastError: Error? = nil

    /// Optional user defined map.
    @Atomic var userInfo: [String: Any] = [:]
  }

  public typealias TransactionCompletionHandler = ((TransactionGroupError) -> Void)?

  /// Shared instance.
  public static let main = Dispatcher()

  /// The background queue used for the .async mode.
  private let backgroundQueue = OperationQueue()

  /// User-defined operation queues.
  @Atomic private var queues: [String: OperationQueue] = [:]

  public func run(
    transactions: [AnyTransaction],
    handler: TransactionCompletionHandler = nil
  ) {
    let dispatchGroupError = TransactionGroupError()
    var completionOperation: Operation?
    if let completionHandler = handler {
      completionOperation
        = BlockOperation {
          completionHandler(dispatchGroupError)
        }
      transactions.map { $0.operation }.forEach { completionOperation?.addDependency($0) }
      OperationQueue.main.addOperation(completionOperation!)
    }
    for transaction in transactions {
      transaction.error = dispatchGroupError
      run(transaction: transaction)
    }
  }

  private func run(transaction: AnyTransaction) {
    let operation = transaction.operation
    switch transaction.strategy {
    case .mainThread:
      if Thread.isMainThread {
        operation.start()
        operation.waitUntilFinished()
      } else {
        OperationQueue.main.addOperation(operation)
        operation.waitUntilFinished()
      }
    case .sync:
      operation.start()
      operation.waitUntilFinished()
    case .async(let id):
      let queue = operationQueue(id: id) ?? backgroundQueue
      queue.addOperation(operation)
    }
  }

  /// Returns the queue registered with the given identifier
  /// - note: If no identifier is passed as argument, the global background queue is returned.
  public func operationQueue(id: String? = nil) -> OperationQueue? {
    guard let id = id else {
      return backgroundQueue
    }
    let queue = queues[id]
    if queue == nil {
      os_log(.error, log: OSLog.primary, " No queue registered with identifier: %s.", id)
    }
    return queue
  }

  /// Registers a new operation queue.
  public func registerOperationQueue(id: String, queue: OperationQueue) {
    _queues.mutate { $0[id] = queue }
  }

  /// Cancel all of the operations of the given queue.
  /// - note: if no identifier is passed as argument, all of the operations on the global queue
  /// will be canceled.
  public func cancelAllTransactions(queueId: String? = nil) {
    operationQueue(id: queueId)?.cancelAllOperations()
  }
}

@available(iOS 2.0, OSX 10.0, tvOS 9.0, watchOS 2.0, *)
@propertyWrapper
public struct Atomic<T> {
  let queue = DispatchQueue(label: "Atomic write access queue", attributes: .concurrent)
  var storage: T

  public init(wrappedValue value: T) {
    self.storage = value
  }

  public var wrappedValue: T {
    get { return queue.sync { storage } }
    set { queue.sync(flags: .barrier) { storage = newValue } }
  }

  /// Atomically mutate the variable (read-modify-write).
  /// - parameter action: A closure executed with atomic in-out access to the wrapped property.
  public mutating func mutate(_ mutation: (inout T) throws -> Void) rethrows {
    return try queue.sync(flags: .barrier) {
      try mutation(&storage)
    }
  }
}
