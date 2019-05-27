import Foundation

/// Actions should conform to this protocol and typically are implemented through *enums* e.g.
///
///     enum CounterAction: ActionType { case increase(amount: Int), case decrease }
///
public protocol ActionType { }

public struct Action<A: ActionType> {
  /// The action associated to this status object.
  /// -note: Typically an extensible enum.
  public let action: A
  /// The state of the action.
  public let model: ActionState
  /// The last time the operation was being executed.
  public let lastRun: TimeInterval
  /// Additional info passed from the action.
  /// - note: Don't use this field to model action arguments.
  public let userInfo: [String: Any]?
}

public enum ActionState {
  /// The action has not yet started.
  case notStarted
  /// The action is being executed right now.
  case inProgress
  /// The action failed its execution.
  case failed
  /// The action has finished and it is now disposed.
  case finished
}
