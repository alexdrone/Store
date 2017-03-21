import Foundation

public protocol AnyAction { }

public protocol AnyState {

  /** The initial 'empty' value for this state. */
  static var initial: Self { get }
}

public protocol AnyStore {

  /** The unique identifier for this store. */
  var identifier: String { get set }

  /** Whether this 'store' comply with the action passed as argument. */
  func responds(to action: AnyAction) -> Bool

  /** Dispatches the action on the store. */
  func dispatch(action: AnyAction, mode: Dispatcher.Mode)
}

public struct StoreObserver<S: AnyState, A: AnyAction> {

  // The actual reference to the observer.
  fileprivate weak var ref: AnyObject?

  // The onChange callback that is going to be executed for this observer.
  fileprivate let closure: Store<S, A>.OnChange

  init(_ ref: AnyObject, closure: @escaping Store<S, A>.OnChange) {
    self.ref = ref
    self.closure = closure
  }
}

public final class Store<S: AnyState, A: AnyAction>: AnyStore {

  public typealias OnChange = (S, A) -> (Void)

  /** The current state for the Store. */
  public private(set) var state: S = S.initial

  /** The reducer function for this store. */
  public let reducer: Reducer<S, A>

  /** The unique identifier of the store. */
  public var identifier: String

  public init(identifier: String, reducer: Reducer<S, A>) {
    self.identifier = identifier
    self.reducer = reducer
  }

  // The main queue used for the .async mode.
  private let queue = OperationQueue()

  // The serial queue used for the .serial mode.
  private let serialQueue = OperationQueue()

  // Syncronizes the access tp the state object.
  private let stateLock = NSRecursiveLock()

  // The observers currently registered in this store.
  private var observers: [StoreObserver<S, A>] = []

  /** Adds a new observer to the store. */
  public func register(observer: AnyObject, onChange: @escaping OnChange) {
    let observer = StoreObserver<S, A>(self, closure: onChange)
    self.observers = self.observers.filter { $0.ref != nil }
    self.observers.append(observer)
  }

  /** Whether this 'store' comply with the action passed as argument. */
  public func responds(to action: AnyAction) -> Bool {
    guard let _ = action as? A else {
      return false
    }
    return true
  }

  /** Called from the reducer to update the store state. */
  public func updateState(closure: (inout S) -> (Void)) {
    self.stateLock.lock()
    closure(&self.state)
    self.stateLock.unlock()
  }

  /** Dispatch an action on this store. */
  public func dispatch(action: A, mode: Dispatcher.Mode = .serial) {
    let operation = self.reducer.operation(for: action, in: self)
    operation.finishBlock = { [weak self] in
      guard let `self` = self else {
        return
      }

      func notifyObservers() {
        // Notify the observers.
        for observer in self.observers where observer.ref != nil {
          observer.closure(self.state, action)
        }
      }

      // Makes sure the observers are notified on the main thread.
      if Thread.isMainThread {
        notifyObservers()
      } else {
        DispatchQueue.main.sync(execute: notifyObservers)
      }
    }

    switch mode {
    case .async:
      self.queue.addOperation(operation)
    case .serial:
      self.serialQueue.addOperation(operation)
    case .sync:
      operation.start()
      operation.waitUntilFinished()
    }
  }

  /** Dispatch an action on this store. */
  public func dispatch(action: AnyAction, mode: Dispatcher.Mode = .serial) {
    guard let action = action as? A else {
      return
    }
    self.dispatch(action: action, mode: mode)
  }

}

