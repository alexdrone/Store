import Foundation
import Logging
#if canImport(Combine)
import Combine
#else
import OpenCombine
import OpenCombineDispatch
#endif


/// An action represent an operation on the store.
public protocol Action: Identifiable {
  
  associatedtype AssociatedStoreType: ReducibleStore
  
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  var id: String { get }
  
  /// The execution body for this action.
  /// - note: Invoke `context.operation.finish` to signal task completion.
  func reduce(context: TransactionContext<AssociatedStoreType, Self>)
  
  /// Used to implement custom cancellation logic for this action.
  /// E.g. Stop network transfer.
  func cancel(context: TransactionContext<AssociatedStoreType, Self>)
}

extension Action {
  
  /// Default identifier implementation.
  public var id: String {
    return String(describing: type(of: self))
  }
}

// MARK: - Cancellable Property Wrapper

/// Wraps a cancellable modifiable type.
/// Useful when using cancellable pubblisher within a value-type action.
/// e.g.
/// ```
/// struct FetchTopStories: Action {
///   @CancellableRef private var cancellable = nil
///
///   func reduce(context: Context...) {
///      ...
///      cancellable =  URLSession.shared.dataTaskPublisher(for: ...).eraseToAnyPublisher()
///      ...
///   }
///
///   func cancel(context: Context...) {
///     cancellable?.cancel()
///   }
///
/// ```
@propertyWrapper public final class CancellableStorage {
    public var wrappedValue: AnyCancellable?
  
    public init(wrappedValue: AnyCancellable? = nil) {
        self.wrappedValue = wrappedValue
    }
}

/// Reduce the model by using the closure passed as argument.
public struct Reduce<M>: Action {
  public let id: String
  public let reduce: (inout M) -> Void

  public init(id: String = _ID.reduce, reduce: @escaping (inout M) -> Void) {
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

/// Assigns the value passed as argument to the model's keyPath.
public struct Assign<M, V>: Action {
  public let id: String
  public let keyPath: KeyPathArg<M, V>
  public let value: V?
  
  public init(id: String = _ID.assign, _ keyPath: KeyPathArg<M, V>, _ value: V) {
    self.id = id
    self.keyPath = keyPath
    self.value = value
  }

  public init(id: String = _ID.assign, _ keyPath: WritableKeyPath<M, V>, _ value: V) {
    self.id = "\(id)[\(keyPath.readableFormat ?? "unknown")]"
    self.keyPath = .value(keyPath: keyPath)
    self.value = value
  }
  
  public init(id: String = _ID.assign,_ keyPath: WritableKeyPath<M, V?>, _ value: V?) {
    self.id = "\(id)[\(keyPath.readableFormat ?? "unknown")]"
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

// MARK: - Internal

public enum KeyPathArg<M, V> {
  /// A non-optional writeable keyPath.
  case value(keyPath: WritableKeyPath<M, V>)
  /// A optional writeable keyPath.
  case optional(keyPath: WritableKeyPath<M, V?>)
}

// MARK: - Private

private func _assignKeyPath<M, V>(object: inout M, keyPath: KeyPathArg<M, V>, value: V?) {
  switch keyPath {
  case .value(let keyPath):
    guard let value = value else { return }
    object[keyPath: keyPath] = value
  case .optional(let keyPath):
    object[keyPath: keyPath] = value
  }
}

// MARK: - IDs

public struct _ID {
  public static let reduce = "_REDUCE"
  public static let assign = "_BINDING_ASSIGN"
}
