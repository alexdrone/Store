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
  
  private var loadingStoriesBody: some View {
    VStack {
      Text("Loading stories...").font(.body)
      Button(action: store.cancelFetchTopStories) {
        Image(systemName: "xmark.circle")
      }
    }
  }
  
  private var noStoriesBody: some View {
    VStack {
      Text("No stories loaded.").font(.body)
      Button(action: store.fetchTopStories) {
        Image(systemName: "tray.and.arrow.down")
      }
    }
  }
  
  private var storiesBody: some View {
    List {
      ForEach(store.model.items.value ?? []) { self.storyBody(forItem: $0) }
    }
  }
  
  private func storyBody(forItem item: Item) -> some View {
    VStack(alignment: .leading) {
      Text(item.title)
        .font(.headline)
      Text(item.text ?? item.url ?? "No description.")
        .lineLimit(4)
        .font(.subheadline)
    }.padding()
  }

}
