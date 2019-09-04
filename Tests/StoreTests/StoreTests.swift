import XCTest
@testable import Store

@available(iOS 13.0, macOS 10.15, *)
struct TestModel: SerializableModelType {
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

@available(iOS 13.0, macOS 10.15, *)
enum Action: ActionType {
  case increase(ammount: Int)
  case decrease(ammount: Int)
  case updateLabel(newLabel: String)
  case setArray(index: Int, value: String)

  var id: String {
    switch self {
    case .increase(_): return "INCREASE"
    case .decrease(_): return "DECREASE"
    case .updateLabel(_): return "UPDATE_LABEL"
    case .setArray(_): return "SET_ARRAY"
    }
  }

  func perform(context: TransactionContext<Store<TestModel>, Self>) {
    defer {
      context.fulfill()
    }
    switch self {
    case .increase(let ammount):
      context.updateModel { $0.count += ammount }
    case .decrease(let ammount):
      context.updateModel { $0.count -= ammount }
    case .updateLabel(let newLabel):
      context.updateModel {
        $0.label = newLabel
        $0.nested.label = newLabel
        $0.nullableLabel = nil
      }
    case .setArray(let index, let value):
      context.updateModel {
        $0.array[index].label = value
      }
    }
  }
}

@available(iOS 13.0, macOS 10.15, *)
final class StoreTests: XCTestCase {

  func testAsyncOperation() {
    let transactionExpectation = expectation(description: "Transaction completed.")
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.$lastTransactionDiff.sink { diff in

    }
    store.register(middleware: LoggerMiddleware())
    store.run(action: Action.increase(ammount: 42)) { context in
      XCTAssert(context.lastError == nil)
      XCTAssert(store.model.count == 42)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testAsyncOperationChain() {
    let transactionExpectation = expectation(description: "Transactions completed.")
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(actions: [
      Action.increase(ammount: 1),
      Action.increase(ammount: 1),
      Action.increase(ammount: 1),
    ]) { context in
      XCTAssert(store.model.count == 3)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testSyncOperation() {
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(action: Action.updateLabel(newLabel: "Bar"), mode: .sync)
    XCTAssert(store.model.label == "Bar")
    XCTAssert(store.model.nested.label == "Bar")
    store.run(action: Action.updateLabel(newLabel: "Foo"), mode: .sync)
    XCTAssert(store.model.label == "Foo")
    XCTAssert(store.model.nested.label == "Foo")
  }

  func testAccessNestedKeyPathInArray() {
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(action: Action.setArray(index: 1, value: "Foo"), mode: .sync)
    XCTAssert(store.model.array[1].label == "Foo")
  }

    static var allTests = [
      ("testAsyncOperation", testAsyncOperation),
      ("testSyncOperation", testSyncOperation),
    ]
}
