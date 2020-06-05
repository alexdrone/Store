import SwiftUI
import Store

// MARK: - Main

struct ContentView: View {
  @EnvironmentObject var store: AppStateStore
  
  var body: some View {
    Group {
      if store.model.selectedItem != nil {
        StoryView(store: self.store.childStore(id: store.model.selectedItem!))
      } else if store.model.items.isPending {
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
      ForEach(store.model.items.value ?? []) {
        StoryView(store: self.store.childStore(id: $0))
      }
    }
  }
}

// MARK: - Story 

struct StoryView: View {
  let store: Store<Item>
  
  private var title: String {
    store.model.title
  }
  private var caption: String {
    store.model.text ?? store.model.url ?? "N/A."
  }
  
  var body: some View {
    Button(action: store.select) {
      VStack(alignment: store.isSelected ? .center : .leading) {
        Text(title).font(.headline)
        Text(caption).font(.subheadline).lineLimit(store.isSelected ? nil : 4)
        
        if store.isSelected {
          Button(action: store.deselect) {
            Image(systemName: "xmark.circle")
          }
        }
      }
      .padding()
    }
  }
  
}
