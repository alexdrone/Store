import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Optional Coalescing for `Binding`.
public func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
  Binding(
    get: { lhs.wrappedValue ?? rhs },
    set: { lhs.wrappedValue = $0 }
  )
}

public extension Binding {
  /// When the `Binding`'s wrapped value changes, the given closure is executed.
  func onUpdate(_ closure: @escaping () -> Void) -> Binding<Value> {
    Binding(
      get: { wrappedValue },
      set: {
        wrappedValue = $0
        closure()
      })
  }
}

#endif
