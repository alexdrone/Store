
import XCTest
import SwiftProtobuf
@testable import Store

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
extension Action_BookInfoSetTitle: ActionProtocol {
  typealias AssociatedStoreType = Store<BookInfo>

  func reduce(context: TransactionContext<Store<BookInfo>, Self>) -> Void {
    defer { context.fulfill() }
    context.reduceModel { book in book.title = self.title }
  }
}

extension BookInfo {
  static func setTitle(_ title: String) -> Action_BookInfoSetTitle {
    Action_BookInfoSetTitle.with {
      $0.title = title
    }
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class ProtobufTests: XCTestCase {

  func testProtobufModelInit() {
    let store = Store(model: BookInfo())
    store.run(actions: [BookInfo.setTitle("Foo")], mode: .sync)
    XCTAssert(store.model.title == "Foo")
  }

  static var allTests = [
    ("testProtobufModelInit", testProtobufModelInit),
  ]
}
