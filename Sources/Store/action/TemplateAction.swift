import Foundation
import os.log

/// General-purpose actions that can be applied to any store.
public struct TemplateAction {
  
  // MARK: - Reduce

  /// Reduce the model by using the closure passed as argument.
  public struct Reduce<M>: ActionProtocol {
    public let id: String
    public let reduce: (inout M) -> Void

    public init(id: String = _Id.reduce, reduce: @escaping (inout M) -> Void) {
      self.id = id
      self.reduce = reduce
    }
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer {
        context.fulfill()
      }
      context.reduceModel(closure: reduce)
    }
    
    public func cancel(context: TransactionContext<Store<M>, Self<M, V>>) { }
  }
  
  // MARK: - Assign

  /// Assigns the value passed as argument to the model's keyPath.
  public struct Assign<M, V>: ActionProtocol {
    public let id: String
    public let keyPath: KeyPathArg<M, V>
    public let value: V?
    
    public init(id: String = _Id.assign, _ keyPath: KeyPathArg<M, V>, _ value: V) {
      self.id = id
      self.keyPath = keyPath
      self.value = value
    }

    public init(id: String = _Id.assign, _ keyPath: WritableKeyPath<M, V>, _ value: V) {
      self.id = id
      self.keyPath = .value(keyPath: keyPath)
      self.value = value
    }
    
    public init(id: String = _Id.assign,_ keyPath: WritableKeyPath<M, V?>, _ value: V?) {
      self.id = id
      self.keyPath = .optional(keyPath: keyPath)
      self.value = value
    }
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer {
        context.fulfill()
      }
      context.reduceModel { model in
        _assignKeyPath(object: &model, keyPath: keyPath, value: value)
      }
    }
    
    public func cancel(context: TransactionContext<Store<M>, Self<M, V>>) { }
  }
  
  // MARK: - Filter
  
  // Filter the array the keyPath points at by using the given predicate.
  public struct Filter<M, V: Collection>: ActionProtocol {
    public let id: String
    public let keyPath: KeyPathArg<M, V>
    public let isIncluded: (V.Element) -> Bool

    public init(
      id: String = _Id.filter,
      _ keyPath: KeyPathArg<M, V>,
      _ isIncluded: @escaping (V.Element) -> Bool
    ) {
      self.id = id
      self.keyPath = keyPath
      self.isIncluded = isIncluded
    }
    
    public init(
      id: String = _Id.filter,
      _ keyPath: WritableKeyPath<M, V>,
      _ isIncluded: @escaping (V.Element) -> Bool
    ) {
      self.id = id
      self.keyPath = .value(keyPath: keyPath)
      self.isIncluded = isIncluded
    }
    
    public init(
      id: String = _Id.filter,
      _ keyPath: WritableKeyPath<M, V?>,
      _ isIncluded: @escaping (V.Element) -> Bool
    ) {
      self.id = id
      self.keyPath = .optional(keyPath: keyPath)
      self.isIncluded = isIncluded
    }
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer {
        context.fulfill()
      }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { $0 = $0.filter(isIncluded) }
      }
    }
    
    public func cancel(context: TransactionContext<Store<M>, Self<M, V>>) { }
  }
  
  // MARK: - Remove
  
  // Remove an element from the array the keyPath points at.
  public struct Remove<M, V: Collection>: ActionProtocol {
    public let id: String
    public let keyPath: KeyPathArg<M, V>
    public let index: Int

    public init(id: String = _Id.remove, _ keyPath: KeyPathArg<M, V>, index: Int) {
      self.id = id
      self.keyPath = keyPath
      self.index = index
    }
    
    public init(id: String = _Id.remove, _ keyPath: WritableKeyPath<M, V>, index: Int) {
      self.id = id
      self.keyPath = .value(keyPath: keyPath)
      self.index = index
    }
    
    public init(id: String = _Id.remove, _ keyPath: WritableKeyPath<M, V?>, index: Int) {
      self.id = id
      self.keyPath = .optional(keyPath: keyPath)
      self.index = index
    }
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer {
        context.fulfill()
      }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { $0.remove(at: index) }
      }
    }
    
    public func cancel(context: TransactionContext<Store<M>, Self<M, V>>) { }
  }
  
  // MARK: - Append
  
  // Append an element in the array the keyPath points at.
  public struct Append<M, V: Collection>: ActionProtocol {
    public let id: String
    public let keyPath: KeyPathArg<M, V>
    public let object: V.Element

    public init(id: String = _Id.append, _ keyPath: KeyPathArg<M, V>, object: V.Element) {
      self.id = id
      self.keyPath = keyPath
      self.object = object
    }
    
    public init(id: String = _Id.append, _ keyPath: WritableKeyPath<M, V>, object: V.Element) {
      self.id = id
      self.keyPath = .value(keyPath: keyPath)
      self.object = object
    }
    
    public init(id: String = _Id.append, _ keyPath: WritableKeyPath<M, V?>, object: V.Element) {
      self.id = id
      self.keyPath = .optional(keyPath: keyPath)
      self.object = object
    }

    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer {
        context.fulfill()
      }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { $0.append(object) }
      }
    }
    
    public func cancel(context: TransactionContext<Store<M>, Self<M, V>>) { }
  }
  
  // MARK: - Push
  
  // Push an element at index 0 in the array the keyPath points at.
  public struct Push<M, V: Collection>: ActionProtocol {
    public let id: String
    public let keyPath: KeyPathArg<M, V>
    public let object: V.Element

    public init(id: String = _Id.push, _ keyPath: KeyPathArg<M, V>, object: V.Element) {
      self.id = id
      self.keyPath = keyPath
      self.object = object
    }
    
    public init(id: String = _Id.push, _ keyPath: WritableKeyPath<M, V>, object: V.Element) {
      self.id = id
      self.keyPath = .value(keyPath: keyPath)
      self.object = object
    }
    
    public init(id: String = _Id.push, _ keyPath: WritableKeyPath<M, V?>, object: V.Element) {
      self.id = id
      self.keyPath = .optional(keyPath: keyPath)
      self.object = object
    }

    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer {
        context.fulfill()
      }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { $0.insert(object, at: 0) }
      }
    }
    
    public func cancel(context: TransactionContext<Store<M>, Self<M, V>>) { }
  }
}

// MARK: - Internal

public enum KeyPathArg<M, V> {
  /// A non-optional writeable keyPath.
  case value(keyPath: WritableKeyPath<M, V>)
  /// A optional writeable keyPath.
  case optional(keyPath: WritableKeyPath<M, V?>)
}

public struct _Id {
  public static let reduce = "__template_reduce"
  public static let assign = "__template_assign"
  public static let filter = "__template_filter"
  public static let remove = "__template_remove"
  public static let append = "__template_append"
  public static let push = "__template_push"
}

  // MARK: - Private
  
private func _mutateArray<M, V: Collection>(
  object: inout M,
  keyPath: KeyPathArg<M, V>,
  mutate: (inout [V.Element]) -> Void
) {
  var value: V
  switch keyPath {
  case .value(let keyPath): value = object[keyPath: keyPath]
  case .optional(let keyPath):
    guard let unwrapped = object[keyPath: keyPath] else { return }
    value = unwrapped
  }
  guard var array = value as? [V.Element] else {
    os_log(.error, log: OSLog.primary, " Arrays are the only collection type supported.")
    return
  }
  mutate(&array)
  switch keyPath {
  case .value(let keyPath):
    object[keyPath: keyPath] = array as! V
  case .optional(let keyPath):
    object[keyPath: keyPath] = array as? V
  }
}

private func _assignKeyPath<M, V>(object: inout M, keyPath: KeyPathArg<M, V>, value: V?) {
  switch keyPath {
  case .value(let keyPath):
    guard let value = value else { return }
    object[keyPath: keyPath] = value
  case .optional(let keyPath):
    object[keyPath: keyPath] = value
  }
}
