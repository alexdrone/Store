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
