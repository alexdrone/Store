// Forked from alexdrone/PushID
// See LICENSE file.

import Foundation

/// Shorthand to PushID's 'make' function.
public func makePushID() -> String {
  return PushID.default.make()
}

/// ID generator that creates 20-character string identifiers with the following properties:
/// 1. They're based on timestamp so that they sort *after* any existing ids.
/// 2. They contain 72-bits of random data after the timestamp so that IDs won't collide with
/// other clients' IDs.
/// 3. They sort *lexicographically* (so the timestamp is converted to characters that will
/// sort properly).
/// 4. They're monotonically increasing. Even if you generate more than one in the same timestamp,
/// the latter ones will sort after the former ones.  We do this by using the previous random bits
/// but "incrementing" them by 1 (only in the case of a timestamp collision).
public final class PushID {
  
  public static let `default` = PushID()
  
  // MARK: Static constants
  
  /// Modeled after base64 web-safe chars, but ordered by ASCII.
  private static let ascChars = Array(
    "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz")
  
  private static let descChars = Array(ascChars.reversed())
  
  
  // MARK: State
  
  /// Timestamp of last push, used to prevent local collisions if you push twice in one ms.
  private var lastPushTime: UInt64 = 0
  
  /// We generate 72-bits of randomness which get turned into 12 characters and appended to the
  /// timestamp to prevent collisions with other clients.  We store the last characters we
  /// generated because in the event of a collision, we'll use those same characters except
  /// "incremented" by one.
  private var lastRandChars = [Int](repeating: 0, count: 12)
  
  /// For testability purposes.
  private let dateProvider: () -> Date
  
  /// Ensure the generator synchronization.
  private var lock = UnfairLock()
  
  public init(dateProvider: @escaping () -> Date = { Date() }) {
    self.dateProvider = dateProvider
  }
  
  /// Generate a new push UUID.
  public func make(ascending: Bool = true) -> String {
    let pushChars = ascending ? PushID.ascChars : PushID.descChars
    precondition(pushChars.count > 0)
    var timeStampChars = [Character](repeating: pushChars.first!, count: 8)
    
    self.lock.lock()
    
    var now = UInt64(self.dateProvider().timeIntervalSince1970 * 1000)
    let duplicateTime = (now == self.lastPushTime)
    
    self.lastPushTime = now
    
    for i in stride(from: 7, to: 0, by: -1) {
      timeStampChars[i] = pushChars[Int(now % 64)]
      now >>= 6
    }
    
    assert(now == 0, "The whole timestamp should be now converted.")
    var id = String(timeStampChars)
    
    if !duplicateTime {
      for i in 0..<12 {
        self.lastRandChars[i] = Int(64 * Double(arc4random()) / Double(UInt32.max))
      }
    } else {
      // If the timestamp hasn't changed since last push, use the same random number,
      // except incremented by 1.
      var index: Int = 0
      for i in stride(from: 11, to: 0, by: -1) {
        index = i
        guard self.lastRandChars[i] == 63 else { break }
        self.lastRandChars[i] = 0
      }
      self.lastRandChars[index] += 1
    }
    
    // Appends the random characters.
    for i in 0..<12 {
      id.append(pushChars[self.lastRandChars[i]])
    }
    assert(id.lengthOfBytes(using: .utf8) == 20, "The id lenght should be 20.")
    
    self.lock.unlock()
    return id
  }
}
