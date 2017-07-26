import Foundation
import DispatchStore_macOS

// MARK: - State

struct Counter: ModelType {

  var count: Int = 0

  enum Action: ActionType {
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
      return ActionOperation(action: action, store: store) { operation, _, store in
        store.updateModel { model in model.count += 1 }
        operation.finish()
      }

    case .decrease:
      return ActionOperation(action: action, store: store) { operation, _, store in
        store.updateModel { model in model.count -= 1 }
        operation.finish()
      }
    }
  }
}

