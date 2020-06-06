import Foundation

// MARK - FetchedProperty

public enum FetchedProperty<T: Codable, E: Codable>: Codable {
  /// The property has no yet a value.
  case uninitalized
  /// The property is being set.
  /// The property can be updated with regual progress or have `Progress.indeterminate` if the
  /// progress is unknown.
  case pending(progress: Float)
  /// The property has been fetched successfully.
  case success(value: T, etag: E)
  /// An error has occurred while fetching the property.
  case error(_ error: Error)

  /// The value if the state of this property is `success`.
  public var value: T? {
    guard case let .success(value, _) = self else { return nil }
    return value
  }

  /// The value if the state of this property is `success`.
  public var etag: E? {
    guard case let .success(_, etag) = self else { return nil }
    return etag
  }

  /// Whether the state of this property is `success`.
  public var hasValue: Bool {
    value != nil
  }

  /// Whether the state of this property is `pending`.
  public var isPending: Bool {
    switch self {
    case .pending(_): return true
    default: return false
    }
  }

  /// Whether the state of this property is `pending` and there's no progress being tracked.
  public var isIndeterminateProgress: Bool {
    progress < 0
  }

  /// If the state of this property is `pending` returns the progress, `0` otherwise.
  public var progress: Float {
    guard case let .pending(progress) = self else { return 0 }
    return max(0, progress)
  }

  /// The error if the state of this property is `error`.
  public var error: Error? {
    guard case let .error(error) = self else { return nil }
    return error
  }

  // MARK Codable

  private enum CodingKeys: String, CodingKey { case value, etag }

  /// Creates a new instance by decoding from the given decoder.
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    if let value = try? values.decode(T.self, forKey: .value),
       let etag = try? values.decode(E.self, forKey: .etag) {
      self = .success(value: value, etag: etag)
    } else {
      self = .uninitalized
    }
  }

  /// Encodes this value into the given encoder.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .success(let value, let etag):
      try? container.encode(value, forKey: .value)
      try? container.encode(etag, forKey: .etag)
    default: break
    }
  }
}

// MARK - NoEtag

/// Used for fetched properties that have no `Etag`.
public typealias NoEtag = Int

// MARK - Constants

/// Used for fetched properties that have no `Etag`.
public let noEtag = 0

/// Used for undetermined progress in `pending(progress:).`
public let indeterminateProgress: Float = -1
