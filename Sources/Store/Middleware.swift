import Combine
import Foundation
import os.log

// MARK: - Protocol

@available(iOS 13.0, macOS 10.15, *)
public protocol MiddlewareType: class {
  /// A transaction has changed its state.
  func onTransactionStateChange(_ transaction: AnyTransaction)
}

// MARK: - Logger

@available(iOS 13.0, macOS 10.15, *)
public final class LoggerMiddleware: MiddlewareType {
  /// Syncronizes the access to the middleware.
  private let lock = Lock()

  /// The transactions start time (in µs).
  private var transactionStartNanos: [String: UInt64] = [:]

  public init() {}

  /// Logs the transaction identifier, the action name and its current state.
  public func onTransactionStateChange(_ transaction: AnyTransaction) {
    lock.lock()
    let id = transaction.id
    let name = transaction.actionId
    switch transaction.state {
    case .pending:
      break
    case .started:
      transactionStartNanos[transaction.id] = nanos()
    case .completed:
      guard let prev = transactionStartNanos[transaction.id] else { break }
      let time = nanos() - prev
      let millis = Float(time)/1_000_000
      os_log(.info, log: OSLog.primary, "▩ (%s) %s [%fs ms]", id, name, millis)
      transactionStartNanos[transaction.id] = nil
    case .canceled:
      os_log(.info, log: OSLog.primary, "▩ (%s) %s [✖ cancelled]", id, name)
      transactionStartNanos[transaction.id] = nil
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

// MARK: - Log Subsystems

@available(iOS 10.0, macOS 10.12, watchOS 3.0, *)
extension OSLog {
  public static let primary = OSLog(subsystem: "io.store.StoreService", category: "primary")
  public static let diff = OSLog(subsystem: "io.store.StoreService", category: "diff")
}
