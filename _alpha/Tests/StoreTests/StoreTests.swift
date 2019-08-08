import XCTest
@testable import Store

@available(iOS 13.0, *)
struct Counter: ModelType {
  struct Action { }
  var count = 0
}

@available(iOS 13.0, *)
extension Counter.Action {
  struct Increase: ActionType {
    let identifier = "INCREASE"
    let ammount: Int

    func perform(operation: AsyncOperation, store: Store<Counter>, context: Dispatcher.Context) {
      store.updateModel { $0.count += ammount }
      operation.finish()
    }
  }
}

@available(iOS 13.0, *)
extension Counter.Action {
  struct Decrease: ActionType {
    let identifier = "DECREASE"
    let ammount: Int

    func perform(operation: AsyncOperation, store: Store<Counter>, context: Dispatcher.Context) {
      store.updateModel { $0.count -= ammount }
      operation.finish()
    }
  }
}

@available(iOS 13.0, *)
final class StoreTests: XCTestCase {
    func testExample() {

      let store = Store<Counter>()
      Transaction(
        store: store,
        action: Counter.Action.Increse(ammount: 42)).withStrategy(.sync).run()


      XCTAssert(store.model.count == 42)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
