import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
import OpenCombineDispatch
#endif

/// This class is used to have read-write access to the model through `@Binding` in SwiftUI.
@dynamicMemberLookup public struct BindingProxy<M> {
  /// Associated store.
  private weak var store: Store<M>!
  
  init(store: Store<M>) {
    self.store = store
  }
  
  public subscript<T>(dynamicMember keyPath: WritableKeyPath<M, T>) -> T {
    get { store.modelStorage.model[keyPath: keyPath] }
    set { store.run(action: Assign(keyPath, newValue), mode: .mainThread) }
  }
}

#if canImport(SwiftUI)
import SwiftUI

/// Optional Coalescing for Bindings.
public func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
  Binding(
    get: { lhs.wrappedValue ?? rhs },
    set: { lhs.wrappedValue = $0 }
  )
}

extension Binding {
    
  /// When the `Binding`'s `wrappedValue` changes, the given closure is executed.
  ///
  /// - Parameter closure: Chunk of code to execute whenever the value changes.
  /// - Returns: New `Binding`.
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
