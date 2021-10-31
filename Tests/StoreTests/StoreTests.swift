import XCTest
import Combine
import SwiftUI
import Primer
@testable import Store

final class StoreTests: XCTestCase {
  var subscriber: Cancellable?
  
  func testInitialization() {
    var testData = TestData()
    let store = Store(object: Binding(get: { testData }, set: { testData = $0 }))
    XCTAssert(store.constant == 1337)
    XCTAssert(store.label == "initial")
    XCTAssert(store.number == 42)
    store.number = 1
    store.label = "change"
    XCTAssert(store.number == 1)
    XCTAssert(store.label == "change")
  }
  
  func testStorePropertyDidChange() {
    var testData = TestData()
    let store = Store(object: Binding(get: { testData }, set: { testData = $0 }))
    let expectation = XCTestExpectation(description: "didChangeEvent")
    
    subscriber = store.propertyDidChange.sink { change in
      XCTAssert(store.label == "changed")
      expectation.fulfill()
    }
    store.label = "changed"
    wait(for: [expectation], timeout: 1)
  }
}

struct TestData {
  let constant = 1337
  var label = "initial"
  var number = 42
}
