import Foundation

/// Constructs a type with all properties of T set to optional. This utility will return a type
/// that represents all subsets of a given type.
///
/// ```
/// struct Todo { var title: String; var description: String }
///
/// var partial = Partial { .success(Todo(
///   title: $0.get(\Todo.title, default: "Untitled"),
///   description: $0.get(\Todo.description, default: "No description")))
/// }
///
/// partial.title = "A Title"
/// partial.description = "A Description"
/// var todo = try! partial.build().get()
///
/// partial.description = "Another Descrition"
/// todo = partial.merge(&todo)
/// ```
///
@dynamicMemberLookup
public struct Partial<T> {
  /// The construction closure invoked by `build()`.
  public let create: (Partial<T>) -> Result<T, Error>
  
  /// All of the values currently set in this partial.
  private var keypathToValueMap: [AnyKeyPath: Any] = [:]
  
  /// All of the `set` commands that will performed once the object is built.
  private var keypathToSetValueMap: [AnyKeyPath: (inout T) -> Void] = [:]
  
  public init(_ create: @escaping (Partial<T>) -> Result<T, Error>) {
    self.create = create
  }

  /// Use `@dynamicMemberLookup` keypath subscript to store the object configuration and postpone
  /// the object construction.
  public subscript<V>(dynamicMember keyPath: KeyPath<T, V>) -> V? {
    get {
      get(keyPath)
    }
    set {
      keypathToValueMap[keyPath] = newValue
    }
  }
  /// Use `@dynamicMemberLookup` keypath subscript to store the object configuration and postpone
  /// the object construction.
  /// - note: `WritableKeyPath` properties are set on the object after construction and used
  /// by the `merge(:)` function.
  public subscript<V>(dynamicMember keyPath: WritableKeyPath<T, V>) -> V? {
    get {
      get(keyPath)
    }
    set {
      guard let value = newValue else {
        keypathToValueMap.removeValue(forKey: keyPath)
        keypathToSetValueMap.removeValue(forKey: keyPath)
        return
      }
      keypathToValueMap[keyPath] = value
      keypathToSetValueMap[keyPath] = { object in
        object[keyPath: keyPath] = value
      }
    }
  }
  
  /// Build the target object by using the `createInstanceClosure` passed to the constructor.
  public func build() -> Result<T, Error> {
    let result = create(self)
    switch result {
    case .success(var obj):
      for (_, setValueClosure) in keypathToSetValueMap {
        setValueClosure(&obj)
      }
      return result
    case .failure(_):
      return result
    }
  }
  
  /// Merge all of the properties currently set in this Partial with the destination object.
  public func merge(_ dest: inout T) -> T {
    assign(dest) {
      for (_, setValueClosure) in self.keypathToSetValueMap {
        setValueClosure(&$0)
      }
    }
  }
  
  /// Returns the value currently set for the given keyPath or an alternative default value.
  public func get<V>(_ keyPath: KeyPath<T, V>, default: V) -> V {
    guard let value = keypathToValueMap[keyPath] as? V else {
      return `default`
    }
    return value
  }
  
  /// Returns the value currently set for the given keyPath or `nil`
  public func get<V>(_ keyPath: KeyPath<T, V>) -> V? {
    guard let value = keypathToValueMap[keyPath] as? V else {
      return nil
    }
    return value
  }
}
