import Foundation

/// This function is used to copy the values of all enumerable own properties from one or more
/// source struct to a target struct.
/// - note: If the argument is a reference type the same refence is returned.
public func assign<T>(_ value: T, changes: (inout T) -> Void) -> T {
  var copy = value
  changes(&copy)
  return copy
}
