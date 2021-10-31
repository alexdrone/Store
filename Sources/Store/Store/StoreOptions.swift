import Foundation
import Combine

public struct StoreOptions<S: Scheduler> {
  
  public enum SchedulingStrategy {
    /// The time the publisher should wait before publishing an element.
    case debounce(Double)
    /// The interval at which to find and emit either the most recent expressed in the time system
    /// of the scheduler.
    case throttle(Double)
    /// Events are being emitted as they're sent through the publisher.
    case none
  }
  
  /// The scheduler on which this publisher delivers elements
  public let scheduler: S
  
  /// Schedule stratey.
  public let schedulingStrategy: SchedulingStrategy
  }
