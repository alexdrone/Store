import Foundation

public typealias EncodedDictionary = [String: Any]

// MARK: - DictionaryEncoder

open class DictionaryEncoder: Encoder {
  open var codingPath: [CodingKey] = []
  open var userInfo: [CodingUserInfoKey: Any] = [:]
  private var storage = Storage()

  public init() {}

  open func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
    KeyedEncodingContainer(KeyedContainer<Key>(encoder: self, codingPath: codingPath))
  }

  open func unkeyedContainer() -> UnkeyedEncodingContainer {
    UnkeyedContanier(encoder: self, codingPath: codingPath)
  }

  open func singleValueContainer() -> SingleValueEncodingContainer {
    SingleValueContanier(encoder: self, codingPath: codingPath)
  }

  private func box<T: Encodable>(_ value: T) throws -> Any {
    /// @note: This results in a EXC_BAD_ACCESS on XCode 11.2 (works again in XCode 11.3).
    try value.encode(to: self)
    return storage.popContainer()
  }
}

extension DictionaryEncoder {
  open func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
    do {
      return try castOrThrow([String: Any].self, try box(value))
    } catch (let error) {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: [],
          debugDescription: "Top-evel \(T.self) did not encode any values.",
          underlyingError: error))
    }
  }
}

extension DictionaryEncoder {
  private class KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    private var encoder: DictionaryEncoder
    private(set) var codingPath: [CodingKey]
    private var storage: Storage

    init(encoder: DictionaryEncoder, codingPath: [CodingKey]) {
      self.encoder = encoder
      self.codingPath = codingPath
      self.storage = encoder.storage
      storage.push(container: [:] as [String: Any])
    }

    deinit {
      guard let dictionary = storage.popContainer() as? [String: Any] else {
        assertionFailure()
        return
      }
      storage.push(container: dictionary)
    }

    private func set(_ value: Any, forKey key: String) {
      guard var dictionary = storage.popContainer() as? [String: Any] else {
        assertionFailure()
        return
      }
      dictionary[key] = value
      storage.push(container: dictionary)
    }

    func encodeNil(forKey key: Key) throws {}

    func encode(
      _ value: Bool,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: Int,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: Int8,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: Int16,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: Int32,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: Int64,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: UInt,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: UInt8,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: UInt16,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: UInt32,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: UInt64,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: Float,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      _ value: Double,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode(
      value: String,
      forKey key: Key
    ) throws { set(value, forKey: key.stringValue) }

    func encode<T: Encodable>(
      _ value: T,
      forKey key: Key
    ) throws {
      encoder.codingPath.append(key)
      defer { encoder.codingPath.removeLast() }
      set(try encoder.box(value), forKey: key.stringValue)
    }

    func nestedContainer<NestedKey: CodingKey>(
      keyedBy keyType: NestedKey.Type,
      forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
      codingPath.append(key)
      defer { codingPath.removeLast() }
      return KeyedEncodingContainer(
        KeyedContainer<NestedKey>(
          encoder: encoder,
          codingPath: codingPath))
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
      codingPath.append(key)
      defer { codingPath.removeLast() }
      return UnkeyedContanier(encoder: encoder, codingPath: codingPath)
    }

    func superEncoder() -> Encoder { encoder }

    func superEncoder(forKey key: Key) -> Encoder { encoder }
  }

  private class UnkeyedContanier: UnkeyedEncodingContainer {
    var encoder: DictionaryEncoder
    private(set) var codingPath: [CodingKey]
    private var storage: Storage
    var count: Int { return storage.count }

    init(encoder: DictionaryEncoder, codingPath: [CodingKey]) {
      self.encoder = encoder
      self.codingPath = codingPath
      self.storage = encoder.storage
      storage.push(container: [] as [Any])
    }

    deinit {
      guard let array = storage.popContainer() as? [Any] else {
        assertionFailure()
        return
      }
      storage.push(container: array)
    }

    private func push(_ value: Any) {
      guard var array = storage.popContainer() as? [Any] else {
        assertionFailure()
        return
      }
      array.append(value)
      storage.push(container: array)
    }

    func encodeNil() throws {}

    func encode(
      _ value: Bool
    ) throws {}

    func encode(
      _ value: Int
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: Int8
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: Int16
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: Int32
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: Int64
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: UInt
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: UInt8
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: UInt16
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: UInt32
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: UInt64
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: Float
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: Double
    ) throws { push(try encoder.box(value)) }

    func encode(
      _ value: String
    ) throws { push(try encoder.box(value)) }

    func encode<T: Encodable>(_ value: T) throws {
      encoder.codingPath.append(AnyCodingKey(index: count))
      defer { encoder.codingPath.removeLast() }
      push(try encoder.box(value))
    }

    func nestedContainer<NestedKey>(
      keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
      codingPath.append(AnyCodingKey(index: count))
      defer { codingPath.removeLast() }
      return KeyedEncodingContainer(
        KeyedContainer<NestedKey>(
          encoder: encoder,
          codingPath: codingPath))
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
      codingPath.append(AnyCodingKey(index: count))
      defer { codingPath.removeLast() }
      return UnkeyedContanier(encoder: encoder, codingPath: codingPath)
    }

    func superEncoder() -> Encoder {
      return encoder
    }
  }

  private class SingleValueContanier: SingleValueEncodingContainer {
    var encoder: DictionaryEncoder
    private(set) var codingPath: [CodingKey]
    private var storage: Storage
    var count: Int { return storage.count }

    init(encoder: DictionaryEncoder, codingPath: [CodingKey]) {
      self.encoder = encoder
      self.codingPath = codingPath
      self.storage = encoder.storage
    }

    private func push(_ value: Any) {
      guard var array = storage.popContainer() as? [Any] else {
        assertionFailure()
        return
      }
      array.append(value)
      storage.push(container: array)
    }

    func encodeNil() throws {}

    func encode(
      _ value: Bool
    ) throws { storage.push(container: value) }

    func encode(
      _ value: Int
    ) throws { storage.push(container: value) }

    func encode(
      _ value: Int8
    ) throws { storage.push(container: value) }

    func encode(
      _ value: Int16
    ) throws { storage.push(container: value) }

    func encode(
      _ value: Int32
    ) throws { storage.push(container: value) }

    func encode(
      _ value: Int64
    ) throws { storage.push(container: value) }

    func encode(
      _ value: UInt
    ) throws { storage.push(container: value) }

    func encode(
      _ value: UInt8
    ) throws { storage.push(container: value) }

    func encode(
      _ value: UInt16
    ) throws { storage.push(container: value) }

    func encode(
      _ value: UInt32
    ) throws { storage.push(container: value) }

    func encode(
      _ value: UInt64
    ) throws { storage.push(container: value) }

    func encode(
      _ value: Float
    ) throws { storage.push(container: value) }

    func encode(
      _ value: Double
    ) throws { storage.push(container: value) }

    func encode(
      _ value: String
    ) throws { storage.push(container: value) }

    func encode<T: Encodable>(_ value: T) throws {
      storage.push(container: try encoder.box(value))
    }
  }
}

// MARK: - DictionaryDecoder

open class DictionaryDecoder: Decoder {
  open var codingPath: [CodingKey]
  open var userInfo: [CodingUserInfoKey: Any] = [:]
  private var storage = Storage()

  public init() {
    codingPath = []
  }

  public init(container: Any, codingPath: [CodingKey] = []) {
    storage.push(container: container)
    self.codingPath = codingPath
  }

  open func container<Key: CodingKey>(
    keyedBy type: Key.Type
  ) throws -> KeyedDecodingContainer<Key> {
    let container = try lastContainer(forType: [String: Any].self)
    return KeyedDecodingContainer(
      KeyedContainer<Key>(
        decoder: self,
        codingPath: [],
        container: container))
  }

  open func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    let container = try lastContainer(forType: [Any].self)
    return UnkeyedContanier(decoder: self, container: container)
  }

  open func singleValueContainer() throws -> SingleValueDecodingContainer {
    return SingleValueContanier(decoder: self)
  }

  private func unbox<T>(_ value: Any, as type: T.Type) throws -> T {
    return try unbox(value, as: type, codingPath: codingPath)
  }

  private func unbox<T>(
    _ value: Any,
    as type: T.Type,
    codingPath: [CodingKey]
  ) throws -> T {
    let description = "Expected to decode \(type) but found \(Swift.type(of: value)) instead."
    let error = DecodingError.typeMismatch(
      T.self,
      DecodingError.Context(codingPath: codingPath, debugDescription: description))
    return try castOrThrow(T.self, value, error: error)
  }

  private func unbox<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
    return try unbox(value, as: type, codingPath: codingPath)
  }

  private func unbox<T: Decodable>(
    _ value: Any,
    as type: T.Type,
    codingPath: [CodingKey]
  ) throws -> T {
    let description = "Expected to decode \(type) but found \(Swift.type(of: value)) instead."
    let error = DecodingError.typeMismatch(
      T.self,
      DecodingError.Context(codingPath: codingPath, debugDescription: description))
    do {
      return try castOrThrow(T.self, value, error: error)
    } catch {
      storage.push(container: value)
      defer { _ = storage.popContainer() }
      return try T(from: self)
    }
  }

  private func lastContainer<T>(forType type: T.Type) throws -> T {
    guard let value = storage.last else {
      let description = "Expected \(type) but found nil value instead."
      let error = DecodingError.Context(codingPath: codingPath, debugDescription: description)
      throw DecodingError.valueNotFound(type, error)
    }
    return try unbox(value, as: T.self)
  }

  private func lastContainer<T: Decodable>(forType type: T.Type) throws -> T {
    guard let value = storage.last else {
      let description = "Expected \(type) but found nil value instead."
      let error = DecodingError.Context(codingPath: codingPath, debugDescription: description)
      throw DecodingError.valueNotFound(type, error)
    }
    return try unbox(value, as: T.self)
  }

  private func notFound(key: CodingKey) -> DecodingError {
    let error = DecodingError.Context(
      codingPath: codingPath,
      debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\").")
    return DecodingError.keyNotFound(key, error)
  }
}

extension DictionaryDecoder {
  open func decode<T: Decodable>(_ type: T.Type, from container: Any) throws -> T {
    storage.push(container: container)
    return try unbox(container, as: T.self)
  }
}

extension DictionaryDecoder {
  private class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private var decoder: DictionaryDecoder
    private(set) var codingPath: [CodingKey]
    private var container: [String: Any]

    init(decoder: DictionaryDecoder, codingPath: [CodingKey], container: [String: Any]) {
      self.decoder = decoder
      self.codingPath = codingPath
      self.container = container
    }

    var allKeys: [Key] { return container.keys.compactMap { Key(stringValue: $0) } }
    func contains(_ key: Key) -> Bool { return container[key.stringValue] != nil }

    private func find(forKey key: CodingKey) throws -> Any {
      return try container.tryValue(forKey: key.stringValue, error: decoder.notFound(key: key))
    }

    func _decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
      let value = try find(forKey: key)
      decoder.codingPath.append(key)
      defer { decoder.codingPath.removeLast() }
      return try decoder.unbox(value, as: T.self)
    }

    func decodeNil(
      forKey key: Key
    ) throws -> Bool {
      // TODO: Verify, this broke in Xcode13b2.
      // decoder.notFound(key: key)
      return true
    }

    func decode(
      _ type: Bool.Type,
      forKey key: Key
    ) throws -> Bool { try _decode(type, forKey: key) }

    func decode(
      _ type: Int.Type,
      forKey key: Key
    ) throws -> Int { try _decode(type, forKey: key) }

    func decode(
      _ type: Int8.Type,
      forKey key: Key
    ) throws -> Int8 { try _decode(type, forKey: key) }

    func decode(
      _ type: Int16.Type,
      forKey key: Key
    ) throws -> Int16 { try _decode(type, forKey: key) }

    func decode(
      _ type: Int32.Type,
      forKey key: Key
    ) throws -> Int32 { try _decode(type, forKey: key) }

    func decode(
      _ type: Int64.Type,
      forKey key: Key
    ) throws -> Int64 { try _decode(type, forKey: key) }

    func decode(
      _ type: UInt.Type,
      forKey key: Key
    ) throws -> UInt { try _decode(type, forKey: key) }

    func decode(
      _ type: UInt8.Type,
      forKey key: Key
    ) throws -> UInt8 { try _decode(type, forKey: key) }

    func decode(
      _ type: UInt16.Type,
      forKey key: Key
    ) throws -> UInt16 { try _decode(type, forKey: key) }

    func decode(
      _ type: UInt32.Type,
      forKey key: Key
    ) throws -> UInt32 { try _decode(type, forKey: key) }

    func decode(
      _ type: UInt64.Type,
      forKey key: Key
    ) throws -> UInt64 { try _decode(type, forKey: key) }

    func decode(
      _ type: Float.Type,
      forKey key: Key
    ) throws -> Float { try _decode(type, forKey: key) }

    func decode(
      _ type: Double.Type,
      forKey key: Key
    ) throws -> Double { try _decode(type, forKey: key) }

    func decode(
      _ type: String.Type,
      forKey key: Key
    ) throws -> String { try _decode(type, forKey: key) }

    func decode<T: Decodable>(
      _ type: T.Type,
      forKey key: Key
    ) throws -> T { try _decode(type, forKey: key) }

    func nestedContainer<NestedKey>(
      keyedBy type: NestedKey.Type,
      forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
      decoder.codingPath.append(key)
      defer { decoder.codingPath.removeLast() }
      let value = try find(forKey: key)
      let dictionary = try decoder.unbox(value, as: [String: Any].self)
      return KeyedDecodingContainer(
        KeyedContainer<NestedKey>(
          decoder: decoder,
          codingPath: [],
          container: dictionary))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
      decoder.codingPath.append(key)
      defer { decoder.codingPath.removeLast() }
      let value = try find(forKey: key)
      let array = try decoder.unbox(value, as: [Any].self)
      return UnkeyedContanier(decoder: decoder, container: array)
    }

    func _superDecoder(forKey key: CodingKey = AnyCodingKey.super) throws -> Decoder {
      decoder.codingPath.append(key)
      defer { decoder.codingPath.removeLast() }

      let value = try find(forKey: key)
      return DictionaryDecoder(container: value, codingPath: decoder.codingPath)
    }

    func superDecoder() throws -> Decoder {
      return try _superDecoder()
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
      return try _superDecoder(forKey: key)
    }
  }

  private class UnkeyedContanier: UnkeyedDecodingContainer {
    private var decoder: DictionaryDecoder
    private(set) var codingPath: [CodingKey]
    private var container: [Any]

    var count: Int? { return container.count }
    var isAtEnd: Bool { return currentIndex >= count! }

    private(set) var currentIndex: Int

    private var currentCodingPath: [CodingKey] {
      return decoder.codingPath + [AnyCodingKey(index: currentIndex)]
    }

    init(decoder: DictionaryDecoder, container: [Any]) {
      self.decoder = decoder
      self.codingPath = decoder.codingPath
      self.container = container
      currentIndex = 0
    }

    private func checkIndex<T>(_ type: T.Type) throws {
      if isAtEnd {
        let error = DecodingError.Context(
          codingPath: currentCodingPath,
          debugDescription: "container is at end.")
        throw DecodingError.valueNotFound(T.self, error)
      }
    }

    func _decode<T: Decodable>(_ type: T.Type) throws -> T {
      try checkIndex(type)

      decoder.codingPath.append(AnyCodingKey(index: currentIndex))
      defer {
        decoder.codingPath.removeLast()
        currentIndex += 1
      }
      return try decoder.unbox(container[currentIndex], as: T.self)
    }

    func decodeNil() throws -> Bool {
      try checkIndex(Any?.self)
      return false
    }

    func decode(_ type: Bool.Type) throws -> Bool { return try _decode(type) }
    func decode(_ type: Int.Type) throws -> Int { return try _decode(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { return try _decode(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { return try _decode(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { return try _decode(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { return try _decode(type) }
    func decode(_ type: UInt.Type) throws -> UInt { return try _decode(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { return try _decode(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return try _decode(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return try _decode(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return try _decode(type) }
    func decode(_ type: Float.Type) throws -> Float { return try _decode(type) }
    func decode(_ type: Double.Type) throws -> Double { return try _decode(type) }
    func decode(_ type: String.Type) throws -> String { return try _decode(type) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { return try _decode(type) }

    func nestedContainer<NestedKey: CodingKey>(
      keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
      decoder.codingPath.append(AnyCodingKey(index: currentIndex))
      defer { decoder.codingPath.removeLast() }
      try checkIndex(UnkeyedContanier.self)
      let value = container[currentIndex]
      let dictionary = try castOrThrow([String: Any].self, value)
      currentIndex += 1
      return KeyedDecodingContainer(
        KeyedContainer<NestedKey>(
          decoder: decoder,
          codingPath: [],
          container: dictionary))
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
      decoder.codingPath.append(AnyCodingKey(index: currentIndex))
      defer { decoder.codingPath.removeLast() }
      try checkIndex(UnkeyedContanier.self)
      let value = container[currentIndex]
      let array = try castOrThrow([Any].self, value)
      currentIndex += 1
      return UnkeyedContanier(decoder: decoder, container: array)
    }

    func superDecoder() throws -> Decoder {
      decoder.codingPath.append(AnyCodingKey(index: currentIndex))
      defer { decoder.codingPath.removeLast() }
      try checkIndex(UnkeyedContanier.self)
      let value = container[currentIndex]
      currentIndex += 1
      return DictionaryDecoder(container: value, codingPath: decoder.codingPath)
    }
  }

  private class SingleValueContanier: SingleValueDecodingContainer {
    private var decoder: DictionaryDecoder
    private(set) var codingPath: [CodingKey]

    init(decoder: DictionaryDecoder) {
      self.decoder = decoder
      self.codingPath = decoder.codingPath
    }

    func _decode<T: Decodable>(_ type: T.Type) throws -> T {
      return try decoder.lastContainer(forType: type)
    }

    func decodeNil() -> Bool { return decoder.storage.last == nil }
    func decode(_ type: Bool.Type) throws -> Bool { return try _decode(type) }
    func decode(_ type: Int.Type) throws -> Int { return try _decode(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { return try _decode(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { return try _decode(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { return try _decode(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { return try _decode(type) }
    func decode(_ type: UInt.Type) throws -> UInt { return try _decode(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { return try _decode(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return try _decode(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return try _decode(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return try _decode(type) }
    func decode(_ type: Float.Type) throws -> Float { return try _decode(type) }
    func decode(_ type: Double.Type) throws -> Double { return try _decode(type) }
    func decode(_ type: String.Type) throws -> String { return try _decode(type) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { return try _decode(type) }
  }
}

// MARK: - Helpers

final class Storage {
  private(set) var containers: [Any] = []

  var count: Int {
    containers.count
  }

  var last: Any? {
    containers.last
  }

  func push(container: Any) {
    containers.append(container)
  }

  @discardableResult func popContainer() -> Any {
    precondition(containers.count > 0, "Empty container stack.")
    return containers.popLast()!
  }
}

public enum DictionaryCodableError: Error {
  case cast
  case unwrapped
  case tryValue
}

func castOrThrow<T>(
  _ resultType: T.Type,
  _ object: Any,
  error: Error = DictionaryCodableError.cast
) throws -> T {
  guard let returnValue = object as? T else {
    throw error
  }
  return returnValue
}

extension Optional {
  func unwrapOrThrow(error: Error = DictionaryCodableError.unwrapped) throws -> Wrapped {
    guard let unwrapped = self else {
      throw error
    }
    return unwrapped
  }
}

extension Dictionary {
  func tryValue(forKey key: Key, error: Error = DictionaryCodableError.tryValue) throws -> Value {
    guard let value = self[key] else { throw error }
    return value
  }
}

struct AnyCodingKey: CodingKey {
  public var stringValue: String
  public var intValue: Int?

  public init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  public init?(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }

  init(index: Int) {
    self.stringValue = "Index \(index)"
    self.intValue = index
  }

  static let `super` = AnyCodingKey(stringValue: "super")!
}

func dynamicEqual(lhs: Any?, rhs: Any?) -> Bool {
  if let lhs = lhs as? NSNumber, let rhs = rhs as? NSNumber {
    return lhs == rhs
  }
  if let lhs = lhs as? String, let rhs = rhs as? String {
    return lhs == rhs
  }
  if let lhs = lhs as? NSArray, let rhs = rhs as? NSArray {
    return lhs == rhs
  }
  if let lhs = lhs as? NSDate, let rhs = rhs as? NSDate {
    return lhs == rhs
  }
  return false
}

func dynamicEncode(value: Any, encoder: Encoder) throws {
  // TODO
}

fileprivate func isEqual<T: Equatable>(type: T.Type, a: Any, b: Any) -> Bool {
  guard let a = a as? T, let b = b as? T else { return false }
  return a == b
}
