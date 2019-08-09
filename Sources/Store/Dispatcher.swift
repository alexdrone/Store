import Foundation

@available(iOS 13.0, macOS 10.15, *)
public final class Dispatcher {
  /// The threading strategy that should be used for a given action.
  public enum Strategy {
    /// The action is dispatched asynchronously on the main thread.
    case mainThread
    /// The action is dispatched synchronously on the main thread.
    case sync
    /// The action is dispatched on a serial background queue.
    case async(_ identifier: String?)
  }

  public final class DispatchGroupError {
    /// The last error logged by an operation in the current dispatch group (if applicable).
    @Atomic var lastError: Error? = nil
    /// Optional user defined map.
    @Atomic var userInfo: [String: Any] = [:]
  }

  public typealias TransactionCompletionHandler = ((DispatchGroupError) -> Void)?

  /// Shared instance.
  public static let main = Dispatcher()
  /// The background queue used for the .async mode.
  private let backgroundQueue = OperationQueue()
  /// The queue on which completion closures are run.
  private let completionHandlerQueue = OperationQueue()
  /// User-defined operation queues.
  @Atomic private var queues: [String: OperationQueue] = [:]

  public func run(
    transactions: [AnyTransaction],
    handler: TransactionCompletionHandler = nil
  ) -> Void {
    let dispatchGroupError = DispatchGroupError()
    var completionOperation: Operation?
    if let completionHandler = handler {
      completionOperation = BlockOperation {
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
    case .async(let identifier):
      let queue = operationQueue(identifier: identifier) ?? backgroundQueue
      queue.addOperation(operation)
    }
  }

  /// Returns the queue registered with the given identifier
  public func operationQueue(identifier: String? = nil) -> OperationQueue? {
    guard let identifier = identifier else {
      return backgroundQueue
    }
    let queue = queues[identifier]
    if queue == nil {
      print("warning: No queue registered with identifier \(identifier).")
    }
    return queue
  }

  /// Registers a new operation queue.
  public func registerOperationQueue(identifier: String, queue: OperationQueue) {
    _queues.mutate { $0[identifier] = queue; }
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
