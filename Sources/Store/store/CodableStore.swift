import Combine
import Foundation
import os.log

/// A `Store` subclass with serialization capabilities.
/// Additionally a `CodableStore` can emits diffs for every transaction execution (see
/// the `lastTransactionDiff` pubblisher).
/// This can be useful for store synchronization (e.g. with a local or remote database).
open class CodableStore<M: Codable>: Store<M> {
  
  /// Transaction diffing options.
  public enum Diffing {
    /// Does not compute any diff.
    case none
    /// Computes the diff synchronously right after the transaction has completed.
    case sync
    /// Computes the diff asynchronously (in a serial queue) when transaction is completed.
    case async
  }

  /// Publishes a stream with the model changes caused by the last transaction.
  @Published public var lastTransactionDiff: TransactionDiff = TransactionDiff(
    transaction: SignpostTransaction(signpost: SignpostID.prior),
    diffs: [:])
  /// Where the diffing routine should be dispatched.
  public let diffing: Diffing
  
  /// Serial queue used to run the diffing routine.
  private let _queue = DispatchQueue(label: "io.store.diff")
  /// Set of `transaction.id` for all of the transaction that have run of this store.
  private var _transactionIdsHistory = Set<String>()
  /// Last serialized snapshot for the model.
  private var _lastModelSnapshot: [FlatEncoding.KeyPath: Codable?] = [:]

  /// Constructs a new Store instance with a given initial model.
  ///
  /// - parameter model: The initial model state.
  /// - parameter diffing: The store diffing option.
  ///                      This will aftect how `lastTransactionDiff` is going to be produced.
  public init(
    model: M,
    diffing: Diffing = .async
  ) {
    self.diffing = diffing
    super.init(model: model)
    self._lastModelSnapshot = CodableStore.encodeFlat(model: model)
  }
  
  
  /// Constructs a new Store instance with a given initial model.
  ///
  /// - parameter model: The initial model state.
  /// - parameter diffing: The store diffing option.
  ///                      This will aftect how `lastTransactionDiff` is going to be produced.
  /// - parameter combine: A associated parent store. Useful whenever it is desirable to merge
  ///                      back changes from a child store to its parent.
  public init<P>(
    model: M,
    diffing: Diffing = .async,
    combine: CombineStore<P, M>
  ) {
    self.diffing = diffing
    super.init(model: model, combine: combine)
    self._lastModelSnapshot = CodableStore.encodeFlat(model: model)
  }
  
  // MARK: Model updates

  override open func reduceModel(transaction: AnyTransaction?, closure: (inout M) -> Void) {
    let transaction = transaction ?? SignpostTransaction(signpost: SignpostID.modelUpdate)
    super.reduceModel(transaction: transaction, closure: closure)
  }

  override open func didUpdateModel(transaction: AnyTransaction?, old: M, new: M) {
    super.didUpdateModel(transaction: transaction, old: old, new: new)
    guard let transaction = transaction else {
      return
    }
    func dispatch(option: Diffing, execute: @escaping () -> Void) {
      switch option {
      case .sync:
        _queue.sync(execute: execute)
      case .async:
        _queue.async(execute: execute)
      case .none:
        return
      }
    }
    dispatch(option: diffing) {
      self._transactionIdsHistory.insert(transaction.id)
      /// The resulting dictionary won't be nested and all of the keys will be paths.
      let encodedModel: FlatEncoding.Dictionary = CodableStore.encodeFlat(model: new)
      var diffs: [FlatEncoding.KeyPath: PropertyDiff] = [:]
      for (key, value) in encodedModel {
        // The (`keyPath`, `value`) pair was not in the previous _lastModelSnapshot.
        if self._lastModelSnapshot[key] == nil {
          diffs[key] = .added(new: value)
          // The (`keyPath`, `value`) pair has changed value.
        } else if let old = self._lastModelSnapshot[key], !dynamicEqual(lhs: old, rhs: value) {
          diffs[key] = .changed(old: old, new: value)
        }
      }
      // The (`keyPath`, `value`) was removed from the _lastModelSnapshot.
      for (key, _) in self._lastModelSnapshot where encodedModel[key] == nil {
        diffs[key] = .removed
      }
      // Updates the publisher.
      self.lastTransactionDiff = TransactionDiff(transaction: transaction, diffs: diffs)
      self._lastModelSnapshot = encodedModel

      os_log(
        .debug, log: OSLog.diff, "▩ 𝘿𝙄𝙁𝙁 (%s) %s %s",
        transaction.id, transaction.actionId, diffs.storeDebugDescription(short: true))
    }
  }
  
  // MARK: - Model Encode/Decode
  
  /// Encodes the model into a dictionary.
  static public func encode<V: Encodable>(model: V) -> EncodedDictionary {
    let result = _serialize(model: model)
    return result
  }

  /// Encodes the model into a flat dictionary.
  /// The resulting dictionary won't be nested and all of the keys will be paths.
  /// e.g. `{user: {name: "John", lastname: "Appleseed"}, tokens: ["foo", "bar"]`
  /// turns into ``` {
  ///   user/name: "John",
  ///   user/lastname: "Appleseed",
  ///   tokens/0: "foo",
  ///   tokens/1: "bar"
  /// } ```
  /// - note: This is particularly useful to synchronize the model with document-based databases
  /// (e.g. Firebase).
  static public func encodeFlat<V: Encodable>(model: V) -> FlatEncoding.Dictionary {
    let result = _serialize(model: model)
    return flatten(encodedModel: result)
  }

  /// Decodes the model from a dictionary.
  static public func decode<V: Decodable>(dictionary: EncodedDictionary) -> V? {
    _deserialize(dictionary: dictionary)
  }
}

// MARK: - Helpers

/// Serialize the model passed as argument.
/// - note: If the serialization fails, an empty dictionary is returned instead.
private func _serialize<V: Encodable>(model: V) -> EncodedDictionary {
  do {
    let dictionary: [String: Any] = try DictionaryEncoder().encode(model)
    return dictionary
  } catch {
    return [:]
  }
}

/// Deserialize the dictionary and returns a store of type `S`.
/// - note: If the deserialization fails, an empty model is returned instead.
private func _deserialize<V: Decodable>(dictionary: EncodedDictionary) -> V? {
  do {
    let model = try DictionaryDecoder().decode(V.self, from: dictionary)
    return model
  } catch {
    return nil
  }
}
