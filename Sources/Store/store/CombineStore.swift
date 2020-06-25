import Foundation

/// Represents a type-erased reference to a `CombineStore` object.
public protocol AnyCombineStore {
  /// Reference to the parent store.
  /// This is going to be the target for the `reconcile()` function.
  var parentStore: AnyStore? { get }
  /// Reconciles the child store with the parent (if applicable).
  func reconcile()
}

/// This class is used to express a parent-child relationship between two stores.
/// This is the case when it is desired to have a store (child) to manage to a subtree of the
/// store (parent) model.
/// `CombineStore` define a merge strategy to reconcile back the changes from the child to the
/// parent.
/// e.g.
/// ```
/// struct Model { let items: [Item] }
/// let store = Store(model: Model())
/// let child = store.makeChildStore(keyPath: \.[0])
/// ```
/// This is equivalent to
/// ```
/// [...]
/// let child = Store(
///   model: items[0],
///   combine: CombineStore(parent: store, merge: .keyPath(\.[0])))
/// ```
public final class CombineStore<P, C>: AnyCombineStore {
  
  public enum MergeStrategy {
    /// The child store does not get reconciled with its parent.
    case none
    /// The child store gets reconciled with the given parent's keyPath.
    case keyPath(keyPath: WritableKeyPath<P, C>)
    /// The child store gets reconciled by running the custom closure.
    case merge(closure: (P, C) -> Void)
  }

  /// Type-erased parent store.
  public var parentStore: AnyStore? { parent }
  
  /// Whether the parent store should notify its observers when a child store merges back
  /// its values.
  public let notifyParentAfterReconciliation: Bool
  
  /// The desired merge strategy for child/parent model reconciliation.
  public let mergeStrategy: MergeStrategy
  
  // Internal.
  weak var parent: Store<P>?
  weak var child: Store<C>?
  
  /// - note: This constructor should be called only as an argument of `Store.init(model:combine)`.
  public init(parent: Store<P>, notify: Bool = false, merge: MergeStrategy = .none) {
    self.parent = parent
    self.notifyParentAfterReconciliation = notify
    self.mergeStrategy = merge
  }

  /// Reconcile the model managed by the child store with the associated parent store using
  /// the given `MergeStrategy`.
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
    if !notifyParentAfterReconciliation {
      parent?.performWithoutNotifyingObservers(perform)
    } else {
      perform()
    }
  }
}
