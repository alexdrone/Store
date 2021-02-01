import SwiftUI
import Store

// MARK: - Main

struct ContentView: View {
  @ObservedObject var store: AppStateStore
  var model: AppState { store.readOnlyModel }

  @ViewBuilder
  var body: some View {
    Group {
      if model.selectedItem != nil {
        StoryView(store: self.store.childStore(id: model.selectedItem!))
      } else if model.items.isPending {
        loadingStoriesBody
      } else if !model.items.hasValue {
        noStoriesBody
      } else {
        storiesBody
      }
    }
  }
  
  @ViewBuilder
  private var loadingStoriesBody: some View {
    VStack {
      Text("Loading stories...").font(.body)
      Button(action: store.cancelFetchTopStories) {
        Image(systemName: "xmark.circle")
      }
    }
  }
  
  @ViewBuilder
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
  
  @ViewBuilder
  private var bindingProxyTest: some View {
    Toggle("", isOn: $store.binding.flag).padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/, /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
  }
  
  @ViewBuilder
  private var storiesBody: some View {
    List {
      ForEach(model.items.value ?? []) {
        StoryView(store: self.store.childStore(id: $0))
      }
    }
  }
}

// MARK: - Story 

struct StoryView: View {
  let store: Store<Item>
  var model: Item { store.modelStorage.model }
  
  private var title: String {
    model.title
  }
  private var caption: String {
    model.text ?? model.url ?? "N/A."
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

