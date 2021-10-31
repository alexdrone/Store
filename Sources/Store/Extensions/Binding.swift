import Combine
import Foundation
import Logging

#if canImport(SwiftUI)
  import SwiftUI
#else

  @propertyWrapper
  @dynamicMemberLookup
  public struct Binding<Value> {
    public var wrappedValue: Value {
      get { get() }
      nonmutating set { set(newValue, transaction) }
    }
    public var transaction = Transaction()

    private let get: () -> Value
    private let set: (Value, Transaction) -> Void

    public var projectedValue: Binding<Value> { self }

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
      self.get = get
      self.set = { v, _ in set(v) }
    }

    public init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) {
      self.transaction = .init()
      self.get = get
      self.set = {
        set($0, $1)
      }
    }

    public static func constant(_ value: Value) -> Binding<Value> {
      .init(get: { value }, set: { _ in })
    }

    public subscript<Subject>(
      dynamicMember keyPath: WritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
      .init(
        get: { wrappedValue[keyPath: keyPath] },
        set: { wrappedValue[keyPath: keyPath] = $0 })
    }

    public func transaction(_ transaction: Transaction) -> Binding<Value> {
      fatalError()
    }
  }

  public struct Transaction {}

#endif

//MARK: - Extensions

/// Optional Coalescing for `Binding`.
public func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
  Binding(
    get: { lhs.wrappedValue ?? rhs },
    set: { lhs.wrappedValue = $0 }
  )
}

extension Binding {
  /// When the `Binding`'s wrapped value changes, the given closure is executed.
  public func onUpdate(_ closure: @escaping () -> Void) -> Binding<Value> {
    Binding(
      get: { wrappedValue },
      set: {
        wrappedValue = $0
        closure()
      })
  }
}
