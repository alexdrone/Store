import Foundation
import Dispatch_macOS

// MARK: - State

struct Counter: AnyState {

  var count: Int

  static var initial: Counter {
    return Counter(count: 0)
  }

  enum Action: AnyAction {
    case increase
    case decrease
  }
}

// MARK: - Reducer

class CounterReducer: Reducer<Counter, Counter.Action> {

  override func operation(for action: Counter.Action, in store: Store<Counter, Counter.Action>)
      -> ActionOperation<Counter, Counter.Action> {
    switch action {
    case .increase:
      return ActionOperation(action: action, store: store, block: self.increase)
    case .decrease:
      return ActionOperation(action: action, store: store, block: self.decrease)
    }
  }

  private func increase(operation: AsynchronousOperation,
                        action: Counter.Action,
                        store: Store<Counter, Counter.Action>) {
    store.updateState { state in
      state.count += 1
    }
    operation.finish()
  }

  private func decrease(operation: AsynchronousOperation,
                        action: Counter.Action,
                        store: Store<Counter, Counter.Action>) {
    store.updateState { state in
      state.count -= 1
    }
    operation.finish()
  }

}

