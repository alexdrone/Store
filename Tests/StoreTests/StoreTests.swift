import XCTest
@testable import Store

@available(iOS 13.0, macOS 10.15, *)
struct Counter: ModelType {
  struct Action { }

  var count = 0
  var label = "Foo"
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
      context.store.updateModel { $0.count += ammount }
    case .decrease(let ammount):
      context.store.updateModel { $0.count -= ammount }
    case .updateLabel(let newLabel):
      context.store.updateModel { $0.label = newLabel }
    }
  }
}

@available(iOS 13.0, macOS 10.15, *)
final class StoreTests: XCTestCase {

  func testAsyncOperation() {
    let transactionExpectation = expectation(description: "Transaction completed.")
    let store = Store<Counter>()
    Transaction(CounterAction.increase(ammount: 42), in: store).run { context in
      XCTAssert(context.lastError == nil)
      XCTAssert(store.model.count == 42)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testAsyncOperationChain() {
    let transactionExpectation = expectation(description: "Transactions completed.")
    let store = Store<Counter>()

    [Transaction(CounterAction.increase(ammount: 1), in: store),
     Transaction(CounterAction.increase(ammount: 1), in: store),
     Transaction(CounterAction.increase(ammount: 1), in: store)].run { context in
      XCTAssert(store.model.count == 3)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testSyncOperation() {
    let store = Store<Counter>()
    Transaction(CounterAction.updateLabel(newLabel: "Bar"), in: store)
      .on(.sync)
      .run()
    XCTAssert(store.model.label == "Bar")
  }

    static var allTests = [
      ("testAsyncOperation", testAsyncOperation),
      ("testSyncOperation", testSyncOperation),
    ]
}
