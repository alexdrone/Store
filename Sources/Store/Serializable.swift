import Foundation

/// A state that is encodable and decodable.
/// For the time being 'Decode' is used as json-parser.
public protocol SerializableModelType: ModelType, Encodable, Decodable { }

@available(iOS 13.0, macOS 10.15, *)
open class SerializableStore<S: SerializableModelType> : Store<S> { }

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

/// Flatten down the dictionary into a map from 'path' to value.
public func merge(encodedModel: [String: Any]) -> [String: Any] {
  func flatten(path: String, dictionary: [String: Any], result: inout [String: Any]) {
    let formattedPath = path.isEmpty ? "" : "\(path)/"
    for (key, value) in dictionary {
      if let nestedDictionary = value as? [String: Any] {
        flatten(path: "\(formattedPath)\(key)",
          dictionary: nestedDictionary,
          result: &result)
      } else {
        result["\(formattedPath)\(key)"] = value
      }
    }
  }
  var result: [String: Any] = [:]
  flatten(path: "", dictionary: encodedModel, result: &result)
  return result
}

