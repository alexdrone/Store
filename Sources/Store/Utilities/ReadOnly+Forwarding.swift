import Combine
import Foundation

extension ReadOnly where T: PropertyObservableObject {
  /// Forwards the `ObservableObject.objectWillChangeSubscriber` to this proxy object.
  public func forwardPropertyObservableObject() {
    propertyDidChangeSubscriber = wrappedValue.propertyDidChange.sink { [weak self] change in
      self?.propertyDidChange.send(change)
    }
  }
}

extension ReadOnly where T: ObservableObject {
  /// Forwards the `ObservableObject.objectWillChangeSubscriber` to this proxy object.
  public func forwardObservableObject() {
    objectWillChangeSubscriber = wrappedValue.objectWillChange.sink { [weak self] change in
      self?.objectWillChange.send()
    }
  }
}
