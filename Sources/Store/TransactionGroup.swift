import Combine
import Foundation
import os.log

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@_functionBuilder
public struct TransactionSequenceBuilder {
  public static func buildBlock(_ transactions: TransactionConvertible...
  ) -> [AnyTransaction] {
    var result: [AnyTransaction] = []
    var dependencies: TransactionConvertible = NullTransaction()
    for tis in transactions {
      for transaction in tis.transactions {
        transaction.depend(on: dependencies.transactions)
        result.append(transaction)
      }
      dependencies = tis
    }
    return result
  }
}

// MARK: - TransactionCollectionConvertible

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public protocol TransactionConvertible {
  /// The wrapped transactions.
  var transactions: [AnyTransaction] { get }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct Concurrent: TransactionConvertible {
  /// The wrapped transactions.
  public let transactions: [AnyTransaction]

  public init(@TransactionSequenceBuilder builder: () -> [AnyTransaction]) {
    self.transactions = builder()
  }
  
  public init(transactions: [AnyTransaction]) {
    self.transactions = transactions
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct Throttle: TransactionConvertible {
  /// The wrapped transactions.
  public let transactions: [AnyTransaction]
  /// The throttle dalay.
  public let  minimumDelay: TimeInterval

  public init(
    _ minimumDelay: TimeInterval,
    @TransactionSequenceBuilder builder: () -> [AnyTransaction]
  ) {
    self.minimumDelay = minimumDelay
    self.transactions = builder()
    _throttle()
  }

  public init(
     _ minimumDelay: TimeInterval,
     transactions: [AnyTransaction]
  ) {
    self.minimumDelay = minimumDelay
    self.transactions = transactions
    _throttle()
  }

  private func _throttle() {
    for transaction in transactions {
      let _ = transaction.throttle(minimumDelay)
    }
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct NullTransaction: TransactionConvertible {
  /// The wrapped transactions.
  public var transactions: [AnyTransaction] = []
}

