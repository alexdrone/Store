
import XCTest
import SwiftProtobuf
@testable import Store

@available(iOS 13.0, macOS 10.15, *)
struct ProtoAction {

  struct SetTitle: ActionType {
    typealias AssociatedStoreType = Store<BookInfo>
    let title: String

    func reduce(context: TransactionContext<Store<BookInfo>, Self>) -> Void {
      defer { context.fulfill() }
      context.reduceModel { book in book.title = self.title }
    }
  }
}

@available(iOS 13.0, macOS 10.15, *)
final class ProtobufTests: XCTestCase {

  func testProtobufModelInit() {
    let store = Store(model: BookInfo())
    store.run(action: ProtoAction.SetTitle(title: "Foo"), mode: .sync)
    XCTAssert(store.model.title == "Foo")
  }

  static var allTests = [
    ("testProtobufModelInit", testProtobufModelInit),
  ]
}
