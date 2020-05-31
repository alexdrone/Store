import Foundation

#if canImport(SwiftProtobuf)
import SwiftProtobuf

public extension SwiftProtobuf.Message {
  /// Configure the proto with the closure body passed as argument.
  func set(_ closure: (inout Self) -> Void) -> Self {
    var new = self
    closure(&new)
    return new
  }

  /// Set the protobuf property for the given keypath.
  func set<V>(_ keyPath: WritableKeyPath<Self, V>, _ value: V) -> Self {
    var new = self
    new[keyPath: keyPath] = value
    return new
  }
}

public extension SwiftProtobuf.Message where Self: ActionProtocol {
  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  var id: String { Self.protoMessageName }
}

#endif
