import Foundation

/// This function is used to copy the values of all enumerable own properties from one or more
/// source struct to a target struct.
/// - returns: The target struct.
/// - note: This is analogous to Object.assign in Javascript and should be used to update
/// immutabel model types.
@inlinable @inline(__always)
public func assign<T>(_ value: T, changes: (inout T) -> Void) -> T {
  guard Mirror(reflecting: value).displayStyle == .struct else {
    fatalError("'value' must be a struct.")
  }
  var copy = value
  changes(&copy)
  return copy
}

// MARK: @Atomic

@available(iOS 2.0, OSX 10.0, tvOS 9.0, watchOS 2.0, *)
@frozen
@propertyWrapper
public struct Atomic<T> {
  private let _queue = DispatchQueue(label: "Atomic write access queue", attributes: .concurrent)
  private var _storage: T

  public init(wrappedValue value: T) {
    self._storage = value
  }

  public var wrappedValue: T {
    get { return _queue.sync { _storage } }
    set { _queue.sync(flags: .barrier) { _storage = newValue } }
  }

  /// Atomically mutate the variable (read-modify-write).
  /// - parameter action: A closure executed with atomic in-out access to the wrapped property.
  public mutating func mutate(_ mutation: (inout T) throws -> Void) rethrows {
    return try _queue.sync(flags: .barrier) {
      try mutation(&_storage)
    }
  }
}

// MARK: Spinlock Implementation

@frozen
@usableFromInline
struct SpinLock {
  private var _spin = OS_SPINLOCK_INIT
  private var _unfair = os_unfair_lock_s()

  /// Locks a spinlock. Although the lock operation spins, it employs various strategies to back
  /// off if the lock is held.
  @inline(__always)
  mutating func lock() {
    if #available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
      os_unfair_lock_lock(&_unfair)
    } else {
      OSSpinLockLock(&_spin)
    }
  }

  /// Unlocks a spinlock.
  @inline(__always)
  mutating func unlock() {
    if #available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
      os_unfair_lock_unlock(&_unfair)
    } else {
      OSSpinLockUnlock(&_spin)
    }
  }
}

