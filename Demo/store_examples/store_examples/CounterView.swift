import Foundation
import SwiftUI
import Store

struct CounterModel {
  var count: Int
}

struct CounterView: View {
  @ObservedObject var store = Store(model: CounterModel(count: 0))
  
  var body: some View {
    VStack {
      Text(String(describing: store.binding.count))
      HStack {
        Button("Increase") { store.binding.count += 1 }
        Button("Decrease") { store.binding.count -= 1 }
      }
    }
  }
}
