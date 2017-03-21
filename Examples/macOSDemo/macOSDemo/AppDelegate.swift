import Cocoa
import Dispatch_macOS

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var label: NSTextField!
  private let store = Store<Counter, Counter.Action>(identifier: "counter",
                                                     reducer: CounterReducer())
  private let dispatcher = Dispatcher.default

  @IBAction func increase(_ sender: Any) {
    dispatcher.dispatch(action: Counter.Action.increase)
  }

  @IBAction func decrease(_ sender: Any) {
    dispatcher.dispatch(action: Counter.Action.decrease)
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

