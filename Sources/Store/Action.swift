import Combine
import Foundation
import os.log

public protocol ActionProtocol: Identifiable {
  associatedtype AssociatedStoreType: StoreProtocol

  /// Unique action identifier.
  /// An high level description of the action (e.g. `FETCH_USER` or `DELETE_COMMENT`)
  var id: String { get }

  /// The execution body for this action.
  /// - note: Invoke `context.operation.finish` to signal task completion.
  func reduce(context: TransactionContext<AssociatedStoreType, Self>)
}
