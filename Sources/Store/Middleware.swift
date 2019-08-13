import Foundation
import Combine

@available(iOS 13.0, macOS 10.15, *)
public protocol MiddlewareType: class {
  /// A transaction has changed its state.
  func onTransactionStateChange(_ transaction: AnyTransaction)
}

@available(iOS 13.0, macOS 10.15, *)
public final class LoggerMiddleware: MiddlewareType {
  /// Syncronizes the access to the middleware.
  private let lock = Lock()
  /// The transactions start time (in µs).
  private var transactionStartNanos: [String: UInt64] = [:]

  /// Logs the transaction identifier, the action name and its current state.
  public func onTransactionStateChange(_ transaction: AnyTransaction) {
    lock.lock()
    let id = transaction.transactionIdentifier
    let name = transaction.identifier
    switch transaction.state {
    case .pending:
      break
    case .started:
      transactionStartNanos[transaction.transactionIdentifier] = nanos()
    case .completed:
      let prev = transactionStartNanos[transaction.transactionIdentifier]
      let time = prev != nil ? nanos() - prev! : 0
      let millis = Float(time)/1000000
      print("▩ (\(id)) \(name) [\(millis) ms]")
    }
    lock.unlock()
  }

  /// Return the current time in µs.
  private func nanos() -> UInt64 {
    var info = mach_timebase_info()
    guard mach_timebase_info(&info) == KERN_SUCCESS else { return 0 }
    let currentTime = mach_absolute_time()
    let nanos = currentTime * UInt64(info.numer) / UInt64(info.denom)
    return nanos
  }
}

@available(iOS 13.0, macOS 10.15, *)
public final class IncrementalDiffMiddleware: MiddlewareType {
  public struct Diff: CustomStringConvertible {
    public enum ChangeType {
      case added
      case changed
      case removed
    }
    /// The (`keyPath`, `value`) pair has been added/removed or changed as a result of this
    /// last transaction.
    public let type: ChangeType
    /// The new value if `added` is `changed` or `type`, the old value otherwise.
    public let value: Any
    /// Human readable description.
    public var description: String {
      return "<\(type) ⇒ \(value)>"
    }
  }
  public struct DiffSet {
    /// The set of (`keyPath`, `value`) pair that has been added/removed or changed.
    public let diffs: [String: Diff]
    /// The transaction that caused this change set.
    public weak var transaction: AnyTransaction?
  }

  /// Publishes a stream with the latest model changes.
  @Published public var diffs: DiffSet = DiffSet(diffs: [:], transaction: nil)
  /// The previous state of the model.
  private var snapshot: [String: Any] = [:]
  /// Syncronizes the access to the middleware.
  private let lock = Lock()
  /// All of the transactions that have already been diffed.
  private var transactions = Set<String>()

  public init(store: StoreType) {
    guard let model = store.modelRef as? SerializableModelType else {
      return
    }
    snapshot = model.encode(flatten: true)
  }

  public func onTransactionStateChange(_ transaction: AnyTransaction) {
    guard
      // The model must be serializable.
      let model = transaction.opaqueStoreRef?.modelRef as? SerializableModelType,
      // The transaction was not diffed already.
      !transactions.contains(transaction.transactionIdentifier),
      // The state of the transaction is `completed`.
      transaction.state == .completed else {
      return
    }

    lock.lock()
    /// The resulting dictionary won't be nested and all of the keys will be paths.
    let encodedModel = model.encode(flatten: true)
    var diffs: [String: Diff] = [:]

    for (key, value) in encodedModel {
      // The (`keyPath`, `value`) pair was not in the previous snapshot.
      if snapshot[key] == nil {
        diffs[key] = Diff(type: .added, value: value)
      // The (`keyPath`, `value`) pair has changed value.
      } else if let lhs = snapshot[key], !dynamicEqual(lhs: lhs, rhs: value) {
        diffs[key] = Diff(type: .changed, value: value)
      }
    }
    // The (`keyPath`, `value`) was removed from the snapshot.
    for (key, value) in snapshot where encodedModel[key] == nil {
      diffs[key] = Diff(type: .removed, value: value)
    }

    // Updates the publisher.
    self.diffs = DiffSet(diffs: diffs, transaction: transaction)
    self.snapshot = encodedModel

    print("Δ (\(transaction.transactionIdentifier)) \(diffs)")
    lock.unlock()
  }

}
