import Cocoa
import DispatchStore

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  /// The key window.
  @IBOutlet weak var window: NSWindow!
  /// A simple label showing the current counter state.
  @IBOutlet weak var label: NSTextField!
  /// The counter store object.
  private let store = Store<Counter, Counter.Action>(
    identifier: "counter",
    reducer: CounterReducer())
  /// The default dispatcher object.
  private let dispatcher = ActionDispatch.default

  /// On click dispatches an increase action.
  @IBAction func increase(_ sender: Any) {
    self.dispatcher.dispatch(action: Counter.Action.increase, mode: .async)
  }

  /// On click dispatches a decrease action.
  @IBAction func decrease(_ sender: Any) {
    self.dispatcher.dispatch(action: Counter.Action.decrease, mode: .async)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    /// Register the store to the global dispatcher.
    self.dispatcher.register(store: self.store)
    /// Register the action logger middleware.
    self.dispatcher.register(middleware: LoggerMiddleware())
    /// Updates the view when the store changes.
    self.store.register(observer: self) { state, _ in
      self.label.stringValue = "\(state.count)"
      self.label.setNeedsDisplay()
    }
  }
}

