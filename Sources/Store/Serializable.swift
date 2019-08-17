import Foundation

/// A state that is encodable and decodable.
/// For the time being 'Decode' is used as json-parser.
public protocol SerializableModelType: Codable {
  init()
}

public extension SerializableModelType {
  /// Encodes the state into a dictionary.
  /// - parameter flatten: If 'true' the resulting dictionary won't be nested and all of the keys
  /// will be paths.
  func encode(flatten: Bool = false) -> [String: Any] {
    let result = serialize(model: self)
    if flatten {
      return merge(encodedModel: result)
    } else {
      return result
    }
  }

  /// Unmarshal the state from a dictionary.
  /// - note: A new empty store of type *S* is returned if the dictionary is malformed.
  static func decode(dictionary: [String: Any]) -> Self {
    return deserialize(dictionary: dictionary)
  }
}

// MARK: - Helpers

/// Serialize the model passed as argument.
/// - note: If the serialization fails, an empty dictionary is returned instead.
private func serialize<S: SerializableModelType>(model: S) -> [String: Any] {
  do {
    let dictionary: [String: Any] = try DictionaryEncoder().encode(model)
    return dictionary
  } catch {
    return [:]
  }
}

/// Deserialize the dictionary and returns a store of type *S*.
/// - note: If the deserialization fails, an empty store is returned instead.
private func deserialize<S: SerializableModelType>(dictionary: [String: Any]) -> S {
  do {
    let model = try DictionaryDecoder().decode(S.self, from: dictionary)
    return model
  } catch {
    return S()
  }
}

fileprivate enum FlattenNode {
  case dictionary(_ dictionary: [String: Any])
  case array(_ array: [Any])
}

fileprivate func flatten(
  path: String,
  node: FlattenNode,
  result: inout [String: Any]
) {
  let formattedPath = path.isEmpty ? "" : "\(path)/"
  func process(path: String, value: Any) {
    if let dictionary = value as? [String: Any] {
      flatten(path: path, node: .dictionary(dictionary), result: &result)
    }else if let array = value as? [Any] {
        flatten(path: path, node: .array(array), result: &result)
    } else {
      result[path] = value
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

/// Flatten down the dictionary into a map from 'path' to value.
public func merge(encodedModel: [String: Any]) -> [String: Any] {
  var result: [String: Any] = [:]
  flatten(path: "", node: .dictionary(encodedModel), result: &result)
  return result
}
