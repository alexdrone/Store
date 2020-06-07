import Foundation
import os.log

public final class Executor {
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
    public var lastError: Error? = nil

    /// Optional user defined map.
    public var userInfo: [String: Any] = [:]
  }

  public typealias TransactionCompletionHandler = ((TransactionGroupError) -> Void)?
  /// Shared instance.
  public static let main = Executor()
  /// The background queue used for the .async mode.
  private let _backgroundQueue = OperationQueue()
  /// Action identifier to `Throttler` map.
  private var _throttlersToActionIdMap: [String: Throttler] = [:]
  /// User-defined operation queues.
  private var _queues: [String: OperationQueue] = [:]

  /// Run a set of transaction concurrently.
  public func run(
    transactions: [TransactionProtocol],
    handler: TransactionCompletionHandler = nil
  ) {
    let dispatchGroupError = TransactionGroupError()
    var completionOperation: Operation?
    if let completionHandler = handler {
      completionOperation = BlockOperation { completionHandler(dispatchGroupError) }
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
    _queues[id] = queue
  }

  /// Cancel all of the operations of the given queue.
  /// - note: if no identifier is passed as argument, all of the operations on the global queue
  /// will be canceled.
  public func cancelAllTransactions(queueId: String? = nil) {
    operationQueue(id: queueId)?.cancelAllOperations()
  }

  private func _run(transaction: TransactionProtocol) {
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

// MARK: - Throttle

public class Throttler {
  private var _executionItem = DispatchWorkItem(block: {})
  private var _cancellationItem = DispatchWorkItem(block: {})
  private var _previousRun = Date.distantPast
  private let _queue: DispatchQueue
  private let _minimumDelay: TimeInterval

  public init(minimumDelay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
    self._minimumDelay = minimumDelay
    self._queue = queue
  }

  public func throttle(
    execution: @escaping () -> Void,
    cancellation: @escaping () -> Void = {}
  ) -> Void {
    // Cancel any existing work item if it has not yet executed
    _executionItem.cancel()
    _cancellationItem.perform()
    // Re-assign workItem with the new block task, resetting the previousRun time when it executes
    _executionItem = DispatchWorkItem() { [weak self] in
      self?._previousRun = Date()
      execution()
    }
    _cancellationItem = DispatchWorkItem() {
      cancellation()
    }
    // If the time since the previous run is more than the required minimum delay
    // { execute the workItem immediately }  else
    // { delay the workItem execution by the minimum delay time }
    let delay = _previousRun.timeIntervalSinceNow > _minimumDelay ? 0 : _minimumDelay
    _queue.asyncAfter(deadline: .now() + Double(delay), execute: _executionItem)
  }
}
