import Foundation
import os.log

// MARK: - Template Actions

/// General-purpose actions that can be applied to any store.
public struct TemplateAction {
  
  public struct AssignKeyPath<M, V>: ActionProtocol {
    public let keyPath: WritableKeyPath<M, V>
    public let value: V

    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in model[keyPath: keyPath] = value }
    }
  }
  
  public struct AssignOptionalKeyPath<M, V>: ActionProtocol {
    public let keyPath: WritableKeyPath<M, V?>
    public let value: V?

    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in model[keyPath: keyPath] = value }
    }
  }
  
  public struct FilterArrayAtKeyPath<M, V: Collection, T>: ActionProtocol where V.Element == T {
    public let keyPath: WritableKeyPath<M, V>
    public let isIncluded: (T) -> Bool
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        guard var array = model[keyPath: keyPath] as? [T] else {
          os_log(.error, log: OSLog.primary, " Arrays are the only collection type supported.")
          return
        }
        array = array.filter(isIncluded)
        // Trivial cast.
        guard let collection = array as? V else { return }
        model[keyPath: keyPath] = collection
      }
    }
  }
  
}
