import Foundation
import Logging
#if canImport(Combine)
import Combine
#else
import OpenCombine
import OpenCombineDispatch
#endif

/// Middleware objects are used to intercept transactions running on the store and implement some
/// specific logic triggered by them."Logging"
/// *Logging*, *undo/redo* and *local/remote database synchronization* are a good examples of when
/// a middleware could be necessary.
public protocol Middleware: class {
  
  /// This function is called whenever a running transaction changes its state.
  func onTransactionStateChange(_ transaction: AnyTransaction)
}

// MARK: - Logger

/// The infra logger.
/// The output stream can be redirected.
public let logger = Logger(label: "io.store")

public final class LoggerMiddleware: Middleware {
  
  /// Syncronizes the access to the middleware.
  private var _lock = SpinLock()
  /// The transactions start time (in µs).
  private var _transactionStartNanos: [String: UInt64] = [:]

  public init() {}

  /// Logs the transaction identifier, the action name and its current state.
  public func onTransactionStateChange(_ transaction: AnyTransaction) {
    _lock.lock()
    let id = transaction.id
    let name = transaction.actionId
    switch transaction.state {
    case .pending:
      break
    case .started:
      _transactionStartNanos[transaction.id] = _nanos()
    case .completed:
      guard let prev = _transactionStartNanos[transaction.id] else { break }
      let time = _nanos() - prev
      let millis = Float(time)/1_000_000
      logger.info("▩ \(id) \(name) [\(millis)) ms]")
      _transactionStartNanos[transaction.id] = nil
    case .canceled:
      logger.info("▩ \(id) \(name) [✖ cancelled]")
      _transactionStartNanos[transaction.id] = nil
    }
    _lock.unlock()
  }

  /// Return the current time in µs.
  private func _nanos() -> UInt64 {
    var info = mach_timebase_info()
    guard mach_timebase_info(&info) == KERN_SUCCESS else { return 0 }
    let currentTime = mach_absolute_time()
    let nanos = currentTime * UInt64(info.numer) / UInt64(info.denom)
    return nanos
  }
}
