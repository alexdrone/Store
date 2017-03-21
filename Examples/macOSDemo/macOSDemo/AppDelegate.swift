import Cocoa
import Dispatch_macOS

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var label: NSTextField!
  private let store = Store<Counter, Counter.Action>(identifier: "counter",
                                                     reducer: CounterReducer())

  @IBAction func increase(_ sender: Any) {
    store.dispatch(action: .increase)
  }

  @IBAction func decrease(_ sender: Any) {
    store.dispatch(action: .decrease)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    store.register(observer: self) { state, _ in
      self.label.stringValue = "\(state.count)"
      self.label.setNeedsDisplay()
    }
  }
}

