import XCTest
import Combine
@testable import Store

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class StoreTests: XCTestCase {

  var sink: AnyCancellable?

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

  func testDiffResult() {
    let transactionExpectation = expectation(description: "Transactions completed.")
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(action: Action.updateLabel(newLabel: "Bar"), mode: .sync)
    sink = store.$lastTransactionDiff.sink { diff in
      XCTAssert(diff.query { $0.label }.isChanged() == true)
      XCTAssert(diff.query { $0.nested.label }.isChanged() == true)
      XCTAssert(diff.query { $0.nullableLabel }.isRemoved() == true)
      XCTAssert(diff.query { $0.label }.isRemoved() == false)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testCancellationPreventOperationsExecution() {
    let transactionExpectation = expectation(description: "Transactions canceled.")
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    let transaction = store.transaction(action: Action.increase(amount: 1))
    sink = transaction.$state.sink { state in
      XCTAssert(state != .completed)
      XCTAssert(store.model.count == 0)
      if state == .canceled {
        transactionExpectation.fulfill()
      }
    }
    transaction.run()
    Dispatcher.main.cancelAllTransactions()
    waitForExpectations(timeout: 2)
  }
  
  func testRunGroupSyntax() {
    let transactionExpectation = expectation(description: "Transactions group finished.")
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.runGroup {
      Transaction<Action>(.increase(amount: 1))
      Concurrent {
        Transaction<Action>(.increase(amount: 1))
        Transaction<Action>(.increase(amount: 1))
      }
      Transaction<Action>(.increase(amount: 1)).then { _ in
        transactionExpectation.fulfill()
      }
    }
    waitForExpectations(timeout: 1)
  }

  func testThrottle() {
    let transactionExpectation = expectation(description: "Transactions group finished.")
    let store = SerializableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.runGroup {
      Throttle(1.0) {
        Transaction<Action>(.throttleIncrease(amount: 1))
        Transaction<Action>(.throttleIncrease(amount: 1))
        Transaction<Action>(.throttleIncrease(amount: 1))
      }
      Transaction<Action>(.updateLabel(newLabel: "Test"), in: store).then { _ in
        // Just one of the two throttleIncrease is invoked.
        XCTAssert(store.model.count == 1)
        transactionExpectation.fulfill()
      }
    }
    waitForExpectations(timeout: 2)
  }


    static var allTests = [
      ("testAsyncOperation", testAsyncOperation),
      ("testSyncOperation", testSyncOperation),
    ]
}
