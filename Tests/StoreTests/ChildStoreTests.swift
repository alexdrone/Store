import XCTest
import Combine
@testable import Store

struct Root: Codable {
  struct Todo: Codable {
    var name: String = "Untitled"
    var description: String = "N/A"
    var done: Bool = false
  }
  struct Note: Codable {
    var author: String = "Nobody"
    var text: String = ""
    var upvotes: Int = 0
  }
  var note: Note = Note()
  var todo: Todo = Todo()
  // List example with transient stores.
  var list: [Todo] = []
}

class RootStore: CodableStore<Root> {
  // Children test.
  lazy var todoStore = {
    self.makeChildStore(keyPath: \.todo)
  }()
  
  lazy var noteStore = {
    self.makeChildStore(keyPath: \.note)
  }()
  
  lazy var listStore = {
    self.makeChildStore(keyPath: \.list)
  }()
}

// MARK: Combined Stores

extension Root.Todo {
  struct Action_MarkAsDone: Action {
    let id = "MARK_AS_DONE"
    func mutate(context: TransactionContext<Store<Root.Todo>, Self>) {
      defer { context.fulfill() }
      context.update { $0.done = true }
    }
  
    func cancel(context: TransactionContext<Store<Root.Todo>, Self>) { }
  }
}

extension Root.Note {
  struct Action_IncreaseUpvotes: Action {
    let id = "INCREASE_UPVOTES"
    func mutate(context: TransactionContext<Store<Root.Note>, Self>) {
      defer { context.fulfill() }
      context.update { $0.upvotes += 1 }
    }
    
    func cancel(context: TransactionContext<Store<Root.Note>, Self>) { }
  }
}

// MARK: List and Transient Stores.

extension Root.Todo {
  struct Action_ListCreateNew: Action {
    let id = "LIST_CREATE_NEW"
    let name: String
    let description: String
    func mutate(context: TransactionContext<Store<Array<Root.Todo>>, Self>) {
      defer { context.fulfill() }
      let new = Root.Todo(name: name, description: description)
      context.update {
        $0.append(new)
      }
    }
    
    func cancel(context: TransactionContext<Store<Array<Root.Todo>>, Self>) { }
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class ChildStoreTests: XCTestCase {
  
  var sink: AnyCancellable?

  // MARK: Combined Stores
  
  func testChildStoreChangesRootStoreValue() {
    let rootStore = RootStore(model: Root())
    rootStore.register(middleware: LoggerMiddleware())
    rootStore.todoStore.register(middleware: LoggerMiddleware())
    rootStore.noteStore.register(middleware: LoggerMiddleware())
    rootStore.listStore.register(middleware: LoggerMiddleware())

    XCTAssertFalse(rootStore.readOnlyModel.todo.done)
    XCTAssertFalse(rootStore.todoStore.readOnlyModel.done)
    rootStore.todoStore.run(action: Root.Todo.Action_MarkAsDone(), mode: .sync)
    XCTAssertTrue(rootStore.todoStore.readOnlyModel.done)
    XCTAssertTrue(rootStore.readOnlyModel.todo.done)
  }
  
  func testChildStoreChangesTriggersRootObserver() {
    let observerExpectation = expectation(description: "Observer called.")
    let rootStore = RootStore(model: Root())
    rootStore.register(middleware: LoggerMiddleware())
    rootStore.todoStore.register(middleware: LoggerMiddleware())
    rootStore.noteStore.register(middleware: LoggerMiddleware())
    rootStore.listStore.register(middleware: LoggerMiddleware())
    
    sink = rootStore.objectWillChange.sink {
      XCTAssertTrue(rootStore.readOnlyModel.todo.done)
      XCTAssertTrue(rootStore.todoStore.readOnlyModel.done)
      observerExpectation.fulfill()
    }
    rootStore.todoStore.run(action: Root.Todo.Action_MarkAsDone(), mode: .sync)
    XCTAssertTrue(rootStore.todoStore.readOnlyModel.done)
    XCTAssertTrue(rootStore.readOnlyModel.todo.done)
    waitForExpectations(timeout: 1)
  }
  
  func testListAndTransientStores() {
    let rootStore = RootStore(model: Root())
    rootStore.listStore.run(
      action: Root.Todo.Action_ListCreateNew(name: "New", description: "New"),
      mode: .sync)
    rootStore.register(middleware: LoggerMiddleware())
    rootStore.listStore.register(middleware: LoggerMiddleware())
    
    XCTAssertTrue(rootStore.listStore.readOnlyModel.count == 1)
    XCTAssertTrue(rootStore.listStore.readOnlyModel[0].name == "New")
    XCTAssertTrue(rootStore.listStore.readOnlyModel[0].description == "New")
    XCTAssertTrue(rootStore.listStore.readOnlyModel[0].done == false)
    XCTAssertTrue(rootStore.readOnlyModel.list.count == 1)
    XCTAssertTrue(rootStore.readOnlyModel.list[0].name == "New")
    XCTAssertTrue(rootStore.readOnlyModel.list[0].description == "New")
    XCTAssertTrue(rootStore.readOnlyModel.list[0].done == false)
    
    let listStore = rootStore.listStore
    
    let todoStore = listStore.makeChildStore(keyPath: \.[0])
    todoStore.register(middleware: LoggerMiddleware())

    todoStore.run(action: Root.Todo.Action_MarkAsDone(), mode: .sync)
    XCTAssertTrue(todoStore.readOnlyModel.name == "New")
    XCTAssertTrue(todoStore.readOnlyModel.description == "New")
    XCTAssertTrue(todoStore.readOnlyModel.done == true)
    XCTAssertTrue(rootStore.listStore.readOnlyModel.count == 1)
    XCTAssertTrue(rootStore.listStore.readOnlyModel[0].name == "New")
    XCTAssertTrue(rootStore.listStore.readOnlyModel[0].description == "New")
    XCTAssertTrue(rootStore.listStore.readOnlyModel[0].done == true)
    XCTAssertTrue(rootStore.readOnlyModel.list.count == 1)
    XCTAssertTrue(rootStore.readOnlyModel.list[0].name == "New")
    XCTAssertTrue(rootStore.readOnlyModel.list[0].description == "New")
    XCTAssertTrue(rootStore.readOnlyModel.list[0].done == true)
  }
}

