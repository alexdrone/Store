import XCTest
import Combine
@testable import Store

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class StoreTests: XCTestCase {

  var sink: AnyCancellable?

  func testAsyncOperation() {
    let transactionExpectation = expectation(description: "Transaction completed.")
    let store = CodableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(action: TestAction.increase(amount: 42)) { error in
      XCTAssert(error == nil)
      XCTAssert(store.model.count == 42)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testAsyncOperationChain() {
    let transactionExpectation = expectation(description: "Transactions completed.")
    let store = CodableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(actions: [
      TestAction.increase(amount: 1),
      TestAction.increase(amount: 1),
      TestAction.increase(amount: 1),
    ]) { context in
      XCTAssert(store.model.count == 3)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 10)
  }

  func testSyncOperation() {
    let store = CodableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(action: TestAction.updateLabel(newLabel: "Bar"), mode: .sync)
    XCTAssert(store.model.label == "Bar")
    XCTAssert(store.model.nested.label == "Bar")
    store.run(action: TestAction.updateLabel(newLabel: "Foo"), mode: .sync)
    XCTAssert(store.model.label == "Foo")
    XCTAssert(store.model.nested.label == "Foo")
  }

  func testAccessNestedKeyPathInArray() {
    let store = CodableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(action: TestAction.setArray(index: 1, value: "Foo"), mode: .sync)
    XCTAssert(store.model.array[1].label == "Foo")
  }

  func testDiffResult() {
    let transactionExpectation = expectation(description: "Transactions completed.")
    let store = CodableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    store.run(action: TestAction.updateLabel(newLabel: "Bar"), mode: .sync)
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
    let store = CodableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    let transaction = store.transaction(action: TestAction.increase(amount: 1))
    sink = transaction.$state.sink { state in
      XCTAssert(state != .completed)
      XCTAssert(store.model.count == 0)
      if state == .canceled {
        transactionExpectation.fulfill()
      }
    }
    let _ = transaction.run()
    Executor.main.cancelAllTransactions()
    waitForExpectations(timeout: 2)
  }

  func testFutures() {
    let transactionExpectation = expectation(description: "Transactions completed.")
    let store = CodableStore(model: TestModel(), diffing: .sync)
    store.register(middleware: LoggerMiddleware())
    let action1 = TestAction.increaseWithDelay(amount: 5, delay: 0.1)

    sink = store.futureOf(action: action1)
      .replaceError(with: ())
      .sink {
      XCTAssert(store.model.count == 5)
      transactionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

    static var allTests = [
      ("testAsyncOperation", testAsyncOperation),
      ("testSyncOperation", testSyncOperation),
    ]
}
