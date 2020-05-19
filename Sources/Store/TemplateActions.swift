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
  
  public struct Filter<M, V: Collection, T>: ActionProtocol where V.Element == T {
    public let keyPath: WritableKeyPath<M, V>
    public let isIncluded: (T) -> Bool
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { array in
          array = array.filter(isIncluded)
        }
      }
    }
  }
  
  public struct RemoveAtIndex<M, V: Collection, T>: ActionProtocol where V.Element == T {
    public let keyPath: WritableKeyPath<M, V>
    public let index: Int
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { array in
          array.remove(at: index)
        }
      }
    }
  }
  
  public struct Push<M, V: Collection, T>: ActionProtocol where V.Element == T {
    public let keyPath: WritableKeyPath<M, V>
    public let object: T

    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { array in
          array.append(object)
        }
      }
    }
  }
}

private func _mutateArray<M, V: Collection, T>(
  object: inout M,
  keyPath: WritableKeyPath<M, V>,
  mutate: (inout [T]) -> Void
) where V.Element == T  {
  guard var array = object[keyPath: keyPath] as? [T] else {
    os_log(.error, log: OSLog.primary, " Arrays are the only collection type supported.")
    return
  }
  mutate(&array)
  // Trivial cast.
  guard let collection = array as? V else { return }
  object[keyPath: keyPath] = collection
}
