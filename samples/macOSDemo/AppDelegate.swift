import Cocoa
import DispatchStore_macOS

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var label: NSTextField!
  private let store = Store<Counter, Counter.Action>(identifier: "counter",
                                                     reducer: CounterReducer())
  private let dispatcher = Dispatcher.default

  @IBAction func increase(_ sender: Any) {
    self.dispatcher.dispatch(action: Counter.Action.increase, mode: .async)
  }

  @IBAction func decrease(_ sender: Any) {
    self.dispatcher.dispatch(action: Counter.Action.decrease, mode: .async)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {

    self.dispatcher.register(store: self.store)
    self.dispatcher.register(middleware: LoggerMiddleware())

    self.store.register(observer: self) { state, _ in
      self.label.stringValue = "\(state.count)"
      self.label.setNeedsDisplay()
    }
  }
}

