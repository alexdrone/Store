import Foundation

public typealias FlattenEncodedDictionary = [FlattenEncodedDictionaryKeyPath: Codable?]

public struct FlattenEncodedDictionaryKeyPath: Encodable, Equatable, Hashable {
  public static let separator = "/"

  public var segments: [String]
  public var isEmpty: Bool { return segments.isEmpty }
  public var path: String {
    return segments.joined(separator: FlattenEncodedDictionaryKeyPath.separator)
  }

  /// Strips off the first segment and returns a pair consisting of the first segment and the
  /// remaining key path.
  /// Returns `nil` if the key path has no segments.
  public func pop() -> (head: String, tail: FlattenEncodedDictionaryKeyPath)? {
    guard !isEmpty else { return nil }
    var tail = segments
    let head = tail.removeFirst()
    return (head, FlattenEncodedDictionaryKeyPath(segments: tail))
  }

  public init(segments: [String]) {
    self.segments = segments
  }

  public init(_ string: String) {
    segments = string.components(separatedBy: FlattenEncodedDictionaryKeyPath.separator)
  }

  public func encode(to encoder: Encoder) throws {
    return try path.encode(to: encoder)
  }

  public var description: String {
    return path
  }
}

/// Flatten down the dictionary into a map from `path` to value.
/// e.g. `{user: {name: "John", lastname: "Appleseed"}, tokens: ["foo", "bar"]`
/// turns into ``` {
///   user/name: "John",
///   user/lastname: "Appleseed",
///   tokens/0: "foo",
///   tokens/1: "bar"
/// } ```
public func flatten(encodedModel: EncodedDictionary) -> FlattenEncodedDictionary {
  var result: FlattenEncodedDictionary = [:]
  flatten(path: "", node: .dictionary(encodedModel), result: &result)
  return result
}

// MARK: - Private

enum FlattenNode {
  case dictionary(_ dictionary: EncodedDictionary)
  case array(_ array: [Any])
}

func flatten(path: String, node: FlattenNode, result: inout FlattenEncodedDictionary) {
  let formattedPath = path.isEmpty ? "" : "\(path)\(FlattenEncodedDictionaryKeyPath.separator)"
  func process(path: String, value: Any) {
    if let dictionary = value as? [String: Any] {
      flatten(path: path, node: .dictionary(dictionary), result: &result)
    }else if let array = value as? [Any] {
        flatten(path: path, node: .array(array), result: &result)
    } else {
      result[FlattenEncodedDictionaryKeyPath(path)] = value as? Codable
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

// MARK: - PropertyDiff

@available(iOS 13.0, macOS 10.15, *)
public enum PropertyDiff: CustomStringConvertible, Encodable {
  case added(new: Codable?)
  case changed(old: Codable?, new: Codable?)
  case removed

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

@available(iOS 13.0, macOS 10.15, *)
public struct PropertyDiffSet {
  /// The set of (`keyPath`, `value`) pair that has been added/removed or changed.
  public let diffs: [FlattenEncodedDictionaryKeyPath: PropertyDiff]
  /// The transaction that caused this change set.
  public weak var transaction: AnyTransaction?
}

// MARK: - Extensions

@available(iOS 13.0, macOS 10.15, *)
extension Dictionary where Key == FlattenEncodedDictionaryKeyPath, Value == PropertyDiff {
  /// String representation of the diffed entries.
  var log: String {
    let keys = self.keys.map { $0.path }.sorted()
    var formats: [String] = []
    for key in keys {
      formats.append("\n\t\t· \(key): \(self[FlattenEncodedDictionaryKeyPath(key)]!)")
    }
    return "{\(formats.joined(separator: ", "))\n\t}"
  }
}
