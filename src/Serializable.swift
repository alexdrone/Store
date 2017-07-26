import Foundation

open class SerializableStore<S: SerializableModelType, A: SerializableActionType> : Store<S, A> {

}

/// Specialization for the 'ActionType'.
public protocol SerializableActionType: ActionType {

  /// Action dispatched whenever the state is being unmarshalled and injected.
  static var injectAction: SerializableActionType { get }

  /// Whether this action is the one marked for state deserialization.
  var isInjectAction: Bool { get }
}

/// A state that is encodable and decodable.
/// For the time being 'Decode' is used as json-parser.
public protocol SerializableModelType: ModelType, Decodable { }

public extension SerializableModelType {

  /// Encodes the state into a dictionary.
  public func encode(flatten: Bool = false) -> [String: Any] {
    let result = serialize(model: self)
    if flatten {
      return merge(encodedModel: result)
    } else {
      return result
    }
  }

  /// Unmarshal the state from a dictionary
  public static func decode(dictionary: [String: Any]) -> Self {
    return deserialize(dictionary: dictionary)
  }

  /// Infer the state target.
  public func decoder() -> ([String: Any]) -> ModelType {
    return { dictionary in
      do {
        let model: Self = try decode(dictionary: dictionary)
        return model
      } catch {
        return Self()
      }
    }
  }
}

fileprivate func serialize(model: ModelType) -> [String: Any] {
  do {
    return try encode(model)
  } catch {
    return [:]
  }
}

fileprivate func deserialize<S: SerializableModelType>(dictionary: [String: Any]) -> S {
  do {
    return try decode(dictionary: dictionary)
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

