import Foundation

/// A collection of changes associated to a transaction.
@available(iOS 13.0, macOS 10.15, *)
public struct TransactionDiff {
  /// The set of (`path`, `value`) that has been **added**/**removed**/**changed**.
  ///
  /// e.g. ``` {
  ///   user/name: <added ⇒ "John">,
  ///   user/lastname: <removed>,
  ///   tokens/1:  <changed ⇒ "Bar">,
  /// } ```
  public let diffs: [FlatEncoding.KeyPath: PropertyDiff]
  /// The identifier of the transaction that caused this change.
  public let transactionId: String
  /// The action that caused this change.
  public let actionId: String
  /// Reference to the transaction that cause this change.
  public private(set) weak var transaction: AnyTransaction?
  /// Returns the `diffs` map encoded as **JSON** data.
  public var json: Data {
    return (try? sharedJSONEncoder.encode(diffs)) ?? Data()
  }
  
  public init(transaction: AnyTransaction, diffs: [FlatEncoding.KeyPath: PropertyDiff]) {
    self.transaction = transaction
    self.diffs = diffs
    self.transactionId = transaction.id
    self.actionId = transaction.actionId
  }
}

/// Represent a property change.
/// A change can be an **addition**, a **removal** or a **value change**.
@available(iOS 13.0, macOS 10.15, *)
public enum PropertyDiff {
  case added(new: Codable?)
  case changed(old: Codable?, new: Codable?)
  case removed
}

/// Flatten down the dictionary into a path/value map.
/// e.g. `{user: {name: "John", lastname: "Appleseed"}, tokens: ["foo", "bar"]`
/// turns into ``` {
///   user/name: "John",
///   user/lastname: "Appleseed",
///   tokens/0: "foo",
///   tokens/1: "bar"
/// } ```
public func flatten(encodedModel: EncodedDictionary) -> FlatEncoding.Dictionary {
  var result: FlatEncoding.Dictionary = [:]
  FlatEncoding.flatten(path: "", node: .dictionary(encodedModel), result: &result)
  return result
}

// MARK: - Internal

public struct FlatEncoding {
  /// A flat non-nested dictionary.
  /// This representation is very efficient for object diffing.
  /// - note: Arrays are represented by indices in the path.
  /// e.g. ``` {
  ///   user/name: "John",
  ///   user/lastname: "Appleseed",
  ///   tokens/0: "foo",
  ///   tokens/1: "bar"
  /// } ```
  public typealias Dictionary = [KeyPath: Codable?]

  /// Represent a path in a `FlatEncoding` dictionary.
  public struct KeyPath: Encodable, Equatable, Hashable {
    /// KeyPath components separator.
    /// e.g. `user/address/street` or `tokens/0`.
    static let separator = "/"
    /// All of the individual components of this KeyPath.
    public var segments: [String]
    /// Whether this is an empty KeyPath or not.
    public var isEmpty: Bool {
      return segments.isEmpty
    }
    /// The raw string for this KeyPath.
    public let path: String

    /// Strips off the first segment and returns a pair consisting of the first segment and the
    /// remaining key path.
    /// Returns `nil` if the key path has no segments.
    public func pop() -> (head: String, tail: KeyPath)? {
      guard !isEmpty else { return nil }
      var tail = segments
      let head = tail.removeFirst()
      return (head, KeyPath(segments: tail))
    }

    /// Construct a new KeyPath from a array of components.
    public init(segments: [String]) {
      self.segments = segments
      self.path = segments.joined(separator: KeyPath.separator)
    }

    /// Constructs a new FlatEncoding KeyPath from a given string.
    /// - note: Returns `nil` if the string is in not in the format `PATH(/PATH)*` where `PATH` is
    /// a valid descriptor, like for example: `foo`, `foo/bar`, `foo/1/bar`.
    public init?(_ string: String) {
      guard string.range(
        of: "(([a-zA-Z0-9])+(\\/?))*",
        options: [.regularExpression, .anchored]) != nil else {
        return nil
      }
      path = string
      segments = string.components(separatedBy: KeyPath.separator)
    }

    /// Encodes this value into the given encoder.
    public func encode(to encoder: Encoder) throws {
      return try path.encode(to: encoder)
    }

    /// The raw string for this KeyPath.
    public var description: String {
      return path
    }
  }

  // MARK: - Private

  /// Intermediate dictionary represntation for `EncodedDictionary` ⇒ `FlatEncoding.Dictionary`
  fileprivate enum Node {
    case dictionary(_ dictionary: EncodedDictionary)
    case array(_ array: [Any])
  }

  /// Private recursive flatten method.
  /// - note: See `flatten(encodedModel:)`.
  fileprivate static func flatten(path: String, node: Node, result: inout Dictionary) {
    let formattedPath = path.isEmpty ? "" : "\(path)\(KeyPath.separator)"
    func process(path: String, value: Any) {
      if let dictionary = value as? [String: Any] {
        flatten(path: path, node: .dictionary(dictionary), result: &result)
      } else if let array = value as? [Any] {
          flatten(path: path, node: .array(array), result: &result)
      } else {
        guard let keyPath = KeyPath(path) else {
          print("warning: Malformed FlatEncoding keypath: \(path).")
          return
        }
        result[keyPath] = value as? Codable
      }
    }
    switch node {
    case .dictionary(let dictionary):
      for (key, value) in dictionary {
        process(path: "\(formattedPath)\(key)", value: value)
      }
    case .array(let array):
      for (index, value) in array.enumerated() {
        process(path: "\(formattedPath)\(index)", value: value)
      }
    }
  }
}

/// Shared **JSON** Encoder.
fileprivate let sharedJSONEncoder = JSONEncoder()

// MARK: - PropertyDiff

@available(iOS 13.0, macOS 10.15, *)
extension PropertyDiff: CustomStringConvertible, Encodable {

  public var description: String {
    switch self {
    case .added(let new):
      return "<added ⇒ \(new ?? "null")>"
    case .changed(let old, let new):
      return "<changed ⇒ (old: \(old ?? "null"), new: \(new ?? "null"))>"
    case .removed:
      return "<removed>"
    }
  }

  public var value: Any? {
    switch self {
    case .added(let new):
      return new
    case .changed(_, let new):
      return new
    case .removed:
      return nil
    }
  }

  /// Encodes this value into the given encoder.
  public func encode(to encoder: Encoder) throws {
    switch self {
    case .added(let new):
      guard let value = new else { return }
      try value.encode(to: encoder)
    case .changed(_, let new):
      guard let value = new else { return }
      try value.encode(to: encoder)
    case .removed:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    }
  }
}

// MARK: - Extensions

@available(iOS 13.0, macOS 10.15, *)
extension Dictionary where Key == FlatEncoding.KeyPath, Value == PropertyDiff {
  /// String representation of the diffed entries.
  var log: String {
    let keys = self.keys.map { $0.path }.sorted()
    var formats: [String] = []
    for key in keys {
      formats.append("\n\t\t· \(key): \(self[FlatEncoding.KeyPath(key)!]!)")
    }
    return "{\(formats.joined(separator: ", "))\n\t}"
  }
}
