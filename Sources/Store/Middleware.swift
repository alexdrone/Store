import Foundation
import Combine

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

  public init() { }

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
      let prev = transactionStartNanos[transaction.id]
      let time = prev != nil ? nanos() - prev! : 0
      let millis = Float(time)/1000000
      print("▩ 𝙄𝙉𝙁𝙊 (\(id)) \(name) [\(millis) ms]")
    case .canceled:
      print("▩ 𝙄𝙉𝙁𝙊 (\(id)) \(name) [✖ CANCELED]")

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
