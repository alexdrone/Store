import Foundation
#if os(iOS)
  import UIKit
#endif

final public class ImmutableModelRecorderMiddleware: MiddlewareType {

  public struct Record {

    /// A unique identifier for the current transaction.
    public let transaction: String

    public let model: ModelType
    public let action: ActionType
    public weak var store: StoreType?

    /// When the action was performed.
    public let timestamp: TimeInterval
  }

  private var records: [Record] = []
  private var index: Int = 0
  private let lock = NSRecursiveLock()

  /// How big is the history for this recorder.
  public var maxNumberOfRecords = 20

  public init(enableKeyboardControls: Bool) {
    guard enableKeyboardControls else {
      return
    }
    #if os(iOS)
      KeyCommands.register(input: "n", modifierFlags: .command) { [weak self] in
        self?.nextRecord()
      }
      KeyCommands.register(input: "p", modifierFlags: .command) { [weak self] in
        self?.previousRecord()
      }
    #endif
  }

  public func willDispatch(transaction: String, action: ActionType, in store: StoreType) { }

  /// An action just got dispatched.
  /// If the recorder index is not pointing to the tail, all of the records that appear after
  /// the index are going to be removed.
  public func didDispatch(transaction: String, action: ActionType, in store: StoreType) {
    let record = Record(transaction: transaction,
                        model: store.anyModel,
                        action: action,
                        store: store,
                        timestamp: Date().timeIntervalSince1970)
    self.lock.lock()
    self.records = Array(self.records.prefix(self.index))
    self.records.append(record)
    self.index += 1
    self.lock.unlock()
  }

  /// Moves the cursor back in history.
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
    store.inject(model: record.model, action: record.action)

    let date = Date(timeIntervalSince1970: record.timestamp)
    print("◀ \(store.identifier).\(record.action) @ \(date).)")
  }

  /// Moves the cursor forward in history.
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
    store.inject(model: record.model, action: record.action)

    let date = Date(timeIntervalSince1970: record.timestamp)
    print("▶ \(store.identifier).\(record.action) @ \(date).)")
  }
}


