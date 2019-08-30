import Foundation

public typealias EncodedDictionary = [String: Any]

/// A state that is encodable and decodable.
/// For the time being 'Decode' is used as json-parser.
public protocol SerializableModelType: Codable {
  init()
}

public extension SerializableModelType {
  /// Encodes the state into a dictionary.
  func encode() -> EncodedDictionary {
    let result = serialize(model: self)
    return result
  }

  /// Encodes the state into a dictionary.
  /// The resulting dictionary won't be nested and all of the keys will be paths.
  func encodeToFlattenDictionary() -> FlatEncoding.Dictionary {
    let result = serialize(model: self)
    return flatten(encodedModel: result)
  }

  /// Unmarshal the state from a dictionary.
  /// - note: A new empty store of type *S* is returned if the dictionary is malformed.
  static func decode(dictionary: EncodedDictionary) -> Self {
    return deserialize(dictionary: dictionary)
  }
}

// MARK: - Helpers

/// Serialize the model passed as argument.
/// - note: If the serialization fails, an empty dictionary is returned instead.
private func serialize<S: SerializableModelType>(model: S) -> EncodedDictionary {
  do {
    let dictionary: [String: Any] = try DictionaryEncoder().encode(model)
    return dictionary
  } catch {
    return [:]
  }
}

/// Deserialize the dictionary and returns a store of type *S*.
/// - note: If the deserialization fails, an empty store is returned instead.
private func deserialize<S: SerializableModelType>(dictionary: EncodedDictionary) -> S {
  do {
    let model = try DictionaryDecoder().decode(S.self, from: dictionary)
    return model
  } catch {
    return S()
  }
}
