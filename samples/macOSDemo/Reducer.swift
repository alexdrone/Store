import Foundation
import DispatchStore

// MARK: - Model

struct Counter: ModelType {
  /// The current count.
  var count: Int = 0
  enum Action: ActionType {
    /// Increases the counter by one unit.
    case increase
    /// Decreases the counter by one unit.
    case decrease
  }
}

// MARK: - Reducer

class CounterReducer: Reducer<Counter, Counter.Action> {
  /// This method should return the operation for the action passed as argument.
  /// You can chain several operations together by defining dependencies between them.
  /// Remember to call ‘operation.finish’ when an operation is finished.
  override func operation(for action: Counter.Action, in store: Store<Counter, Counter.Action>
  ) -> ActionOperation<Counter, Counter.Action> {

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

