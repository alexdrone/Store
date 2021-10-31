import Foundation
import Logging

public final class Executor {
  
  public typealias TransactionCompletion = ((Error?) -> Void)?

  /// The threading strategy that should be used for a given action.
  public enum Mode {
    /// Dispatch asynchronously on the main thread.
    case mainThread
    
    /// Dispatch synchronously without changing context.
    case sync
    
    /// Dispatch on a serial background queue.
    case async(_ identifier: String?)
  }
  
  public static let main = Executor()
  
  // Private.
  
  /// The background queue used for the .async mode.
  private let backgroundQueue = OperationQueue()
  
  /// Action identifier to `Throttler` map.
  private var throttlersToActionIdMap: [String: Throttler] = [:]
  
  /// User-defined operation queues.
  private var queues: [String: OperationQueue] = [:]

  /// Run a set of transaction concurrently.
  public func run(
    transactions: [AnyTransaction],
    handler: TransactionCompletion = nil
  ) {
    let error = ErrorStorage()
    var completionOperation: Operation?
    if let completionHandler = handler {
      /// Wraps the completion handler in an operation.
      completionOperation = BlockOperation {
        completionHandler(error.error)
      }
      /// Set the completion handler as dependent from every operation.
      for operation in transactions.map(\.operation) {
        completionOperation?.addDependency(operation)
      }
      OperationQueue.main.addOperation(completionOperation!)
    }
    for transaction in transactions {
      transaction.error = error
      /// Throttles the transaction if necessary.
      if let throttler = throttlersToActionIdMap[transaction.actionId] {
        throttler.throttle(
          /// The operation execution body.
          execution: {
            [weak self] in self?._run(transaction: transaction)
          /// Performed whenever the operation is canceled.
          }, cancellation: {
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
    guard throttlersToActionIdMap[actionId] == nil else { return }
    throttlersToActionIdMap[actionId] = Throttler(minimumDelay: minimumDelay)
  }

  /// Returns the queue registered with the given identifier
  /// - note: If no identifier is passed as argument, the global background queue is returned.
  public func operationQueue(id: String? = nil) -> OperationQueue? {
    guard let id = id else { return backgroundQueue }
    let queue = queues[id]
    if queue == nil {
      logger.error("No queue registered with identifier: \(id).")
    }
    return queue
  }

  /// Registers a new operation queue.
  public func registerOperationQueue(id: String, queue: OperationQueue) {
    queues[id] = queue
  }

  /// Cancel all of the operations of the given queue.
  /// - note: if no identifier is passed as argument, all of the operations on the global queue
  /// will be canceled.
  public func cancelAllTransactions(queueId: String? = nil) {
    operationQueue(id: queueId)?.cancelAllOperations()
  }
  
  // MARK: Private

  private func _run(transaction: AnyTransaction) {
    let operation = transaction.operation
    switch transaction.mode {
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
}

// MARK: - Throttle

public class Throttler {

  private var executionItem = DispatchWorkItem(block: {})
  private var cancellationItem = DispatchWorkItem(block: {})
  private var previousRun = Date.distantPast
  private let queue: DispatchQueue
  private let minimumDelay: TimeInterval

  public init(minimumDelay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
    self.minimumDelay = minimumDelay
    self.queue = queue
  }

  public func throttle(
    execution: @escaping () -> Void,
    cancellation: @escaping () -> Void = {}
  ) -> Void {
    // Cancel any existing work item if it has not yet executed
    executionItem.cancel()
    cancellationItem.perform()
    // Re-assign workItem with the new block task, resetting the previousRun time when it executes
    executionItem = DispatchWorkItem() { [weak self] in
      self?.previousRun = Date()
      execution()
    }
    cancellationItem = DispatchWorkItem() {
      cancellation()
    }
    // If the time since the previous run is more than the required minimum delay
    // { execute the workItem immediately }  else
    // { delay the workItem execution by the minimum delay time }
    let delay = previousRun.timeIntervalSinceNow > minimumDelay ? 0 : minimumDelay
    queue.asyncAfter(deadline: .now() + Double(delay), execute: executionItem)
  }
}
