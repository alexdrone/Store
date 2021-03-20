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
  
  associatedtype AssociatedStoreType: MutableStore
  
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  var id: String { get }
  
  /// The execution body for this action.
  /// - note: Invoke `context.operation.finish` to signal task completion.
  func mutate(context: TransactionContext<AssociatedStoreType, Self>)
  
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

// MARK: - Mutate

extension Store {
  
  /// Mutate the model with the closure passed as argument.
  public func mutate(
    id: String = _ID.mutate,
    mode: Executor.Mode = .sync,
    mutate: @escaping (inout M) -> Void
  ) {
    let action = Mutate(id: id, mutate: mutate)
    run(action: action, mode: mode)
  }
}

/// Mutate the model by using the closure passed as argument.
public struct Mutate<M>: Action {
  
  public let id: String
  public let mutate: (inout M) -> Void

  public init(id: String = _ID.mutate, mutate: @escaping (inout M) -> Void) {
    self.id = id
    self.mutate = mutate
  }
  
  public func mutate(context: TransactionContext<Store<M>, Self>) {
    defer {
      context.fulfill()
    }
    context.update(closure: mutate)
  }
  
  public func cancel(context: TransactionContext<Store<M>, Self<M, V>>) { }
}

// MARK: - Assign

extension Store {

  /// Mutate the model at the target key path passed as argument.
  public func mutate<V>(
    keyPath: WritableKeyPath<M, V>,
    value: V,
    mode: Executor.Mode = .sync
  ) {
    let action = Assign(keyPath, value)
    run(action: action, mode: mode)
  }
  
  /// Synchronously mutate the model at the target key path passed as argument.
  public func mutateSynchronous<V>(keyPath: WritableKeyPath<M, V?>, value: V?) {
    let action = Assign(keyPath, value)
    run(action: action, mode: .sync)
  }
}

/// Assigns the value passed as argument to the model's keyPath.
public struct Assign<M, V>: Action {
  
  public let id: String
  
  private let value: V?
  private let keyPath: KeyPathTarget<M, V>

  private init(_ keyPath: KeyPathTarget<M, V>, _ value: V) {
    self.id = _ID.assign
    self.keyPath = keyPath
    self.value = value
  }

  public init(_ keyPath: WritableKeyPath<M, V>, _ value: V) {
    self.id = "\(_ID.assign)[\(keyPath.readableFormat ?? "unknown")]"
    self.keyPath = .value(keyPath: keyPath)
    self.value = value
  }
  
  public init(_ keyPath: WritableKeyPath<M, V?>, _ value: V?) {
    self.id = "\(_ID.assign)[\(keyPath.readableFormat ?? "unknown")]"
    self.keyPath = .optional(keyPath: keyPath)
    self.value = value
  }
  
  public func mutate(context: TransactionContext<Store<M>, Self>) {
    defer {
      context.fulfill()
    }
    context.update { model in
      _assignKeyPath(object: &model, keyPath: keyPath, value: value)
    }
  }
  
  public func cancel(context: TransactionContext<Store<M>, Self<M, V>>) { }
}

// MARK: - Private

private enum KeyPathTarget<M, V> {

  /// A non-optional writeable keyPath.
  case value(keyPath: WritableKeyPath<M, V>)
  
  /// A optional writeable keyPath.
  case optional(keyPath: WritableKeyPath<M, V?>)
}

private func _assignKeyPath<M, V>(object: inout M, keyPath: KeyPathTarget<M, V>, value: V?) {
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
  public static let mutate = "MUTATE"
  public static let assign = "BINDING_ASSIGN"
}
