import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
import OpenCombineDispatch
#endif

public final class SignpostTransaction: AnyTransaction {

  public let actionId: String
  public let id: String = PushID.default.make()
  public let mode: Executor.Mode = .async(nil)
  public var error: ErrorStorage? = nil
  
  /// - note: Never set because `SignpostTransaction`s do not have a backing operation.
  public var operation: AsyncOperation {
    fatalError("This transaction does not spawn any operation.")
  }
  
  /// No associated store ref.
  public var opaqueStoreRef: AnyStore? = nil
  public var state: TransactionState = .pending

  public func on(_ queueWithStrategy: Executor.Mode) { }
  public func throttleIfNeeded(_ minimumDelay: TimeInterval) { }

  init(signpost: String) {
    self.actionId = signpost
  }

  public func perform(operation: AsyncOperation) { }
  public func run(handler: Executor.TransactionCompletion) { }
  
  public func run() -> Future<Void, Error> {
    Future { promise in promise(.success(())) }
  }

  public func cancel() { }
  
  public func eraseToAnyCancellable() -> AnyCancellable {
    AnyCancellable(self)
  }
}

// MARK: - IDs

public enum SignpostID {
  public static let prior = "SIGNPOST_PRIOR"
  public static let modelUpdate = "SIGNPOST_UPDATE"
  public static let undoRedo = "SIGNPOST_UNDO_REDO"
}
