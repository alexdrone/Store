import Foundation

public protocol AnyCombineStore {
  /// Type-erased parent store.
  var parentStore: AnyStoreProtocol? { get }
  /// Reconciles the child store with the parent (if applicable).
  func reconcile()
}

public final class CombineStore<P, C>: AnyCombineStore {
  public enum MergeStrategy {
    /// The child store does not get reconciled with its parent.
    case none
    /// The child store gets reconciled with the given parent's keyPath.
    case keyPath(keyPath: WritableKeyPath<P, C>)
    /// The child store gets reconciled using the user defined closure.
    case merge(closure: (P, C) -> Void)
  }
  weak var parent: Store<P>?
  weak var child: Store<C>?

  /// Type-erased parent store.
  public var parentStore: AnyStoreProtocol? { parent }
  /// Whether the parent store should notify its observers when a child store merges back
  /// its values.
  public let notifyParentOnChange: Bool
  /// The desired merge strategy for child/parent model reconciliation.
  public let mergeStrategy: MergeStrategy
  
  /// - note: This constructor should be called only as an argument of `Store.init(model:combine)`.
  public init(parent: Store<P>, notify: Bool = false, merge: MergeStrategy = .none) {
    self.parent = parent
    self.notifyParentOnChange = notify
    self.mergeStrategy = merge
  }

  public func reconcile() {
    func perform() {
      guard let child = child, let parent = parent else { return }
      switch mergeStrategy {
      case .none:
        return
      case .keyPath(let keyPath):
        parent.reduceModel { model in model[keyPath: keyPath] = child.model }
      case .merge(let closure):
        parent.reduceModel { model in closure(model, child.model) }
      }
    }
    if !notifyParentOnChange {
      parent?.performWithoutNotifyingObservers(perform)
    } else {
      perform()
    }
  }
}
