import XCTest
@testable import Store

@available(iOS 13.0, macOS 10.15, *)
struct Counter: SerializableModelType {
  struct Action { }

  var count = 0
  var label = "Foo"
  var nullableLabel: String? = "Something"
  var nested = Nested()

  struct Nested: Codable {
    var label = "Nested struct"
  }
}

@available(iOS 13.0, macOS 10.15, *)
enum CounterAction: ActionType {
  case increase(ammount: Int)
  case decrease(ammount: Int)
  case updateLabel(newLabel: String)

  var identifier: String {
    switch self {
    case .increase(_): return "INCREASE"
    case .decrease(_): return "DECREASE"
    case .updateLabel(_): return "UPDATE_LABEL"
    }
  }

  func perform(context: TransactionContext<Store<Counter>, Self>) {
    defer {
      context.operation.finish()
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
    }
  }
}

@available(iOS 13.0, macOS 10.15, *)
final class StoreTests: XCTestCase {

  func testAsyncOperation() {
    let transactionExpectation = expectation(description: "Transaction completed.")
    let store = SerializableStore(model: Counter())
    store.diffing = .sync
    store.register(middleware: LoggerMiddleware())
    store.run(action: CounterAction.increase(ammount: 42)) { context in
      XCTAssert(context.lastError == nil)
      XCTAssert(store.model.count == 42)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testAsyncOperationChain() {
    let transactionExpectation = expectation(description: "Transactions completed.")
    let store = SerializableStore(model: Counter())
    store.diffing = .sync
    store.register(middleware: LoggerMiddleware())
    store.run(actions: [
      CounterAction.increase(ammount: 1),
      CounterAction.increase(ammount: 1),
      CounterAction.increase(ammount: 1),
    ]) { context in
      XCTAssert(store.model.count == 3)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testSyncOperation() {
    let store = SerializableStore(model: Counter())
    store.diffing = .sync
    store.register(middleware: LoggerMiddleware())
    store.run(action: CounterAction.updateLabel(newLabel: "Bar"), mode: .sync)
    XCTAssert(store.model.label == "Bar")
    XCTAssert(store.model.nested.label == "Bar")
    store.run(action: CounterAction.updateLabel(newLabel: "Foo"), mode: .sync)
    XCTAssert(store.model.label == "Foo")
    XCTAssert(store.model.nested.label == "Foo")
  }

    static var allTests = [
      ("testAsyncOperation", testAsyncOperation),
      ("testSyncOperation", testSyncOperation),
    ]
}
