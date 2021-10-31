import Combine
import Foundation
import Logging

#if canImport(SwiftUI)
  import SwiftUI
#endif

// MARK: - Extensions

extension Store: Equatable where T: Equatable {
  public static func == (lhs: Store<T>, rhs: Store<T>) -> Bool {
    lhs.object.wrappedValue == rhs.object.wrappedValue
  }
}

extension Store: Hashable where T: Hashable {
  /// Hashes the essential components of this value by feeding them into the given hasher.
  public func hash(into hasher: inout Hasher) {
    object.wrappedValue.hash(into: &hasher)
  }
}

extension Store: Identifiable where T: Identifiable {
  /// The stable identity of the entity associated with this instance.
  public var id: T.ID { object.wrappedValue.id }
}

//MARK: - forward Publishers

extension Store where T: PropertyObservableObject {
  /// Forwards `ObservableObject.objectWillChangeSubscriber` to this proxy.
  public func forwardPropertyObservablePublisher() {
    objectSubscriptions.insert(
      object.wrappedValue.propertyDidChange.sink { [weak self] change in
        self?.propertyDidChange.send(change)
      })
  }
}

extension Store where T: ObservableObject {
  /// Forwards `ObservableObject.objectWillChangeSubscriber` to this proxy.
  public func forwardObservableObjectPublisher() {
    objectSubscriptions.insert(
      object.wrappedValue.objectWillChange.sink { [weak self] _ in
        guard let self = self else { return }
        self.objectDidChange.send()
      })
  }
}
