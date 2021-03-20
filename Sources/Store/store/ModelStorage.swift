import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
import OpenCombineDispatch
#endif

/// A reference-type storage for an immutable value-type model.
/// It provides observability and thread-safe access to the underlying model.
///
/// Abstract base class for `ModelStorage` and `ChildModelStorage`.
open class ModelStorageBase<M>: ObservableObject {
  
  /// A publisher that publishes changes from observable objects.
  public let objectWillChange = ObservableObjectPublisher()
  
  /// Read-only wrapped immutable model.
  public var model: M { fatalError() }

  /// Thread-safe access to the underlying wrapped immutable model.
  public func mutate(_ closure: (inout M) -> Void) {
    fatalError()
  }
  
  /// Returns a child model storage that points at a subtree of the immutable model wrapped by
  /// this object.
  public func makeChild<N>(keyPath: WritableKeyPath<M, N>) -> ModelStorageBase<N> {
    ChildModelStorage(parent: self, keyPath: keyPath)
  }
  
  fileprivate init() { }
  
  fileprivate var modelLock = UnfairLock()
  fileprivate var parentObjectWillChangeObserver: AnyCancellable?
}

/// Concrete implementation for `ModelStorageBase`.
public final class ModelStorage<M>: ModelStorageBase<M> {

  override public var model: M { _model }
  private var _model: M
  
  public init(model: M) {
    _model = model
    super.init()
  }

  override public func mutate(_ closure: (inout M) -> Void) {
    modelLock.lock()
    let new = assign(_model, changes: closure)
    _model = new
    modelLock.unlock()
    objectWillChange.send()
  }
}

/// Create a model storage from a `ModelStorage` model subtree defined by a key path.
/// The model for this store is shared with the parent.
public final class ChildModelStorage<P, M>: ModelStorageBase<M> {
  
  override public var model: M { parent.model[keyPath: keyPath] }

  private let parent: ModelStorageBase<P>
  private let keyPath: WritableKeyPath<P, M>
  
  public init(parent: ModelStorageBase<P>, keyPath: WritableKeyPath<P, M>) {
    self.parent = parent
    self.keyPath = keyPath
    super.init()
    parentObjectWillChangeObserver = parent.objectWillChange.sink { [weak self] in
      self?.objectWillChange.send()
    }
  }

  
  override public func mutate(_ closure: (inout M) -> Void) {
    parent.mutate { closure(&$0[keyPath: keyPath]) }
    objectWillChange.send()
  }
}

/// Whenever this object change the parent model is reconciled with the change (and will
/// subsequently emit an `objectWillChange` notification).
public final class UnownedChildModelStorage<P, M>: ModelStorageBase<M> {
  private let parent: ModelStorageBase<P>
  private let merge: (inout P, M) -> Void
  
  override public var model: M { _model }
  private var _model: M

  public init(parent: ModelStorageBase<P>, model: M, merge: @escaping (inout P, M) -> Void) {
    self.parent = parent
    self.merge = merge
    self._model = model
    super.init()
    parentObjectWillChangeObserver = parent.objectWillChange.sink { [weak self] in
      self?.objectWillChange.send()
    }
  }

  override public func mutate(_ closure: (inout M) -> Void) {
    modelLock.lock()
    let new = assign(model, changes: closure)
    _model = new
    modelLock.unlock()
    parent.mutate { [weak self] in
      guard let self = self else { return }
      self.merge(&$0, self.model)
    }
    objectWillChange.send()
  }
}
