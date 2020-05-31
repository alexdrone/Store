import Foundation

public class Throttler {
  private var _executionItem = DispatchWorkItem(block: {})
  private var _cancellationItem = DispatchWorkItem(block: {})
  private var _previousRun = Date.distantPast
  private let _queue: DispatchQueue
  private let _minimumDelay: TimeInterval

  public init(minimumDelay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
    self._minimumDelay = minimumDelay
    self._queue = queue
  }

  public func throttle(
    execution: @escaping () -> Void,
    cancellation: @escaping () -> Void = {}
  ) -> Void {
    // Cancel any existing work item if it has not yet executed
    _executionItem.cancel()
    _cancellationItem.perform()
    // Re-assign workItem with the new block task, resetting the previousRun time when it executes
    _executionItem = DispatchWorkItem() { [weak self] in
      self?._previousRun = Date()
      execution()
    }
    _cancellationItem = DispatchWorkItem() {
      cancellation()
    }
    // If the time since the previous run is more than the required minimum delay
    // { execute the workItem immediately }  else
    // { delay the workItem execution by the minimum delay time }
    let delay = _previousRun.timeIntervalSinceNow > _minimumDelay ? 0 : _minimumDelay
    _queue.asyncAfter(deadline: .now() + Double(delay), execute: _executionItem)
  }
}
