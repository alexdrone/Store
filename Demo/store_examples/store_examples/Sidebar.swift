import SwiftUI

struct Sidebar: View {
    var body: some View {
      List {
       NavigationLink("Counter", destination: CounterView())
      }
      .listStyle(SidebarListStyle())
      .navigationTitle("Store")
    }
}
