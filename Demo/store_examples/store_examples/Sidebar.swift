import SwiftUI

struct Sidebar: View {
    var body: some View {
      List {
        NavigationLink("Counter", destination: CounterView())
        NavigationLink("Todo List", destination: TodoListView())
      }
      .listStyle(SidebarListStyle())
      .navigationTitle("Store")
    }
}
