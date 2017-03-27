import Foundation

public protocol ActionType { }

public struct Action<A: ActionType> {

  /** The action associated to this status object. */
  let action: A

  /** The state of the action. */
  let state: ActionState

  /** The last time the operation was being executed. */
  let lastRun: TimeInterval

  /** Additional info passed from the action. */
  let userInfo: [String: Any]?
}

public enum ActionState {
  case notStarted
  case inProgress
  case failed
  case finished
}
