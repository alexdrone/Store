import Foundation
#if os(iOS)
  import UIKit
#endif

public protocol RecoderMiddlewareType: class, MiddlewareType {

  /// The pointer to the current record in the history.
  var index: Int { get set }

  /// Internal mutual exclusion mechanism.
  var lock: NSRecursiveLock { get set }

  /// The records history.
  var records: [RecordType] { get set }

  /// How big is the history for this recorder.
  var maxNumberOfRecords: Int { get set }

  /// Returns a record for the current store state.
  func constructRecord(transaction: String,
                       action: ActionType,
                       model: ModelType,
                       timestamp: TimeInterval) -> RecordType?
}

public protocol RecordType {

  /// A unique identifier for the current transaction.
  var transaction: String { get }

  /// The action that triggered the state change.
  var action: ActionType { get }

  /// Associated store.
  weak var store: StoreType? { get set }

  /// When the action was performed.
  var timestamp: TimeInterval { get }

  /// The model for the given record state.
  var model: () -> ModelType? { get }
}

public extension RecoderMiddlewareType {

  public func enableKeyboardControls() {
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
    guard var record = constructRecord(transaction: transaction,
                                       action: action,
                                       model: store.anyModel,
                                       timestamp: Date().timeIntervalSince1970) else {
      print("\(type(of: self)): Unable to construct model record.")
      return
    }
    record.store = store

    lock.lock()
    records = Array(self.records.prefix(self.index))
    records.append(record)
    index += 1
    lock.unlock()
  }

  /// Moves the cursor back in history.
  public func previousRecord() {
    precondition(Thread.isMainThread)
    guard index >= 0 else {
      return
    }
    lock.lock()
    index -= 1
    let record = records[self.index]
    lock.unlock()
    guard let store = record.store else {
      return
    }
    guard let model = record.model() else {
      return
    }
    store.inject(model: model, action: record.action)

    let date = Date(timeIntervalSince1970: record.timestamp)
    print("PREV \(store.identifier).\(record.action) @ \(date).)")
  }

  /// Moves the cursor forward in history.
  public func nextRecord() {
    precondition(Thread.isMainThread)
    guard index < records.count-1 else {
      return
    }
    lock.lock()
    index += 1
    let record = records[self.index]
    lock.unlock()
    guard let store = record.store else {
      return
    }
    guard let model = record.model() else {
      return
    }
    store.inject(model: model, action: record.action)

    let date = Date(timeIntervalSince1970: record.timestamp)
    print("NEXT \(store.identifier).\(record.action) @ \(date).)")
  }
}

// MARK: - Immutable Recorder 

public final class ImmutableModelRecorderMiddleware: RecoderMiddlewareType {

  public final class Record: RecordType {

    public let transaction: String
    public let action: ActionType
    public weak var store: StoreType?
    public let timestamp: TimeInterval
    public var model: () -> ModelType? = { return nil }

    private let immutableModel: ImmutableModelType

    init(transaction: String,
         action: ActionType,
         model: ImmutableModelType,
         timestamp: TimeInterval) {
      self.transaction = transaction
      self.action = action
      self.timestamp = timestamp
      self.immutableModel = model
      self.model = { [weak self] in
        guard let `self` = self else {
          return nil
        }
        return self.immutableModel
      }
    }
  }

  public var records: [RecordType] = []
  public var index: Int = 0
  public var lock = NSRecursiveLock()
  public var maxNumberOfRecords = 20

  public init(shouldEnableKeyboardControls: Bool) {
    guard shouldEnableKeyboardControls else {
      return
    }
    enableKeyboardControls()
  }

  public func constructRecord(transaction: String,
                              action: ActionType,
                              model: ModelType,
                              timestamp: TimeInterval) -> RecordType? {
    guard let model = model as? ImmutableModelType else {
      return nil
    }
    return Record(transaction: transaction, action: action, model: model, timestamp: timestamp)
  }
}

// MARK: - Serializable Recorder

public final class SerializableModelRecorderMiddleware: RecoderMiddlewareType {

  public final class Record: RecordType {

    public let transaction: String
    public let action: ActionType
    public weak var store: StoreType?
    public let timestamp: TimeInterval
    public var model: () -> ModelType? = { return nil }
    private let encodedModel: [String: Any]
    private let decoder: ([String: Any]) -> ModelType

    init(transaction: String,
         action: ActionType,
         model: SerializableModelType,
         timestamp: TimeInterval) {
      self.transaction = transaction
      self.action = action
      self.timestamp = timestamp
      self.encodedModel = model.encode()
      self.decoder = model.decoder()
      self.model = { [weak self] in
        guard let `self` = self else {
          return nil
        }
        return self.decoder(self.encodedModel)
      }
    }
  }

  public var records: [RecordType] = []
  public var index: Int = 0
  public var lock = NSRecursiveLock()
  public var maxNumberOfRecords = 20

  public init(shouldEnableKeyboardControls: Bool) {
    guard shouldEnableKeyboardControls else {
      return
    }
    enableKeyboardControls()
  }

  public func constructRecord(transaction: String,
                              action: ActionType,
                              model: ModelType,
                              timestamp: TimeInterval) -> RecordType? {
    guard let model = model as? SerializableModelType else {
      return nil
    }
    return Record(transaction: transaction, action: action, model: model, timestamp: timestamp)
  }
  
}


