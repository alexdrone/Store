import Foundation

/// An operation associated to a specific action.
public class ActionOperation<S: ModelType, A: ActionType>: AsynchronousOperation {

  /// The operation execution block.
  public typealias ExecutionBlock = (AsynchronousOperation, A, Store<S, A>) -> Void
  public typealias FinishBlock = (Void) -> (Void)

  // Arguments.
  public let action: A
  public weak var store: Store<S, A>?

  // Executing blocks.
  public let block: ExecutionBlock
  internal var finishBlock: FinishBlock = { }

 public override func execute() {
    guard let store = store else {
      self.finish()
      return
    }
    self.block(self, self.action, store)
  }

  override public func finish() {
    self.finishBlock()
    super.finish()
  }

  public init(action: A, store: Store<S, A>, block: @escaping ExecutionBlock) {
    self.action = action
    self.store = store
    self.block = block
  }
}

/// Base class for an asynchronous operation.
/// Subclasses are expected to override the 'execute' function and call
/// the function 'finish' when they're done with their task.
public class AsynchronousOperation: Operation {

  // property overrides
  override public var isAsynchronous: Bool { return true }
  override public var isConcurrent: Bool { return true }
  override public var isExecuting: Bool { return __executing }
  override public var isFinished: Bool { return __finished }

  // __ to avoid name clashes with the superclass.
  private var __executing = false {
    willSet { willChangeValue(forKey: "isExecuting") }
    didSet { didChangeValue(forKey: "isExecuting") }
  }

  private var __finished = false {
    willSet { willChangeValue(forKey: "isFinished") }
    didSet { didChangeValue(forKey: "isFinished") }
  }

  public override func start() {
    __executing = true
    execute()
  }

  /// Subclasses are expected to override the 'execute' function and call
  /// the function 'finish' when they're done with their task.
  public dynamic func execute() {
    fatalError("Your subclass must override this")
  }

  /// This function should be called inside 'execute' when the task for this
  /// operation is completed.
  public dynamic func finish() {
    __executing = false
    __finished = true
  }
}

