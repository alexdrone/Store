import XCTest
import Combine
@testable import Store

struct Root {
  class Todo {
    var name: String = "Untitled"
    var description: String = "N/A"
    var done: Bool = false
    init() { }
  }
  class Note {
    var author: String = "Nobody"
    var text: String = ""
    var upvotes: Int = 0
    init() { }
  }
  var todo: Todo = Todo()
  var note: Note = Note()
}

class RootStore: Store<Root> {
  lazy var todoStore: Store<Root.Todo> = {
    Store(model: self.model.todo).withParent(store: self)
  }()
  lazy var noteStore: Store<Root.Note> = {
    Store(model: self.model.note).withParent(store: self)
  }()
}

extension Root.Todo {
  struct Action_MarkAsDone: ActionProtocol {
    func reduce(context: TransactionContext<Store<Root.Todo>, Self>) {
      defer {  context.fulfill() }
      context.reduceModel { $0.done = true }
    }
  }
}

extension Root.Note {
  struct Action_IncreaseUpvotes: ActionProtocol {
    func reduce(context: TransactionContext<Store<Root.Note>, Self>) {
      defer {  context.fulfill() }
      context.reduceModel { $0.upvotes += 1 }
    }
  }
}
