import Foundation

public protocol StateType {
  init()
}

public protocol StoreType: class {

  /** The unique identifier for this store. */
  var identifier: String { get set }

  /** The current store value. */
  var stateValue: StateType { get }

  /** Whether this 'store' comply with the action passed as argument. */
  func responds(to action: ActionType) -> Bool

  /** Dispatches the action on the store. */
  func dispatchOperation(action: ActionType, completion: ((Void) -> (Void))?) -> Operation?

  /** Tries to inject the state passed as argument in the store. */
  func inject(state: StateType, action: ActionType)
}

public struct StoreObserver<S: StateType, A: ActionType> {

  // The actual reference to the observer.
  fileprivate weak var ref: AnyObject?

  // The onChange callback that is going to be executed for this observer.
  fileprivate let closure: Store<S, A>.OnChange

  init(_ ref: AnyObject, closure: @escaping Store<S, A>.OnChange) {
    self.ref = ref
    self.closure = closure
  }
}

public final class Store<S: StateType, A: ActionType>: StoreType {

  public typealias OnChange = (S, Action<A>) -> (Void)

  /** The current state for the Store. */
  public private(set) var state: S = S()
  public var stateValue: StateType {
    return self.state
  }

  /** The reducer function for this store. */
  public let reducer: Reducer<S, A>

  /** The unique identifier of the store. */
  public var identifier: String

  public init(identifier: String, reducer: Reducer<S, A>) {
    self.identifier = identifier
    self.reducer = reducer
  }

  // Syncronizes the access tp the state object.
  private let stateLock = NSRecursiveLock()

  // The observers currently registered in this store.
  private var observers: [StoreObserver<S, A>] = []

  /** Adds a new observer to the store. */
  public func register(observer: AnyObject, onChange: @escaping OnChange) {
    precondition(Thread.isMainThread)
    let observer = StoreObserver<S, A>(self, closure: onChange)
    self.observers = self.observers.filter { $0.ref != nil }
    self.observers.append(observer)
  }

  public func unregister(observer: AnyObject) {
    precondition(Thread.isMainThread)
    self.observers = self.observers.filter { $0.ref != nil && $0.ref !== observer }
  }

  /** Whether this 'store' comply with the action passed as argument. */
  public func responds(to action: ActionType) -> Bool {
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

  /** Notify the store observers for the change of this store. */
  public func notifyObservers(action: Action<A>) {
    func notify() {
      for observer in self.observers where observer.ref != nil {
        observer.closure(self.state, action)
      }
    }
    // Makes sure the observers are notified on the main thread.
    if Thread.isMainThread {
      notify()
    } else {
      DispatchQueue.main.sync(execute: notify)
    }
  }

  /** Tries to inject the state passed as argument in the store. */
  public func inject(state: StateType, action: ActionType) {
    guard let state = state as? S, let action = action as? A else {
      return
    }
    self.updateState { _ in
      self.state = state
      let action = Action(action: action,
                          state: .finished,
                          lastRun: Date().timeIntervalSince1970,
                          userInfo: [:])
      self.notifyObservers(action: action)
    }
  }

  /** Package the operation returned from the 'Reducer'. */
  public func dispatchOperation(action: ActionType,
                                completion: ((Void) -> (Void))? = nil) -> Operation? {
    guard let action = action as? A else {
      return nil
    }

    // Retrieve the operation from the 'Reducer'.
    let operation = self.reducer.operation(for: action, in: self)
    let shouldNotifyObservers = self.reducer.shouldNotifyObservers(for: action, in: self)

    operation.finishBlock = { [weak self] in
      guard let `self` = self else {
        return
      }
      if shouldNotifyObservers {
        let action = Action(action: action,
                            state: .finished,
                            lastRun: Date().timeIntervalSince1970,
                            userInfo: [:])
        self.notifyObservers(action: action)
      }

      // Run the completion provided from the 'Dispatcher'.
      completion?()
    }
    return operation
  }

}

