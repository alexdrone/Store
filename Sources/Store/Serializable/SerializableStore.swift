import Foundation
import Combine

@available(iOS 13.0, macOS 10.15, *)
open class SerializableStore<M: SerializableModelType>: Store<M> {
  public enum DiffingOption {
    case none
    case sync
    case async
  }
  /// The diffing dispatch strategy.
  public var diffing: DiffingOption = .async
  /// Publishes a stream with the latest model changes.
  @Published public var diffs: PropertyDiffSet = PropertyDiffSet(diffs: [:], transaction: nil)
  /// Publishes a JSON data stream with the econded diffs.
  @Published public var jsonDiffs: Data = Data()

  // Private.
  private let queue = DispatchQueue(label: "io.store.serializable")
  private let jsonEncoder = JSONEncoder()
  private var transactions = Set<String>()
  private var snapshot: [FlatEncoding.KeyPath: Codable?] = [:]

  override public init(model: M) {
    super.init(model: model)
    self.snapshot = model.encodeToFlattenDictionary()
  }

  override open func updateModel(transaction: AnyTransaction?, closure: (inout M) -> (Void)) {
    let transaction = transaction ?? SerializableUpdateModelTransaction()
    super.updateModel(transaction: transaction, closure: closure)
  }

  override open func didUpdateModel(transaction: AnyTransaction?, old: M, new: M) {
    guard let transaction = transaction, diffing != .none else {
      return
    }
    func dispatch(option: DiffingOption, execute: @escaping () -> Void) {
      if option == .sync {
        queue.sync(execute: execute)
      } else if option == .async {
        queue.async(execute: execute)
      }
    }
    dispatch(option: diffing) {
      self.transactions.insert(transaction.id)
      /// The resulting dictionary won't be nested and all of the keys will be paths.
      let encodedModel: FlatEncoding.Dictionary = new.encodeToFlattenDictionary()
      var diffs: [FlatEncoding.KeyPath: PropertyDiff] = [:]
      for (key, value) in encodedModel {
        // The (`keyPath`, `value`) pair was not in the previous snapshot.
        if self.snapshot[key] == nil {
          diffs[key] = .added(new: value)
        // The (`keyPath`, `value`) pair has changed value.
        } else if let old = self.snapshot[key], !dynamicEqual(lhs: old, rhs: value) {
          diffs[key] = .changed(old: old, new: value)
        }
      }
      // The (`keyPath`, `value`) was removed from the snapshot.
      for (key, _) in self.snapshot where encodedModel[key] == nil {
        diffs[key] = .removed
      }
      // Updates the publisher.
      self.diffs = PropertyDiffSet(diffs: diffs, transaction: transaction)
      self.jsonDiffs = (try? self.jsonEncoder.encode(diffs)) ?? Data()
      self.snapshot = encodedModel

      print("▩ 𝘿𝙄𝙁𝙁 (\(transaction.id)) \(transaction.actionId) \(diffs.log)")
    }
  }
}

// MARK: - SerializableUpdateModelTransaction

@available(iOS 13.0, macOS 10.15, *)
public final class SerializableUpdateModelTransaction: AnyTransaction {
  /// Every access to `SerializableStore.updateModel` without a transaction argument results in
  /// a `SERIALIZABLE_UPDATE_MODEL` transaction.
  public let actionId: String = "SERIALIZABLE_UPDATE_MODEL"
  /// Randomized identifier for the current transaction that preserve the temporal information.
  public let id: String = PushID.default.make()
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public let strategy: Dispatcher.Strategy = .async(nil)
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public var error: Dispatcher.TransactionGroupError? = nil
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public  var operation: AsyncOperation {
    fatalError("SERIALIZABLE_UPDATE_MODEL transaction does not spawn any operation.")
  }
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public var opaqueStoreRef: AnyStoreType? = nil
  /// Represents the progress of the transaction.
  public var state: TransactionState = .pending
  
  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public func on(_ queueWithStrategy: Dispatcher.Strategy) -> Self {
    // No op.
    return self
  }

  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public func perform(operation: AsyncOperation) {
    // No op
  }

  /// - note: SERIALIZABLE_UPDATE_MODEL transaction don't have an associated operation..
  public func run(handler: Dispatcher.TransactionCompletionHandler) {
    // No op
  }
}
