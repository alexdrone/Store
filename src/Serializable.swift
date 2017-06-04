import Foundation

open class SerializableStore<S: SerializableStateType, A: SerializableActionType> : Store<S, A> {

}

/** Specialization for the 'ActionType'. */
public protocol SerializableActionType: ActionType {

  /** Action dispatched whenever the state is being unmarshalled and injected. */
  static var injectAction: SerializableActionType { get }

  /** Whether this action is the one marked for state deserialization. */
  var isInjectAction: Bool { get }
}

/** A state that is encodable and decodable.
 *  For the time being 'Decode' is used as json-parser.
 */
public protocol SerializableStateType: StateType, Decodable { }

public extension SerializableStateType {

  /** Encodes the state into a dictionary. */
  public func encode(flatten: Bool = false) -> [String: Any] {
    let result = serialize(state: self)
    if flatten {
      return merge(encodedState: result)
    } else {
      return result
    }
  }

  /** Unmarshal the state from a dictionary */
  public static func decode(dictionary: [String: Any]) -> Self {
    return deserialize(dictionary: dictionary)
  }

  /** Infer the state target. */
  public func decoder() -> ([String: Any]) -> StateType {
    return { dictionary in
      do {
        let state: Self = try decode(dictionary: dictionary)
        return state
      } catch {
        return Self()
      }
    }
  }
}

fileprivate func serialize(state: StateType) -> [String: Any] {
  do {
    return try encode(state)
  } catch {
    return [:]
  }
}

fileprivate func deserialize<S: SerializableStateType>(dictionary: [String: Any]) -> S {
  do {
    return try decode(dictionary: dictionary)
  } catch {
    return S()
  }
}

/** Flatten down the dictionary into a map from 'path' to value. */
fileprivate func merge(encodedState: [String: Any]) -> [String: Any] {
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
  flatten(path: "", dictionary: encodedState, result: &result)
  return result
}

