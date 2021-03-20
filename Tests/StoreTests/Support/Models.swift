import Foundation
@testable import Store

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
struct TestModel: Codable {
  struct Action { }

  var count = 0
  var label = "Foo"
  var nullableLabel: String? = "Something"
  var nested = Nested()
  var array: [Nested] = [Nested(), Nested()]

  struct Nested: Codable {
    var label = "Nested struct"
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
enum TestAction: Action {
  case increase(amount: Int)
  case increaseWithDelay(amount: Int, delay: TimeInterval)
  case throttleIncrease(amount: Int)
  case decrease(amount: Int)
  case updateLabel(newLabel: String)
  case setArray(index: Int, value: String)

  var id: String {
    switch self {
    case .increase(_): return "INCREASE"
    case .increaseWithDelay(_, _): return "INCREASE_WITH_DELAY"
    case .throttleIncrease(_): return "THROTTLE_INCREASE"
    case .decrease(_): return "DECREASE"
    case .updateLabel(_): return "UPDATE_LABEL"
    case .setArray(_, _): return "SET_ARRAY"
    }
  }

  func mutate(context: TransactionContext<Store<TestModel>, Self>) {
    switch self {
    case .increase(let amount):
      context.update { $0.count += amount }
      context.fulfill()
    case .increaseWithDelay(let amount, let delay):
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        context.update { $0.count += amount }
        context.fulfill()
      }
    case .throttleIncrease(let amount):
      context.update { $0.count += amount }
      context.fulfill()
    case .decrease(let amount):
      context.update { $0.count -= amount }
      context.fulfill()
    case .updateLabel(let newLabel):
      context.update {
        $0.label = newLabel
        $0.nested.label = newLabel
        $0.nullableLabel = nil
      }
      context.fulfill()
    case .setArray(let index, let value):
      context.update {
        $0.array[index].label = value
      }
      context.fulfill()
    }
  }
  
  func cancel(context: TransactionContext<Store<TestModel>, Self>) { }
}

enum TestError: Error {
  case unknown
}
