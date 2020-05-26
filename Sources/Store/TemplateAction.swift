import Foundation
import os.log

// MARK: - StdAction

/// General-purpose actions that can be applied to any store.
public struct TemplateAction {
  
  public struct Reduce<M>: ActionProtocol {
    public let reduce: (inout M) -> Void
    public var id: String = "__tmpl_mutate"
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel(closure: reduce)
    }
    
    /// Override the action identifier for increase debuggability.
    public mutating func withID(_ id: String) -> Self {
      self.id = id
      return self
    }
  }

  public struct AssignKeyPath<M, V>: ActionProtocol {
    public let keyPath: KeyPathField<M, V>
    public let value: V?
    public var id: String = "__tmpl_assign_keypath"
    
    public init(_ keyPath: KeyPathField<M, V>, _ value: V) {
      self.keyPath = keyPath
      self.value = value
    }

    public init(_ keyPath: WritableKeyPath<M, V>, _ value: V) {
      self.keyPath = .value(keyPath: keyPath)
      self.value = value
    }
    
    public init(_ keyPath: WritableKeyPath<M, V?>, _ value: V?) {
      self.keyPath = .optional(keyPath: keyPath)
      self.value = value
    }
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        _assignKeyPath(object: &model, keyPath: keyPath, value: value)
      }
    }
    
    /// Override the action identifier for increase debuggability.
    public mutating func withID(_ id: String) -> Self {
      self.id = id
      return self
    }
  }
  
  public struct Filter<M, V: Collection, T>: ActionProtocol where V.Element == T {
    public let keyPath: KeyPathField<M, V>
    public let isIncluded: (T) -> Bool
    public var id: String = "__tmpl_filter"

    
    public init(_ keyPath: KeyPathField<M, V>, _ isIncluded: @escaping (T) -> Bool) {
      self.keyPath = keyPath
      self.isIncluded = isIncluded
    }
    
    public init(_ keyPath: WritableKeyPath<M, V>, _ isIncluded: @escaping (T) -> Bool) {
      self.keyPath = .value(keyPath: keyPath)
      self.isIncluded = isIncluded
    }
    
    public init(_ keyPath: WritableKeyPath<M, V?>, _ isIncluded: @escaping (T) -> Bool) {
      self.keyPath = .optional(keyPath: keyPath)
      self.isIncluded = isIncluded
    }
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { $0 = $0.filter(isIncluded) }
      }
    }
    
    /// Override the action identifier for increase debuggability.
    public mutating func withID(_ id: String) -> Self {
      self.id = id
      return self
    }
  }
  
  public struct RemoveAtIndex<M, V: Collection, T>: ActionProtocol where V.Element == T {
    public let keyPath: KeyPathField<M, V>
    public let index: Int
    public var id: String = "__tmpl_remove_at_index"

    public init(_ keyPath: KeyPathField<M, V>, index: Int) {
      self.keyPath = keyPath
      self.index = index
    }
    
    public init(_ keyPath: WritableKeyPath<M, V>, index: Int) {
      self.keyPath = .value(keyPath: keyPath)
      self.index = index
    }
    
    public init(_ keyPath: WritableKeyPath<M, V?>, index: Int) {
      self.keyPath = .optional(keyPath: keyPath)
      self.index = index
    }
    
    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { $0.remove(at: index) }
      }
    }
    
    /// Override the action identifier for increase debuggability.
    public mutating func withID(_ id: String) -> Self {
      self.id = id
      return self
    }
  }
  
  public struct Push<M, V: Collection, T>: ActionProtocol where V.Element == T {
    public let keyPath: KeyPathField<M, V>
    public let object: T
    public var id: String = "__tmpl_push"

    public init(_ keyPath: KeyPathField<M, V>, object: T) {
      self.keyPath = keyPath
      self.object = object
    }
    
    public init(_ keyPath: WritableKeyPath<M, V>, object: T) {
      self.keyPath = .value(keyPath: keyPath)
      self.object = object
    }
    
    public init(_ keyPath: WritableKeyPath<M, V?>, object: T) {
      self.keyPath = .optional(keyPath: keyPath)
      self.object = object
    }

    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { $0.append(object) }
      }
    }
    
    /// Override the action identifier for increase debuggability.
    public mutating func withID(_ id: String) -> Self {
      self.id = id
      return self
    }
  }
  
  public struct PushFirst<M, V: Collection, T>: ActionProtocol where V.Element == T {
    public let keyPath: KeyPathField<M, V>
    public let object: T
    public var id: String = "__tmpl_push_first"

    public init(_ keyPath: KeyPathField<M, V>, object: T) {
      self.keyPath = keyPath
      self.object = object
    }
    
    public init(_ keyPath: WritableKeyPath<M, V>, object: T) {
      self.keyPath = .value(keyPath: keyPath)
      self.object = object
    }
    
    public init(_ keyPath: WritableKeyPath<M, V?>, object: T) {
      self.keyPath = .optional(keyPath: keyPath)
      self.object = object
    }

    public func reduce(context: TransactionContext<Store<M>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { model in
        _mutateArray(object: &model, keyPath: keyPath) { $0.insert(object, at: 0) }
      }
    }
    
    /// Override the action identifier for increase debuggability.
    public mutating func withID(_ id: String) -> Self {
      self.id = id
      return self
    }
  }
}

public enum KeyPathField<M, V> {
  /// A non-optional writeable keyPath.
  case value(keyPath: WritableKeyPath<M, V>)
  /// A optional writeable keyPath.
  case optional(keyPath: WritableKeyPath<M, V?>)
}

private func _mutateArray<M, V: Collection, T>(
  object: inout M,
  keyPath: KeyPathField<M, V>,
  mutate: (inout [T]) -> Void
) where V.Element == T  {
  var value: V
  switch keyPath {
  case .value(let keyPath): value = object[keyPath: keyPath]
  case .optional(let keyPath):
    guard let unwrapped = object[keyPath: keyPath] else { return }
    value = unwrapped
  }
  guard var array = value as? [T] else {
    os_log(.error, log: OSLog.primary, " Arrays are the only collection type supported.")
    return
  }
  mutate(&array)
  // Trivial cast.
  guard let collection = array as? V else { return }
  switch keyPath {
  case .value(let keyPath): object[keyPath: keyPath] = collection
  case .optional(let keyPath): object[keyPath: keyPath] = collection
  }
}

private func _assignKeyPath<M, V>(object: inout M, keyPath: KeyPathField<M, V>, value: V?) {
  switch keyPath {
  case .value(let keyPath):
    guard let value = value else { return }
    object[keyPath: keyPath] = value
  case .optional(let keyPath):
    object[keyPath: keyPath] = value
  }
}
