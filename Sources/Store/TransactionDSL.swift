import Combine
import Foundation
import os.log

// MARK: - Function Builder

@frozen
@_functionBuilder
public struct TransactionSequenceBuilder {
  public static func buildBlock(
    _ transactions: TransactionConvertible...
  ) -> [TransactionProtocol] {
    var result: [TransactionProtocol] = []
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

public func RunGroup(@TransactionSequenceBuilder builder: () -> [TransactionProtocol]) {
  let transactions = builder()
  for transaction in transactions {
    transaction.run(handler: nil)
  }
}

// MARK: - TransactionCollectionConvertible

public protocol TransactionConvertible {
  /// The wrapped transactions.
  var transactions: [TransactionProtocol] { get }
}

// MARK: - DSL / Concurrent

@frozen
public struct Concurrent: TransactionConvertible {
  /// The wrapped transactions.
  public let transactions: [TransactionProtocol]

  public init(@TransactionSequenceBuilder builder: () -> [TransactionProtocol]) {
    self.transactions = builder()
  }
  
  public init(transactions: [TransactionProtocol]) {
    self.transactions = transactions
  }
}

// MARK: - DSL / Throttle

@frozen
public struct Throttle: TransactionConvertible {
  /// The wrapped transactions.
  public let transactions: [TransactionProtocol]
  /// The throttle dalay.
  public let minimumDelay: TimeInterval

  public init(
    _ minimumDelay: TimeInterval,
    @TransactionSequenceBuilder builder: () -> [TransactionProtocol]
  ) {
    self.minimumDelay = minimumDelay
    self.transactions = builder()
    _throttle()
  }

  public init(_ minimumDelay: TimeInterval, transactions: [TransactionProtocol]) {
    self.minimumDelay = minimumDelay
    self.transactions = transactions
    _throttle()
  }

  @inline(__always)
  private func _throttle() {
    for transaction in transactions {
      let _ = transaction.throttle(minimumDelay)
    }
  }
}

// MARK: - DSL / Null

@frozen
public struct NullTransaction: TransactionConvertible {
  /// The wrapped transactions.
  public var transactions: [TransactionProtocol] = []
}

