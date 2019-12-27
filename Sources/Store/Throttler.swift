import Foundation

public class Throttler {
  private var executionItem: DispatchWorkItem = DispatchWorkItem(block: {})
  private var cancellationItem: DispatchWorkItem = DispatchWorkItem(block: {})
  private var previousRun: Date = Date.distantPast
  private let queue: DispatchQueue
  private let minimumDelay: TimeInterval

  public init(minimumDelay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
    self.minimumDelay = minimumDelay
    self.queue = queue
  }

  public func throttle(
    execution: @escaping () -> Void,
    cancellation: @escaping () -> Void = {}
  ) -> Void {
    // Cancel any existing work item if it has not yet executed
    executionItem.cancel()
    cancellationItem.perform()
    // Re-assign workItem with the new block task, resetting the previousRun time when it executes
    executionItem = DispatchWorkItem() { [weak self] in
      self?.previousRun = Date()
      execution()
    }
    cancellationItem = DispatchWorkItem() { [weak self] in
      cancellation()
    }
    // If the time since the previous run is more than the required minimum delay
    // => execute the workItem immediately
    // else
    // => delay the workItem execution by the minimum delay time
    let delay = previousRun.timeIntervalSinceNow > minimumDelay ? 0 : minimumDelay
    queue.asyncAfter(deadline: .now() + Double(delay), execute: executionItem)
  }
}
