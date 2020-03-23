import XCTest
import Combine
@testable import Store

struct Root {
  struct Todo {
    var name: String = "Untitled"
    var description: String = "N/A"
    var done: Bool = false
  }
  struct Note {
    var author: String = "Nobody"
    var text: String = ""
    var upvotes: Int = 0
  }
  var todo: Todo = Todo()
  var note: Note = Note()
}

class RootStore: Store<Root> {
  lazy var todoStore = makeChildStore(keyPath: \.todo)
  lazy var noteStore = makeChildStore(keyPath: \.note)
}

extension Root.Todo {
  struct Action_MarkAsDone: ActionProtocol {
    func reduce(context: TransactionContext<Store<Root.Todo>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { $0.done = true }
    }
  }
}

extension Root.Note {
  struct Action_IncreaseUpvotes: ActionProtocol {
    func reduce(context: TransactionContext<Store<Root.Note>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { $0.upvotes += 1 }
    }
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class CombinedStoreTests: XCTestCase {
  
  var sink: AnyCancellable?

  func testChildStoreChangesRootStoreValue() {
    let rootStore = RootStore(model: Root())
    XCTAssertFalse(rootStore.model.todo.done)
    XCTAssertFalse(rootStore.todoStore.model.done)
    rootStore.todoStore.run(action: Root.Todo.Action_MarkAsDone(), mode: .sync)
    XCTAssertTrue(rootStore.todoStore.model.done)
    XCTAssertTrue(rootStore.model.todo.done)
  }
  
  func testChildStoreChangesTriggersRootObserver() {
    let observerExpectation = expectation(description: "Observer called.")
    let rootStore = RootStore(model: Root())
    sink = rootStore.objectWillChange.sink {
      XCTAssertTrue(rootStore.model.todo.done)
      XCTAssertTrue(rootStore.todoStore.model.done)
      observerExpectation.fulfill()      
    }
    rootStore.todoStore.run(action: Root.Todo.Action_MarkAsDone(), mode: .sync)
    XCTAssertTrue(rootStore.todoStore.model.done)
    XCTAssertTrue(rootStore.model.todo.done)
    waitForExpectations(timeout: 1)
  }
}
