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
    @Atomic public var lastError: Error? = nil

    /// Optional user defined map.
    @Atomic public var userInfo: [String: Any] = [:]
  }

  public typealias TransactionCompletionHandler = ((TransactionGroupError) -> Void)?

  /// Shared instance.
  public static let main = Dispatcher()

  /// The background queue used for the .async mode.
  private let _backgroundQueue = OperationQueue()

  /// Action identifier to `Throttler` map.
  private var _throttlersToActionIdMap: [String: Throttler] = [:]

  /// User-defined operation queues.
  @Atomic private var _queues: [String: OperationQueue] = [:]

  /// Run a set of transaction concurrently.
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
      if let throttler = _throttlersToActionIdMap[transaction.actionId] {
        throttler.throttle(
          execution: { [weak self] in self?._run(transaction: transaction) },
          cancellation: {
            transaction.operation.completionBlock = nil
            transaction.operation.finish()
        })
      } else {
        _run(transaction: transaction)
      }
    }
  }

  /// Throttle an action for a specified delay time.
  public func throttle(actionId: String, minimumDelay: TimeInterval) {
    guard _throttlersToActionIdMap[actionId] == nil else {
      return
    }
    _throttlersToActionIdMap[actionId] = Throttler(minimumDelay: minimumDelay)
  }

  /// Returns the queue registered with the given identifier
  /// - note: If no identifier is passed as argument, the global background queue is returned.
  public func operationQueue(id: String? = nil) -> OperationQueue? {
    guard let id = id else {
      return _backgroundQueue
    }
    let queue = _queues[id]
    if queue == nil {
      os_log(.error, log: OSLog.primary, " No queue registered with identifier: %s.", id)
    }
    return queue
  }

  /// Registers a new operation queue.
  public func registerOperationQueue(id: String, queue: OperationQueue) {
    __queues.mutate { $0[id] = queue }
  }

  /// Cancel all of the operations of the given queue.
  /// - note: if no identifier is passed as argument, all of the operations on the global queue
  /// will be canceled.
  public func cancelAllTransactions(queueId: String? = nil) {
    operationQueue(id: queueId)?.cancelAllOperations()
  }

  private func _run(transaction: AnyTransaction) {
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
      let queue = operationQueue(id: id) ?? _backgroundQueue
      queue.addOperation(operation)
    }
  }
}

@available(iOS 2.0, OSX 10.0, tvOS 9.0, watchOS 2.0, *)
@propertyWrapper
public struct Atomic<T> {
  private let _queue = DispatchQueue(label: "Atomic write access queue", attributes: .concurrent)
  private var _storage: T

  public init(wrappedValue value: T) {
    self._storage = value
  }

  public var wrappedValue: T {
    get { return _queue.sync { _storage } }
    set { _queue.sync(flags: .barrier) { _storage = newValue } }
  }

  /// Atomically mutate the variable (read-modify-write).
  /// - parameter action: A closure executed with atomic in-out access to the wrapped property.
  public mutating func mutate(_ mutation: (inout T) throws -> Void) rethrows {
    return try _queue.sync(flags: .barrier) {
      try mutation(&_storage)
    }
  }
}
