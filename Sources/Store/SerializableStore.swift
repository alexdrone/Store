import Combine
import Foundation
import os.log

// MARK: - SerializableStore

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
open class SerializableStore<M: SerializableModelType>: Store<M> {
  /// Transaction diffing options.
  public enum TransactionDiffStrategy {
    /// Does not compute any diff.
    case none

    /// Computes the diff synchrously right after the transaction has completed.
    case sync

    /// Computes the diff asynchrously (in a serial queue) when transaction is completed.
    case async
  }

  /// Publishes a stream with the model changes caused by the last transaction.
  @Published public var lastTransactionDiff: TransactionDiff = TransactionDiff(
    transaction: SignpostTransaction(singpost: Signpost.prior),
    diffs: [:])

  /// Where the diffing routine should be dispatched.
  public let transactionDiffStrategy: TransactionDiffStrategy

  /// Serial queue used to run the diffing routine.
  private let queue = DispatchQueue(label: "io.store.serializable")

  /// Set of `transaction.id` for all of the transaction that have run of this store.
  private var transactionIdsHistory = Set<String>()

  /// Last serialized snapshot for the model.
  private var lastModelSnapshot: [FlatEncoding.KeyPath: Codable?] = [:]

  public init(model: M, diffing: TransactionDiffStrategy = .async) {
    self.transactionDiffStrategy = diffing
    super.init(model: model)
    self.lastModelSnapshot = model.encodeFlatDictionary()
  }

  override open func reduceModel(transaction: AnyTransaction?, closure: (inout M) -> (Void)) {
    let transaction = transaction ?? SignpostTransaction(singpost: Signpost.modelUpdate)
    super.reduceModel(transaction: transaction, closure: closure)
  }

  override open func didUpdateModel(transaction: AnyTransaction?, old: M, new: M) {
    guard let transaction = transaction else {
      return
    }
    func dispatch(option: TransactionDiffStrategy, execute: @escaping () -> Void) {
      switch option {
      case .sync:
        queue.sync(execute: execute)
      case .async:
        queue.async(execute: execute)
      case .none:
        return
      }
    }
    dispatch(option: transactionDiffStrategy) {
      self.transactionIdsHistory.insert(transaction.id)
      /// The resulting dictionary won't be nested and all of the keys will be paths.
      let encodedModel: FlatEncoding.Dictionary = new.encodeFlatDictionary()
      var diffs: [FlatEncoding.KeyPath: PropertyDiff] = [:]
      for (key, value) in encodedModel {
        // The (`keyPath`, `value`) pair was not in the previous lastModelSnapshot.
        if self.lastModelSnapshot[key] == nil {
          diffs[key] = .added(new: value)
          // The (`keyPath`, `value`) pair has changed value.
        } else if let old = self.lastModelSnapshot[key], !dynamicEqual(lhs: old, rhs: value) {
          diffs[key] = .changed(old: old, new: value)
        }
      }
      // The (`keyPath`, `value`) was removed from the lastModelSnapshot.
      for (key, _) in self.lastModelSnapshot where encodedModel[key] == nil {
        diffs[key] = .removed
      }
      // Updates the publisher.
      self.lastTransactionDiff = TransactionDiff(transaction: transaction, diffs: diffs)
      self.lastModelSnapshot = encodedModel

      os_log(
        .debug, log: OSLog.diff, "▩ 𝘿𝙄𝙁𝙁 (%s) %s %s",
        transaction.id, transaction.actionId, diffs.storeDebugDecription(short: true))
    }
  }
}

// MARK: - SerializableModelType

public typealias EncodedDictionary = [String: Any]

public protocol SerializableModelType: Codable {
  init()
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
extension SerializableModelType {
  /// Encodes the model into a dictionary.
  public func encode() -> EncodedDictionary {
    let result = serialize(model: self)
    return result
  }

  /// Encodes the state into a dictionary.
  /// The resulting dictionary won't be nested and all of the keys will be paths.
  /// e.g. `{user: {name: "John", lastname: "Appleseed"}, tokens: ["foo", "bar"]`
  /// turns into ``` {
  ///   user/name: "John",
  ///   user/lastname: "Appleseed",
  ///   tokens/0: "foo",
  ///   tokens/1: "bar"
  /// } ```
  public func encodeFlatDictionary() -> FlatEncoding.Dictionary {
    let result = serialize(model: self)
    return flatten(encodedModel: result)
  }

  /// Decodes the model from a dictionary.
  public static func decode(dictionary: EncodedDictionary) -> Self {
    return deserialize(dictionary: dictionary)
  }
}

// MARK: - Helpers

/// Serialize the model passed as argument.
/// - note: If the serialization fails, an empty dictionary is returned instead.
private func serialize<S: SerializableModelType>(model: S) -> EncodedDictionary {
  do {
    let dictionary: [String: Any] = try DictionaryEncoder().encode(model)
    return dictionary
  } catch {
    return [:]
  }
}

/// Deserialize the dictionary and returns a store of type `S`.
/// - note: If the deserialization fails, an empty model is returned instead.
private func deserialize<S: SerializableModelType>(dictionary: EncodedDictionary) -> S {
  do {
    let model = try DictionaryDecoder().decode(S.self, from: dictionary)
    return model
  } catch {
    return S()
  }
}
