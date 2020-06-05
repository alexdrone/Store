import Foundation
import Store
import Combine

struct AppState: Codable {
  /// The items currently available.
  var items: FetchedProperty<[Item], Int> = .uninitalized
  /// Whether there is an item on focus.
  var selectedItem: Item?
  /// Whether there is a focused user.
  var selectedUser: User?
}

/// Fetches the top stories from HackerNews.
struct FetchTopStories: ActionProtocol {
  private let cancellable = AnyCancellableRef()
  
  func reduce(context: TransactionContext<AppStateStore, Self>) {
    context.reduceModel { model in
      model.items = .pending(progress: 0)
    }
    cancellable.pointee = context.store.api.topStories().sink { items in
      context.reduceModel { model in
        model.items = .success(value: items, etag: 0)
      }
      context.fulfill()
    }
  }
}

class AppStateStore: SerializableStore<AppState> {
  /// Hackernews REST endpoints.
  let api = API()
  
  convenience init() {
    self.init(model: AppState(), diffing: .none)
  }
  
  func fetchTopStories() {
    run(action: FetchTopStories())
  }
}


// MARK: - Internal

final class AnyCancellableRef {
  /// The cancellable value-type.
  var pointee: AnyCancellable?
}
