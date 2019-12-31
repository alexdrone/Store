import Combine
import Foundation
import os.log

// MARK: - Protocol

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public protocol Middleware: class {
  /// A transaction has changed its state.
  func onTransactionStateChange(_ transaction: TransactionProtocol)
}

// MARK: - Logger

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public final class LoggerMiddleware: Middleware {
  /// Syncronizes the access to the middleware.
  private var _lock = SpinLock()

  /// The transactions start time (in µs).
  private var _transactionStartNanos: [String: UInt64] = [:]

  public init() {}

  /// Logs the transaction identifier, the action name and its current state.
  public func onTransactionStateChange(_ transaction: TransactionProtocol) {
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
      os_log(.info, log: OSLog.primary, "▩ (%s) %s [%fs ms]", id, name, millis)
      _transactionStartNanos[transaction.id] = nil
    case .canceled:
      os_log(.info, log: OSLog.primary, "▩ (%s) %s [✖ cancelled]", id, name)
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

// MARK: - Log Subsystems

@available(iOS 12.0, macOS 10.14, watchOS 3.0, tvOS 13.0, *)
extension OSLog {
  public static let primary = OSLog(subsystem: "io.store.StoreService", category: "primary")
  public static let diff = OSLog(subsystem: "io.store.StoreService", category: "diff")
}
