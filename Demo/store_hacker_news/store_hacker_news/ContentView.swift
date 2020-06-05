import SwiftUI

struct ContentView: View {
  @EnvironmentObject var store: AppStateStore
  
  var body: some View {
    Group {
  
      if store.model.items.isPending {
        loadingStoriesBody
      } else if !store.model.items.hasValue {
        noStoriesBody
      } else {
        storiesBody
      }
    }
  }
  
  var loadingStoriesBody: some View {
    HStack {
      Text("Loading stories..").font(.system(.caption, design: .rounded))
    }
  }
  
  var noStoriesBody: some View {
    HStack {
      Image(systemName: "hexagon")
      Text("Tap to load top stories").font(.system(.caption, design: .rounded))
    }.onTapGesture(perform: store.fetchTopStories)
  }
  
  var storiesBody: some View {
    List {
      ForEach(store.model.items.value ?? []) {
        Text($0.title)
      }
    }
  }
  
}
