import Foundation
import Logging
import Combine
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Creates an observable store that acts as a proxy for the object passed as argument.
///
/// Mutations of the wrapped object performed via `get`, `set` or the dynamic keypath subscript
/// are thread-safe and trigger an event through the `objectWillChangeSubscriber` and
/// `propertyDidChangeSubscriber` streams.
@dynamicMemberLookup
@propertyWrapper
final public class Store<T>: ObservableObject, PropertyObservableObject, @unchecked Sendable {
  
  /// Emits an event whenever any of the wrapped object has been mutated.
  public var propertyDidChange = PassthroughSubject<AnyPropertyChangeEvent, Never>()
  
  /// Subsystem logger.
  public private(set) lazy var logger: Logger = {
    let type = String(describing: T.self)
    let pointer = String(format:"%02x", Unmanaged.passUnretained(self).toOpaque().hashValue)
    let label = "\(type)(\(pointer))"
    return Logger(label: label)
  }()

  /// The underlying value referenced by the binding variable.
  /// This property provides primary access to the value's data. However, you
  /// don't access `wrappedValue` directly.
  public var wrappedValue: T { object.wrappedValue }
  
  /// The wrapped object.
  var object: Binding<T>

  /// Internal subject used to propagate `objectWillChange` and `propertyDidChange` events.
  var objectDidChange = PassthroughSubject<Void, Never>()
  var objectSubscriptions = Set<AnyCancellable>()
  var subscriptions = Set<AnyCancellable>()
  
  /// Synchronize the access to the wrapped object.
  private let objectLock: Locking

  /// Constructs a new proxy for the object passed as argument.
  public init<S: Scheduler>(
    object: Binding<T>,
    objectLock: Locking = UnfairLock(),
    options: StoreOptions<S>
  ) {
    self.object = object
    self.objectLock = objectLock
    
    var objectWillChange = objectDidChange.eraseToAnyPublisher()
    let propertyDidChange = propertyDidChange.eraseToAnyPublisher()
    
    switch options.schedulingStrategy {
    case .debounce(let seconds):
      objectWillChange = objectWillChange
        .debounce(for: .seconds(seconds), scheduler: options.scheduler)
        .eraseToAnyPublisher()
    case .throttle(let seconds):
      objectWillChange = objectWillChange
        .throttle(for: .seconds(seconds), scheduler: options.scheduler, latest: true)
        .eraseToAnyPublisher()
    case .none:
      objectWillChange = objectWillChange
        .receive(on: options.scheduler)
        .eraseToAnyPublisher()
    }

    subscriptions.insert(propertyDidChange.sink { [weak self] in
      self?.objectDidChange.send()
      let property = $0.debugLabel != nil ? ".\($0.debugLabel!)" : "*"
      self?.logger.info("send { propertyDidChange(\(property)) }");
    });
    subscriptions.insert(objectWillChange.sink { [weak self] in
      self?.objectWillChange.send()
      self?.logger.info("send { objectWillChange }");
    })
  }
  
  convenience public init(
    object: Binding<T>,
    objectLock: Locking = UnfairLock()
  ) {
    self.init(
      object: object,
      objectLock: objectLock,
      options: StoreOptions(scheduler: RunLoop.main, schedulingStrategy: .none))
  }
  
  /// Notifies the subscribers for the wrapped object changes.
  private func didSetValue<V>(keyPath: KeyPath<T, V>, value: V) {
    propertyDidChange.send(AnyPropertyChangeEvent(
      object: object.wrappedValue,
      keyPath: keyPath,
      debugLabel: keyPath.readableFormat))
  }
  
  /// Read the value of the property for the wrapped object.
  public func get<V>(keyPath: KeyPath<T, V>) -> V {
    objectLock.withLock {
      object.wrappedValue[keyPath: keyPath]
    }
  }
  
  /// Sets a new value for the property at the given keypath in the wrapped object.
  public func set<V>(keyPath: WritableKeyPath<T, V>, value: V, signpost: String = #function) {
    let oldValue = objectLock.withLock { () -> V in 
      let oldValue = object.wrappedValue[keyPath: keyPath]
      object.wrappedValue[keyPath: keyPath] = value
      return oldValue
    }
    let keyPathReadableFormat = keyPath.readableFormat ?? "unknown"
    let valueChangeFormat = "\(String(describing: oldValue)) ⟶ \(value)"
    logger.info("set @ [\(signpost)] .\(keyPathReadableFormat) = { \(valueChangeFormat) }")
    didSetValue(keyPath: keyPath, value: value)
  }
  
  /// Perfom a batch update to the wrapped object.
  /// The changes applied in the `update` closure are atomic in respect of this store's
  /// wrapped object and a single `objectWillChange` event is being published after the update has
  /// been applied.
  public func performBatchUpdate(
    _ update: (inout T) async -> Void,
    signpost: String = #function
  ) async {
    await objectLock.withLock {
      await update(&object.wrappedValue)
    }
    logger.info("performBatchUpdate @ [\(signpost)]")
    objectDidChange.send()
  }
  
  /// Returns a binding to one of the properties of the wrapped object.
  /// The returned binding can itself be used as the argument for a new store object or can simply
  /// be used inside a SwiftUI view.
  public func binding<V>(keyPath: WritableKeyPath<T, V>) -> Binding<V> {
    .init(
      get: { self.get(keyPath: keyPath) },
      set: { self.set(keyPath: keyPath, value: $0) })
  }
  
  public subscript<V>(dynamicMember keyPath: KeyPath<T, V>) -> V {
    get { get(keyPath: keyPath) }
  }

  public subscript<V>(dynamicMember keyPath: WritableKeyPath<T, V>) -> V {
    get { get(keyPath: keyPath) }
    set { set(keyPath: keyPath, value: newValue, signpost: "dynamic_member") }
  }
}
