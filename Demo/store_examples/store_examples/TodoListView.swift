import Foundation
import SwiftUI
import Store

// MARK: - Store

final class Todo: Codable, Identifiable {
  private(set) var id = PushID.default.make()
  var text: String = "Untitled Todo"
  var done: Bool = false
}

final class TodoList: Codable {
  var todos: [Todo] = []
}

extension Store where M == TodoList {
  func addNewTodo() {
    mutate(id: #function) { model in
      model.todos.append(Todo())
    }
  }
  
  func move(from source: IndexSet, to destination: Int) {
    mutate(id: #function) { model in
      model.todos.move(fromOffsets: source, toOffset: destination)
    }
  }
  
  func remove(todo: Todo) {
    mutate(id: #function) { model in
      model.todos = model.todos.filter { $0.id != todo.id }
    }
  }
}

// MARK: - Views

struct TodoView: View {
  @ObservedObject var store: CodableStore<Todo>
  let onRemove: () -> Void
  
  var body: some View {
    HStack {
      // Move handle.
      Image(systemName: "line.horizontal.3")
      // Text.
      if store.readOnlyModel.done {
        Text(store.readOnlyModel.text)
          .strikethrough()
      } else {
        TextField("Todo", text: $store.binding.text)
      }
      Spacer()
      // Mark item as done.
      Toggle("", isOn: $store.binding.done)
      // Remove task.
      Button("Remove", action: onRemove)
        .buttonStyle(DestructiveButtonStyle())
    }.padding()
  }
}

struct TodoListView: View {
  @ObservedObject var store = CodableStore(model: TodoList(), diffing: printDebugDiff)
  
  var body: some View {
    List {
      // Todo items.
      ForEach(store.readOnlyModel.todos) { todo in
        TodoView(store: CodableStore(model: todo)) { store.remove(todo: todo) }
      }
      .onMove(perform: store.move)
      // Add a new item.
      Button("New Todo", action: store.addNewTodo)
        .buttonStyle(AccentButtonStyle())
    }
  }
}

#if DEBUG
fileprivate let printDebugDiff: CodableStore<TodoList>.Diffing = .sync
#else
fileprivate let printDebugDiff: CodableStore<TodoList>.Diffing = .none
#endif
