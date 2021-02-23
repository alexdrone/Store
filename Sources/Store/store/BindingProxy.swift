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
    get { store.modelStorage[dynamicMember: keyPath] }
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

/// Bridges any binding to a `String` binding.
public func BindingAsString<T>(
  _ binding: Binding<T>,
  _ encode: @escaping (T) -> String = { "\($0)" },
  _ decode: @escaping (String) -> T
) -> Binding<String> {
  Binding(
    get: { encode(binding.wrappedValue) },
    set: { binding.wrappedValue = decode($0) }
  )
}

#endif
