import Foundation
import Combine

/// First iteration will have URIs prefixe
fileprivate let baseURL = URL(string:"https://hacker-news.firebaseio.com/v0/")!

enum Endpoint {
  case topStories
  case item(id: Identifier<Item>)
  
  var url: URL {
    switch self {
    case .topStories:
      return baseURL.appendingPathComponent("topstories.json")
    case .item(let id):
      return baseURL.appendingPathComponent("item").appendingPathComponent("\(id.id).json")
    }
  }
}

final class API {
  private var fetchTopStoriesIdsCancellable: AnyCancellable?
  private var fetchItemsCancellable: AnyCancellable?
  
  func topStories() -> Future<[Item], Never> {
    Future { promise in
      self.fetchTopStoriesIdsCancellable = self.fetchTopStoriesIds().sink { ids in
        let idsPub = ids.map { id in self.fetchItem(id: id) }
        self.fetchItemsCancellable = Publishers.MergeMany(idsPub).collect().sink { items in
          let nonNilItems = items.compactMap { $0 }
          promise(.success(nonNilItems))
        }
      }
    }
  }
  
  func fetchTopStoriesIds() -> AnyPublisher<[Identifier<Item>], Never>  {
    URLSession.shared
      .dataTaskPublisher(for: Endpoint.topStories.url)
      .map(\.data)
      .decode(type: [Identifier<Item>].self, decoder: JSONDecoder())
      .replaceError(with: [])
      .eraseToAnyPublisher()
  }
  
  private func fetchItem(id: Identifier<Item>) -> AnyPublisher<Item?, Never> {
    URLSession.shared
      .dataTaskPublisher(for: Endpoint.item(id: id).url)
      .map(\.data)
      .decode(type: Item?.self, decoder: JSONDecoder())
      .replaceError(with: nil)
      .eraseToAnyPublisher()
  }
}


