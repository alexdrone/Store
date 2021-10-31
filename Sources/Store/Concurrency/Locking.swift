import Foundation

// MARK: - Locking

public protocol Locking {
  /// Create a new lock.
  init()

  /// Acquire the lock.
  ///
  /// Whenever possible, consider using `withLock` instead of this method and
  /// `unlock`, to simplify lock handling.
  func lock()
  
  /// Release the lock.
  ///
  /// Whenver possible, consider using `withLock` instead of this method and
  /// `lock`, to simplify lock handling.
  func unlock()
}

extension Locking {
  /// Acquire the lock for the duration of the given block.
  ///
  /// This convenience method should be preferred to `lock` and `unlock` in
  /// most situations, as it ensures that the lock will be released regardless
  /// of how `body` exits.
  @inlinable
  public func withLock<T>(_ body: () throws -> T) rethrows -> T {
    defer {
      unlock()
    }
    lock()
    return try body()
  }
  
  /// Specialise Void return (for performance).
  @inlinable
  public func withLockVoid(_ body: () throws -> Void) rethrows -> Void {
    try self.withLock(body)
  }
  
  /// Async variant.
  @inlinable
  public func withLock<T>(_ body: () async throws -> T) async rethrows -> T {
    defer {
      unlock()
    }
    lock()
    return try await body()
  }
}

// MARK: - Foundation Locks

/// An object that coordinates the operation of multiple threads of execution within the
/// same application.
extension NSLock: Locking { }

/// A lock that may be acquired multiple times by the same thread without causing a deadlock.
extension NSRecursiveLock: Locking { }

/// A lock that multiple applications on multiple hosts can use to restrict access to some
/// shared resource, such as a file.
extension NSConditionLock: Locking { }

// MARK: - Mutex

/// A mechanism that enforces limits on access to a resource when there are many threads
/// of execution.
public final class Mutex: Locking {
  private var mutex: pthread_mutex_t = {
    var mutex = pthread_mutex_t()
    pthread_mutex_init(&mutex, nil)
    return mutex
  }()
  
  public init() {}

  public func lock() {
    pthread_mutex_lock(&mutex)
  }

  public func unlock() {
    pthread_mutex_unlock(&mutex)
  }
}

// MARK: - UnfairLock

/// A low-level lock that allows waiters to block efficiently on contention.
public final class UnfairLock: Locking {
  private var unfairLock = os_unfair_lock_s()
  
  public init() {}

  public func lock() {
    os_unfair_lock_lock(&unfairLock)
  }

  public func unlock() {
    os_unfair_lock_unlock(&unfairLock)
  }
}

// MARK: - ReadersWriterLock

/// A readers-writer lock provided by the platform implementation of the POSIX Threads standard.
/// Read more: https://en.wikipedia.org/wiki/POSIX_Threads
public final class ReadersWriterLock: @unchecked Sendable {
  private var rwlock: UnsafeMutablePointer<pthread_rwlock_t>
  
  public init() {
    rwlock = UnsafeMutablePointer.allocate(capacity: 1)
    assert(pthread_rwlock_init(rwlock, nil) == 0)
  }
  
  deinit {
    assert(pthread_rwlock_destroy(rwlock) == 0)
    rwlock.deinitialize(count: 1)
    rwlock.deallocate()
  }
  
  public func withReadLock<T>(body: () throws -> T) rethrows -> T {
    pthread_rwlock_rdlock(rwlock)
    defer {
      pthread_rwlock_unlock(rwlock)
    }
    return try body()
  }
  
  public func withWriteLock<T>(body: () throws -> T) rethrows -> T {
    pthread_rwlock_wrlock(rwlock)
    defer {
      pthread_rwlock_unlock(rwlock)
    }
    return try body()
  }
}
