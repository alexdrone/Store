import Foundation
import os.log

@available(iOS 13.0, macOS 10.15, *)
public extension OSLog {
  static let primary = OSLog(subsystem: "io.store.StoreService", category: "primary")
  static let diff = OSLog(subsystem: "io.store.StoreService", category: "diff")
}
