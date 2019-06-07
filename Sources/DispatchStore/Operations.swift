import Foundation

/// An operation associated to a specific action.
@available(iOS 13.0, *)
public class ActionOperation<S: ModelType, A: ActionType>: AsynchronousOperation {
  /// The  execution block type for this operation.
  public typealias ExecutionBlock = (AsynchronousOperation, A, Store<S, A>) -> Void
  /// The completion block type for this operation.
  public typealias FinishBlock = () -> Void
  /// The associated action.
  public let action: A
  /// The store that is going to be affected.
  public weak var store: Store<S, A>?
  /// The  execution block for this operation.
  public let block: ExecutionBlock
  /// The completion block type for this operation.
  /// - note: Internal only.
  var finishBlock: FinishBlock = { }

  /// Subclasses are expected to override the ‘execute’ function and call the function ‘finish’
  /// when they’re done with their task.
  public override func execute() {
    guard let store = store else {
      finish()
      return
    }
    self.block(self, self.action, store)
  }

  /// This function should be called inside ‘execute’ when the task for this operation is completed.
  override public func finish() {
    finishBlock()
    super.finish()
  }

  /// Constructs a new action operation.
  /// - parameter action: The action associated to this operation.
  /// - parameter store: The affected store.
  /// - parameter block: The execution block.
  public init(action: A, store: Store<S, A>, block: @escaping ExecutionBlock) {
    self.action = action
    self.store = store
    self.block = block
  }
}

/// Base class for an asynchronous operation.
/// Subclasses are expected to override the 'execute' function and call
/// the function 'finish' when they're done with their task.
@available(iOS 13.0, *)
public class AsynchronousOperation: Operation {
  // Internal properties override.
  @objc dynamic override public var isAsynchronous: Bool { return true }
  @objc dynamic override public var isConcurrent: Bool { return true }
  @objc dynamic override public var isExecuting: Bool { return __executing }
  @objc dynamic override public var isFinished: Bool { return __finished }
  // __ to avoid name clashes with the superclass.
  @objc dynamic private var __executing = false {
    willSet { willChangeValue(forKey: "isExecuting") }
    didSet { didChangeValue(forKey: "isExecuting") }
  }
  // __ to avoid name clashes with the superclass.
  @objc dynamic private var __finished = false {
    willSet { willChangeValue(forKey: "isFinished") }
    didSet { didChangeValue(forKey: "isFinished") }
  }

  /// Begins the execution of the operation.
  @objc dynamic public override func start() {
    __executing = true
    execute()
  }

  /// Subclasses are expected to override the 'execute' function and call
  /// the function 'finish' when they're done with their task.
  @objc  public func execute() {
    fatalError("Your subclass must override this")
  }

  /// This function should be called inside 'execute' when the task for this
  /// operation is completed.
  @objc dynamic public func finish() {
    __executing = false
    __finished = true
  }
}

