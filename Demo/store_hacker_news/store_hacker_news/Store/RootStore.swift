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
  @CancellableRef private var cancellable = nil
  
  /// The execution body for this action.
  func reduce(context: TransactionContext<AppStateStore, Self>) {
    context.reduceModel { model in
      model.items = .pending(progress: 0)
    }
    cancellable = context.store.api.fetchTopStories().sink { items in
      context.reduceModel { model in
        model.items = .success(value: items, etag: 0)
      }
      context.fulfill()
    }
  }
  
  /// Cancels the operation.
  func cancel(context: TransactionContext<AppStateStore, FetchTopStories>) {
    cancellable.cancel()
    context.reduceModel { model in
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
    run(action: TemplateAction.Assign( \AppState.selectedItem, item))
  }
  
  func childStore(id: Item) -> Store<Item> {
    Store(model: id, combine: CombineStore(parent: self))
  }
}

extension Store where M == Item {
  var isSelected: Bool {
    guard let parent = parent(type: AppState.self) else { return false }
    return parent.model.selectedItem?.id == model.id
  }
  
  func select() {
    guard let parent = parent(type: AppState.self) as? AppStateStore else { return }
    parent.selectStory(model)
  }
  
  func deselect() {
    guard let parent = parent(type: AppState.self) as? AppStateStore else { return }
    parent.selectStory(nil)
  }
}

// MARK: - Internal

final class AnyCancellableRef {
  /// The cancellable value-type.
  var pointee: AnyCancellable?
}
