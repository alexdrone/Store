import SwiftUI
import Store

// MARK: - Main

struct ContentView: View {
  @ObservedObject var store: AppStateStore
  
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
      Spacer()
      Text("No stories loaded.").font(.body)
      Button(action: store.fetchTopStories) {
        Image(systemName: "tray.and.arrow.down")
      }
      Spacer()
      bindingProxyTest
    }
  }
  
  private var bindingProxyTest: some View {
    Toggle("", isOn: $store.binding.flag).padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/, /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
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
    Group {
      if store.isSelected {
        expanded
      } else {
        collapsed
      }
    }.padding()
  }
  
  var collapsed: some View {
    Button(action: store.select) {
      HStack {
        Image(systemName: "hexagon").padding()
        VStack(alignment: .leading) {
          Text(title).font(.headline)
          Text(caption).font(.subheadline).lineLimit(2)
        }
      }

    }
  }
  
  var expanded: some View {
    VStack(alignment: .center) {
      Text(title).font(.system(.headline, design: .rounded))
      ScrollView {
        Text(caption).font(.callout)
      }
      Spacer()
      Button(action: store.deselect) {
        Image(systemName: "xmark.circle")
      }
    }
  }

}

