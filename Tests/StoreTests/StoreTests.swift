import XCTest
@testable import Store

@available(iOS 13.0, macOS 10.15, *)
final class StoreTests: XCTestCase {

  func testAsyncOperation() {
    let transactionExpectation = expectation(description: "Transaction completed.")
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(action: Action.increase(amount: 42)) { context in
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
      Action.increase(amount: 1),
      Action.increase(amount: 1),
      Action.increase(amount: 1),
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
