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

struct SpinLock {
  private var _spin = OS_SPINLOCK_INIT
  private var _unfair = os_unfair_lock_s()

  /// Locks a spinlock. Although the lock operation spins, it employs various strategies to back
  /// off if the lock is held.
  mutating func lock() {
    if #available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
      os_unfair_lock_lock(&_unfair)
    } else {
      OSSpinLockLock(&_spin)
    }
  }

  /// Unlocks a spinlock.
  mutating func unlock() {
    if #available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
      os_unfair_lock_unlock(&_unfair)
    } else {
      OSSpinLockUnlock(&_spin)
    }
  }
}

