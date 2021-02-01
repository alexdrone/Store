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
@dynamicMemberLookup open class ModelStorageBase<M>: ObservableObject {
  
  /// A publisher that publishes changes from observable objects.
  public let objectWillChange = ObservableObjectPublisher()
  
  /// Read-only wrapped immutable model.
  public var model: M { fatalError() }

  /// Managed acccess to the wrapped model.
  open subscript<T>(dynamicMember keyPath: WritableKeyPath<M, T>) -> T {
    fatalError()
  }
  
  /// Thread-safe access to the underlying wrapped immutable model.
  public func reduce(_ closure: (inout M) -> Void) {
    fatalError()
  }
  
  /// Returns a child model storage that points at a subtree of the immutable model wrapped by
  /// this object.
  public func makeChild<N>(keyPath: WritableKeyPath<M, N>) -> ModelStorageBase<N> {
    ChildModelStorage(parent: self, keyPath: keyPath)
  }
  
  fileprivate init() { }
  
  fileprivate var _modelLock = SpinLock()
  fileprivate var _parentObjectWillChangeObserver: AnyCancellable?
}


@dynamicMemberLookup public final class ModelStorage<M>: ModelStorageBase<M> {

  override public var model: M { _model }

  override public final subscript<T>(dynamicMember keyPath: WritableKeyPath<M, T>) -> T {
    get { _model[keyPath: keyPath] }
    set { reduce { $0[keyPath: keyPath] = newValue } }
  }
  
  private var _model: M
  
  public init(model: M) {
    _model = model
    super.init()
  }

  override public func reduce(_ closure: (inout M) -> Void) {
    _modelLock.lock()
    let new = assign(_model, changes: closure)
    _model = new
    _modelLock.unlock()
    objectWillChange.send()
  }
}

@dynamicMemberLookup public final class ChildModelStorage<P, M>: ModelStorageBase<M> {
  
  override public var model: M { _parent[dynamicMember: _keyPath] }

  private let _parent: ModelStorageBase<P>
  private let _keyPath: WritableKeyPath<P, M>
  
  public init(parent: ModelStorageBase<P>, keyPath: WritableKeyPath<P, M>) {
    _parent = parent
    _keyPath = keyPath
    super.init()
    _parentObjectWillChangeObserver = parent.objectWillChange.sink { [weak self] in
      self?.objectWillChange.send()
    }
  }
    
  override public final subscript<T>(dynamicMember keyPath: WritableKeyPath<M, T>) -> T {
    get { model[keyPath: keyPath] }
    set { reduce { $0[keyPath: keyPath] = newValue } }
  }
  
  override public func reduce(_ closure: (inout M) -> Void) {
    _parent.reduce { closure(&$0[keyPath: _keyPath]) }
    objectWillChange.send()
  }
}

@dynamicMemberLookup public final class UnownedChildModelStorage<P, M>: ModelStorageBase<M> {
  private let _parent: ModelStorageBase<P>
  private var _model: M
  private let _merge: (inout P) -> Void
  
  override public var model: M { _model }

  public init(parent: ModelStorageBase<P>, model: M, merge: @escaping (inout P) -> Void) {
    _parent = parent
    _model = model
    _merge = merge
    super.init()
    _parentObjectWillChangeObserver = parent.objectWillChange.sink { [weak self] in
      self?.objectWillChange.send()
    }
  }
  
  override public final subscript<T>(dynamicMember keyPath: WritableKeyPath<M, T>) -> T {
    get { _model[keyPath: keyPath] }
    set { reduce { $0[keyPath: keyPath] = newValue } }
  }
  
  override public func reduce(_ closure: (inout M) -> Void) {
    _modelLock.lock()
    let new = assign(_model, changes: closure)
    _model = new
    _modelLock.unlock()
    _parent.reduce(_merge)
    objectWillChange.send()
  }
}
