import Foundation

final public class RecorderMiddleware: MiddlewareType {

  public struct Record {

    /** A unique identifier for the current transaction. */
    public let transaction: String

    /** The state after the action was performed. */
    public let state: StateType

    /** Thse action triggered. */
    public let action: ActionType

    /** The store that was affected. */
    public weak var store: StoreType?

    /** When the action was performed. */
    public let timestamp: TimeInterval
  }

  // All the states recorded.
  private var records: [Record] = []
  private var index: Int = 0
  private let lock = NSRecursiveLock()

  /** How big is the history for this recorder. */
  public var maxNumberOfRecords = 20

  public init(enableKeyboardControls: Bool) {
    guard enableKeyboardControls else {
      return
    }
    KeyCommands.register(input: "n", modifierFlags: .command) { [weak self] in
      self?.nextRecord()
    }
    KeyCommands.register(input: "p", modifierFlags: .command) { [weak self] in
      self?.previousRecord()
    }
  }

  public func willDispatch(transaction: String, action: ActionType, in store: StoreType) {
    // Nothing to do.
  }

  /** An action just got dispatched. 
   *  If the recorder index is not pointing to the tail, all of the records that appear after
   *  the index are going to be removed.
   */
  public func didDispatch(transaction: String, action: ActionType, in store: StoreType) {
    let record = Record(transaction: transaction,
                        state: store.stateValue,
                        action: action,
                        store: store,
                        timestamp: Date().timeIntervalSince1970)
    self.lock.lock()
    self.records = Array(self.records.prefix(self.index))
    self.records.append(record)
    self.index += 1
    self.lock.unlock()
  }

  /** Moves the cursor back in history. */
  private func previousRecord() {
    precondition(Thread.isMainThread)
    guard self.index > 0 else {
      return
    }
    self.lock.lock()
    self.index -= 1
    let record = self.records[self.index]
    self.lock.unlock()
    guard let store = record.store else {
      return
    }
    store.inject(state: record.state, action: record.action)

    let date = Date(timeIntervalSince1970: record.timestamp)
    print("◀ \(store.identifier).\(record.action) @ \(date).)")
  }

  /** Moves the cursor forward in history. */
  private func nextRecord() {
    precondition(Thread.isMainThread)
    guard self.index < self.records.count-1 else {
      return
    }
    self.lock.lock()
    self.index += 1
    let record = self.records[self.index]
    self.lock.unlock()
    guard let store = record.store else {
      return
    }
    store.inject(state: record.state, action: record.action)

    let date = Date(timeIntervalSince1970: record.timestamp)
    print("▶ \(store.identifier).\(record.action) @ \(date).)")
  }
}

// MARK: - KeyCommands
// forked from: Augustyniak/KeyCommands / Created by Rafal Augustyniak

#if (arch(i386) || arch(x86_64)) && (os(iOS) || os(tvOS))

  import UIKit

  struct KeyActionableCommand {
    fileprivate let keyCommand: UIKeyCommand
    fileprivate let actionBlock: () -> ()

    func matches(_ input: String, modifierFlags: UIKeyModifierFlags) -> Bool {
      return keyCommand.input == input && keyCommand.modifierFlags == modifierFlags
    }
  }

  func == (lhs: KeyActionableCommand, rhs: KeyActionableCommand) -> Bool {
    return lhs.keyCommand.input == rhs.keyCommand.input
      && lhs.keyCommand.modifierFlags == rhs.keyCommand.modifierFlags
  }

  public enum KeyCommands {
    private static var __once: () = {
      exchangeImplementations(class: UIApplication.self,
                              originalSelector: #selector(getter: UIResponder.keyCommands),
                              swizzledSelector: #selector(UIApplication.KYC_keyCommands));
    }()
    fileprivate struct Static {
      static var token: Int = 0
    }

    struct KeyCommandsRegister {
      static var sharedInstance = KeyCommandsRegister()
      fileprivate var actionableKeyCommands = [KeyActionableCommand]()
    }

    /** Registers key command for specified input and modifier flags. Unregisters previously
     *  registered key commands matching provided input and modifier flags. Does nothing when
     * application runs on actual device.
     */
    public static func register(input: String,
                                modifierFlags: UIKeyModifierFlags,
                                action: @escaping () -> ()) {
      _ = KeyCommands.__once
      let keyCommand = UIKeyCommand(input: input,
                                    modifierFlags: modifierFlags,
                                    action: #selector(UIApplication.KYC_handleKeyCommand(_:)),
                                    discoverabilityTitle: "")
      let actionableKeyCommand = KeyActionableCommand(keyCommand: keyCommand, actionBlock: action)
      let index = KeyCommandsRegister.sharedInstance.actionableKeyCommands.index(
        where: { return $0 == actionableKeyCommand })
      if let index = index {
        KeyCommandsRegister.sharedInstance.actionableKeyCommands.remove(at: index)
      }
      KeyCommandsRegister.sharedInstance.actionableKeyCommands.append(actionableKeyCommand)
    }

    /** Unregisters key command matching specified input and modifier flags.
     *  Does nothing when application runs on actual device.
     */
    public static func unregister(input: String, modifierFlags: UIKeyModifierFlags) {
      let index = KeyCommandsRegister.sharedInstance.actionableKeyCommands.index(
        where: { return $0.matches(input, modifierFlags: modifierFlags) })
      if let index = index {
        KeyCommandsRegister.sharedInstance.actionableKeyCommands.remove(at: index)
      }
    }
  }

  extension UIApplication {
    dynamic func KYC_keyCommands() -> [UIKeyCommand] {
      return KeyCommands.KeyCommandsRegister.sharedInstance.actionableKeyCommands.map({
        return $0.keyCommand
      })
    }

    func KYC_handleKeyCommand(_ keyCommand: UIKeyCommand) {
      for command in KeyCommands.KeyCommandsRegister.sharedInstance.actionableKeyCommands {
        if command.matches(keyCommand.input, modifierFlags: keyCommand.modifierFlags) {
          command.actionBlock()
        }
      }
    }
  }

  func exchangeImplementations(class classs: AnyClass,
                               originalSelector: Selector,
                               swizzledSelector: Selector ){
    let originalMethod = class_getInstanceMethod(classs, originalSelector)
    let originalMethodImplementation = method_getImplementation(originalMethod)
    let originalMethodTypeEncoding = method_getTypeEncoding(originalMethod)
    let swizzledMethod = class_getInstanceMethod(classs, swizzledSelector)
    let swizzledMethodImplementation = method_getImplementation(swizzledMethod)
    let swizzledMethodTypeEncoding = method_getTypeEncoding(swizzledMethod)
    let didAddMethod = class_addMethod(classs,
                                       originalSelector,
                                       swizzledMethodImplementation,
                                       swizzledMethodTypeEncoding)
    if didAddMethod {
      class_replaceMethod(classs,
                          swizzledSelector,
                          originalMethodImplementation,
                          originalMethodTypeEncoding)
    } else {
      method_exchangeImplementations(originalMethod, swizzledMethod)
    }
  }

#else
  public enum KeyCommands {
    public static func register(input: String,
                                modifierFlags: UIKeyModifierFlags,
                                action: () -> ()) {}
    public static func unregister(input: String, modifierFlags: UIKeyModifierFlags) {}
  }
#endif
