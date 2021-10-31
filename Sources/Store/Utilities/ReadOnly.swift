import Foundation
import Combine

/// Constructs a type with all properties of the given generic type `T` set to readonly,
/// meaning that the properties of the constructed type cannot be reassigned.
///
/// - note: A read-only object can propagate change events if the wrapped type ia an
/// `ObservableObject` by calling `propagateObservableObject` at construction time.
///
/// ```
/// struct Todo { var title: String; var description: String }
/// let todo = Todo(title: "A Title", description: "A Description")
/// let readOnlyTodo = ReadOnly(todo)
/// readOnlyTodo.title // "A title"
/// ```
///
@dynamicMemberLookup
@propertyWrapper
open class ReadOnly<T>: ObservableObject, PropertyObservableObject {
  public var propertyDidChange = PassthroughSubject<AnyPropertyChangeEvent, Never>()
  public private(set) var wrappedValue: T
  
  // Observable internals.
  var objectWillChangeSubscriber: Cancellable?
  var propertyDidChangeSubscriber: Cancellable?

  /// Constructs a new read-only proxy for the object passed as argument.
  init(object: T) {
    wrappedValue = object
  }
  
  public func read<V>(keyPath: KeyPath<T, V>) -> V {
    wrappedValue[keyPath: keyPath]
  }
  
  /// Use `@dynamicMemberLookup` keypath subscript to forward the value of the proxied object.
  public subscript<V>(dynamicMember keyPath: KeyPath<T, V>) -> V {
    wrappedValue[keyPath: keyPath]
  }
}

//MARK: - forward Publishers

