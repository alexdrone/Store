import Foundation

/// This function is used to copy the values of all enumerable own properties from one or more
/// source struct to a target struct.
/// - returns: The target struct.
/// - note: This is analogous to Object.assign in Javascript and should be used to update
/// immutabel model types.
@inlinable @inline(__always)
public func assign<T>(_ value: T, changes: (inout T) -> Void) -> T {
  var copy = value
  changes(&copy)
  return copy
}

// MARK: Spinlock Implementation

/// Low-level lock that allows waiters to block efficiently on contention.
/// This lock must be unlocked from the same thread that locked it, attempts to unlock from a
/// different thread will cause an assertion aborting the process.
/// This lock must not be accessed from multiple processes or threads via shared or multiply-mapped
/// memory, the lock implementation relies on the address of the lock value and owning process.
struct UnfairLock {
  private var unfair = os_unfair_lock_s()

  /// Locks an `os_unfair_lock`.
  mutating func lock() {
    os_unfair_lock_lock(&unfair)

  }

  /// Unlocks an `os_unfair_lock`.
  mutating func unlock() {
    os_unfair_lock_unlock(&unfair)
  }
}

