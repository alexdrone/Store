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
  var stateDemo: FetchedProperty<String, NoEtag> = .uninitalized

  struct Nested: Codable {
    var label = "Nested struct"
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
enum Action: ActionProtocol {
  case increase(amount: Int)
  case throttleIncrease(amount: Int)
  case decrease(amount: Int)
  case updateLabel(newLabel: String)
  case setArray(index: Int, value: String)

  var id: String {
    switch self {
    case .increase(_): return "increase"
    case .throttleIncrease(_): return "throttle_increase"
    case .decrease(_): return "decrease"
    case .updateLabel(_): return "update_label"
    case .setArray(_): return "set_array"
    }
  }

  func reduce(context: TransactionContext<Store<TestModel>, Self>) {
    defer {
      context.fulfill()
    }
    switch self {
    case .increase(let amount):
      context.reduceModel { $0.count += amount }
    case .throttleIncrease(let amount):
      context.reduceModel { $0.count += amount }
    case .decrease(let amount):
      context.reduceModel { $0.count -= amount }
    case .updateLabel(let newLabel):
      context.reduceModel {
        $0.label = newLabel
        $0.nested.label = newLabel
        $0.nullableLabel = nil
      }
    case .setArray(let index, let value):
      context.reduceModel {
        $0.array[index].label = value
      }
    }
  }
  
  func cancel(context: TransactionContext<Store<TestModel>, Action>) { }
}

enum TestError: Error {
  case unknown
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
struct CancellableAction: ActionProtocol {

  func reduce(context: TransactionContext<Store<TestModel>, Self>) {
    context.reduceModel { $0.stateDemo = .success(value: "Loaded", etag: noEtag) }
  }

  func cancel(context: TransactionContext<Store<TestModel>, Self>) {
    context.reduceModel { $0.stateDemo = .error(TestError.unknown) }
  }
}
