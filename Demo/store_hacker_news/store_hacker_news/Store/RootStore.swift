import Foundation
import Store
import Combine

struct AppState: Codable {
  /// The items currently available.
  var items: FetchedProperty<[Item], Int> = .uninitalized
  /// Whether there is an item on focus.
  var selectedItem: Item?
  /// Test property used to test @ObservedObject binding usage with Store.
  var flag: Bool = false
}

/// Fetches the top stories from HackerNews.
struct FetchTopStories: Action {
  @CancellableStorage private var cancellable = nil
  
  /// The execution body for this action.
  func mutate(context: TransactionContext<AppStateStore, Self>) {
    context.update { model in
      model.items = .pending(progress: 0)
    }
    cancellable = context.store.api.fetchTopStories().sink { items in
      context.update { model in
        model.items = .success(value: items, etag: 0)
      }
      context.fulfill()
    }
  }
  
  /// Cancels the operation.
  func cancel(context: TransactionContext<AppStateStore, FetchTopStories>) {
    cancellable?.cancel()
    context.update { model in
      model.items = .uninitalized
    }
  }
}

class AppStateStore: CodableStore<AppState> {
  /// Hackernews REST endpoints.
  let api = API()
  private var fetchTopStoriesTransaction: AnyCancellable?
  
  convenience init() {
    self.init(model: AppState(), diffing: .async)
  }
  
  /// Fetches today's top stories from Hacker News.
  func fetchTopStories() {
    fetchTopStoriesTransaction = run(action: FetchTopStories()).eraseToAnyCancellable()
  }
  
  /// Cancels the fetch operation.
  func cancelFetchTopStories() {
    fetchTopStoriesTransaction?.cancel()
  }

  /// Select (or deselect) a story.
  func selectStory(_ item: Item?) {
    binding.selectedItem = item
  }
  
  func childStore(id: Item) -> Store<Item> {
    guard let idx = readOnlyModel.items.value?.firstIndex(where: { $0.id == id.id }) else {
      fatalError()
    }
    let childModel = readOnlyModel.items.value![idx]
    let childStorage = UnownedChildModelStorage(parent: modelStorage, model: childModel) {
      _, _ in
    }
    return Store(modelStorage: childStorage, parent: self)
  }
}

extension Store where M == Item {
  var isSelected: Bool {
    guard let parent = parent(type: AppState.self) else { return false }
    return parent.readOnlyModel.selectedItem?.id == readOnlyModel.id
  }
  
  func select() {
    guard let parent = parent(type: AppState.self) as? AppStateStore else { return }
    parent.selectStory(readOnlyModel)
  }
  
  func deselect() {
    guard let parent = parent(type: AppState.self) as? AppStateStore else { return }
    parent.selectStory(nil)
  }
}
