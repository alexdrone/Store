import Foundation
import Combine

public protocol PropertyObservableObject: AnyObject {
  /// A publisher that emits when an object property has changed.
  var propertyDidChange: PassthroughSubject<AnyPropertyChangeEvent, Never> { get }
}

/// Represent an object mutation.
public struct AnyPropertyChangeEvent {
  /// The proxy's wrapped value.
  public let object: Any
  
  /// The mutated keyPath.
  public let keyPath: AnyKeyPath?
  
  /// Optional debug label for this event.
  public let debugLabel: String?
  
  public init(object: Any, keyPath: AnyKeyPath? = nil, debugLabel: String? = nil) {
    self.object = object
    self.keyPath = keyPath
    self.debugLabel = debugLabel
  }
  
  /// Returns the tuple `object, value` if this property change matches the `keyPath` passed as
  /// argument.
  public func match<T, V>(keyPath: KeyPath<T, V>) -> (T, V)? {
    guard self.keyPath === keyPath, let obj = self.object as? T else {
      return nil
    }
    return (obj, obj[keyPath: keyPath])
  }
}
