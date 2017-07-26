// Forked from johnsundell/Wrap
// See LICENSE file.

//MARK: - Encoder

import Foundation

/// Type alias defining what type of Dictionary that Encode produces
public typealias EncodedDictionary = [String : Any]

///
/// Encode any object or value, encoding it into a JSON compatible Dictionary
///
/// - Parameter object: The object to encode
/// - Parameter context: An optional contextual object that will be available throughout
///   the encoding process. Can be used to inject extra information or objects needed to
///   perform the encoding.
/// - Parameter dateFormatter: Optionally pass in a date formatter to use to encode any
///   `NSDate` values found while encoding the object. If this is `nil`, any found date
///   values will be encoded using the "yyyy-MM-dd HH:mm:ss" format.
///
/// All the type's stored properties (both public & private) will be recursively
/// encoded with their property names as the key.
///
/// The object passed to this function must be an instance of a Class, or a value
/// based on a Struct. Standard library values, such as Ints, Strings, etc are not
/// valid input.
///
/// Throws a EncodeError if the operation could not be completed.
///
/// For more customization options, make your type conform to `EncodeCustomizable`,
/// that lets you override encoding keys and/or the whole encoding process.
///
/// See also `EncodableKey` (for dictionary keys) and `EncodableEnum` for Enum values.
///
public func encode<T>(_ object: T,
                    context: Any? = nil,
                    dateFormatter: DateFormatter? = nil) throws -> EncodedDictionary {
  return try Encoder(context: context, dateFormatter: dateFormatter)
      .encode(object: object, enableCustomizedEncodeping: true)
}

/// Alternative `encode()` overload that returns JSON-based `Data`
/// See the documentation for the dictionary-based `encode()` function for more information
public func encode<T>(_ object: T,
                    writingOptions: JSONSerialization.WritingOptions? = nil,
                    context: Any? = nil, dateFormatter: DateFormatter? = nil) throws -> Data {
  return try Encoder(context: context, dateFormatter: dateFormatter)
      .encode(object: object, writingOptions: writingOptions ?? [])
}

/// Alternative `encode()` overload that encodes an array of objects into an array of dictionaries
/// See the documentation for the dictionary-based `encode()` function for more information
public func encode<T>(_ objects: [T],
                    context: Any? = nil,
                    dateFormatter: DateFormatter? = nil) throws -> [EncodedDictionary] {
  return try objects.map { try encode($0, context: context, dateFormatter: dateFormatter) }
}

/// Alternative `encode()` overload that encodes an array of objects into JSON-based `Data`
/// See the documentation for the dictionary-based `encode()` function for more information
public func encode<T>(_ objects: [T],
                    writingOptions: JSONSerialization.WritingOptions? = nil,
                    context: Any? = nil, dateFormatter: DateFormatter? = nil) throws -> Data {
  let dictionaries: [EncodedDictionary] = try encode(objects, context: context)
  return try JSONSerialization.data(withJSONObject: dictionaries, options: writingOptions ?? [])
}

// Enum describing various styles of keys in a encoded dictionary
public enum EncodeKeyStyle {
  /// The keys in a dictionary produced by Encode should match their property name (default)
  case matchPropertyName
  /// The keys in a dictionary produced by Encode should be converted to snake_case.
  /// For example, "myProperty" will be converted to "my_property". All keys will be lowercased.
  case convertToSnakeCase
}

/// Protocol providing the main customization point for Encode
/// It's optional to implement all of the methods in this protocol, as Encode
/// supplies default implementations of them.
public protocol EncodeCustomizable {

  var encodeKeyStyle: EncodeKeyStyle { get }

  /// Override the encoding process for this type
  /// All top-level types should return a `EncodedDictionary` from this method.
  /// You may use the default encoding implementation by using a `Encoder`, but
  /// never call `encode()` from an implementation of this method, since that might
  /// cause an infinite recursion.
  /// The context & dateFormatter passed to this method is any formatter that you
  /// supplied when initiating the encoding process by calling `encode()`.
  /// Returning nil from this method will be treated as an error, and cause
  /// a `EncodeError.encodingFailedForObject()` error to be thrown.
  func encode(context: Any?, dateFormatter: DateFormatter?) -> Any?

  /// Override the key that will be used when encoding a certain property
  /// Returning nil from this method will cause Encode to skip the property
  func keyForEncodeping(propertyNamed propertyName: String) -> String?

  /// Override the encoding of any property of this type
  /// The original value passed to this method will be the original value that the
  /// type is currently storing for the property. You can choose to either use this,
  /// or just access the property in question directly.
  /// The dateFormatter passed to this method is any formatter that you supplied
  /// when initiating the encoding process by calling `encode()`.
  /// Returning nil from this method will cause Encode to use the default
  /// encoding mechanism for the property, so you can choose which properties
  /// you want to customize the encoding for.
  /// If you encounter an error while attempting to encode the property in question,
  /// you can choose to throw. This will cause a EncodeError.EncodepingFailedForObject
  /// to be thrown from the main `encode()` call that started the process.
  func encode(propertyNamed propertyName: String,
            originalValue: Any,
            context: Any?,
            dateFormatter: DateFormatter?) throws -> Any?
}

/// Protocol implemented by types that may be used as keys in a encoded Dictionary
public protocol EncodableKey {
  /// Convert this type into a key that can be used in a encoded Dictionary
  func toEncodedKey() -> String
}

///
/// Protocol implemented by Enums to enable them to be directly encoded
/// If an Enum implementing this protocol conforms to `RawRepresentable` (it's based
/// on a raw type), no further implementation is required. If you wish to customize
/// how the Enum is encoded, you can use the APIs in `EncodeCustomizable`.
public protocol EncodableEnum: EncodeCustomizable {}

/// Protocol implemented by Date types to enable them to be encoded
public protocol EncodableDate {
  /// Encode the date using a date formatter, generating a string representation
  func encode(dateFormatter: DateFormatter) -> String
}

///
/// Class used to encode an object or value. Use this in any custom `encode()` implementations
/// in case you only want to add on top of the default implementation.
/// You normally don't have to interact with this API. Use the `encode()` function instead
/// to encode an object from top-level code.
public class Encoder {
  fileprivate let context: Any?
  fileprivate var dateFormatter: DateFormatter?

  ///
  /// Initialize an instance of this class
  ///
  /// - Parameter context: An optional contextual object that will be available throughout the
  ///   encoding process. Can be used to inject extra information or objects needed to perform
  ///   the encoding.
  /// - Parameter dateFormatter: Any specific date formatter to use to encode any found `NSDate`
  ///   values. If this is `nil`, any found date values will be encoded using the "yyyy-MM-dd
  ///   HH:mm:ss" format.
  public init(context: Any? = nil, dateFormatter: DateFormatter? = nil) {
    self.context = context
    self.dateFormatter = dateFormatter
  }

  /// Perform automatic encoding of an object or value. For more information, see `Encode()`.
  public func encode(object: Any) throws -> EncodedDictionary {
    return try self.encode(object: object, enableCustomizedEncodeping: false)
  }
}

/// Error type used by Encode
public enum EncodeError: Error {
  /// Thrown when an invalid top level object (such as a String or Int) was passed to `Encode()`
  case invalidTopLevelObject(Any)
  /// Thrown when an object couldn't be encoded. This is a last resort error.
  case encodingFailedForObject(Any)
}

/// Extension containing default implementations of `EncodeCustomizable`. Override as you see fit.
public extension EncodeCustomizable {
  var encodeKeyStyle: EncodeKeyStyle {
    return .matchPropertyName
  }

  func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return try? Encoder(context: context, dateFormatter: dateFormatter).encode(object: self)
  }

  func keyForEncodeping(propertyNamed propertyName: String) -> String? {
    switch self.encodeKeyStyle {
    case .matchPropertyName:
      return propertyName
    case .convertToSnakeCase:
      return self.convertPropertyNameToSnakeCase(propertyName: propertyName)
    }
  }

  func encode(propertyNamed propertyName: String,
            originalValue: Any,
            context: Any?,
            dateFormatter: DateFormatter?) throws -> Any? {
    return try Encoder(context: context, dateFormatter: dateFormatter)
        .encode(value: originalValue, propertyName: propertyName)
  }
}

/// Extension adding convenience APIs to `EncodeCustomizable` types
public extension EncodeCustomizable {
  /// Convert a given property name (assumed to be camelCased) to snake_case
  func convertPropertyNameToSnakeCase(propertyName: String) -> String {
    let regex = try! NSRegularExpression(pattern: "(?<=[a-z])([A-Z])|([A-Z])(?=[a-z])", options: [])
    let range = NSRange(location: 0, length: propertyName.characters.count)
    let camelCasePropertyName =
        regex.stringByReplacingMatches(in: propertyName,
                                       options: [],
                                       range: range,
                                       withTemplate: "_$1$2")
    return camelCasePropertyName.lowercased()
  }
}

/// Extension providing a default encoding implementation for `RawRepresentable` Enums
public extension EncodableEnum where Self: RawRepresentable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return self.rawValue
  }
}

/// Extension customizing how Arrays are encoded
extension Array: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return try? Encoder(context: context, dateFormatter: dateFormatter).encode(collection: self)
  }
}

/// Extension customizing how Dictionaries are encoded
extension Dictionary: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return try? Encoder(context: context, dateFormatter: dateFormatter).encode(dictionary: self)
  }
}

/// Extension customizing how Sets are encoded
extension Set: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return try? Encoder(context: context, dateFormatter: dateFormatter).encode(collection: self)
  }
}

/// Extension customizing how Int64s are encoded, ensuring compatbility with 32 bit systems
extension Int64: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return NSNumber(value: self)
  }
}

/// Extension customizing how UInt64s are encoded, ensuring compatbility with 32 bit systems
extension UInt64: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return NSNumber(value: self)
  }
}

/// Extension customizing how NSStrings are encoded
extension NSString: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return self
  }
}

/// Extension customizing how NSURLs are encoded
extension NSURL: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return self.absoluteString
  }
}

/// Extension customizing how URLs are encoded
extension URL: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return self.absoluteString
  }
}


/// Extension customizing how NSArrays are encoded
extension NSArray: EncodeCustomizable {
  public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
    return try? Encoder(context: context, dateFormatter: dateFormatter)
        .encode(collection: Array(self))
  }
}

#if !os(Linux)
  /// Extension customizing how NSDictionaries are encoded
  extension NSDictionary: EncodeCustomizable {
    public func encode(context: Any?, dateFormatter: DateFormatter?) -> Any? {
      return try? Encoder(context: context, dateFormatter: dateFormatter)
          .encode(dictionary: self as [NSObject : AnyObject])
    }
  }
#endif

/// Extension making Int a EncodableKey
extension Int: EncodableKey {
  public func toEncodedKey() -> String {
    return String(self)
  }
}

/// Extension making Date a EncodableDate
extension Date: EncodableDate {
  public func encode(dateFormatter: DateFormatter) -> String {
    return dateFormatter.string(from: self)
  }
}

#if !os(Linux)
  /// Extension making NSdate a EncodableDate
  extension NSDate: EncodableDate {
    public func encode(dateFormatter: DateFormatter) -> String {
      return dateFormatter.string(from: self as Date)
    }
  }
#endif

private extension Encoder {
  func encode<T>(object: T, enableCustomizedEncodeping: Bool) throws -> EncodedDictionary {
    if enableCustomizedEncodeping {
      if let customizable = object as? EncodeCustomizable {
        let encoded = try self.performCustomEncodeping(object: customizable)

        guard let encodedDictionary = encoded as? EncodedDictionary else {
          throw EncodeError.invalidTopLevelObject(object)
        }

        return encodedDictionary
      }
    }

    var mirrors = [Mirror]()
    var currentMirror: Mirror? = Mirror(reflecting: object)

    while let mirror = currentMirror {
      mirrors.append(mirror)
      currentMirror = mirror.superclassMirror
    }

    return try self.performEncodeping(object: object, mirrors: mirrors.reversed())
  }

  func encode<T>(object: T, writingOptions: JSONSerialization.WritingOptions) throws -> Data {
    let dictionary = try self.encode(object: object, enableCustomizedEncodeping: true)
    return try JSONSerialization.data(withJSONObject: dictionary, options: writingOptions)
  }

  func encode<T>(value: T, propertyName: String? = nil) throws -> Any? {
    if let customizable = value as? EncodeCustomizable {
      return try self.performCustomEncodeping(object: customizable)
    }
    if let date = value as? EncodableDate {
      return self.encode(date: date)
    }
    let mirror = Mirror(reflecting: value)
    if mirror.children.isEmpty {
      if let displayStyle = mirror.displayStyle {
        switch displayStyle {
        case .enum:
          if let encodepableEnum = value as? EncodableEnum {
            if let encoded = encodepableEnum.encode(context: self.context,
                                                dateFormatter: self.dateFormatter) {
              return encoded
            }
            throw EncodeError.encodingFailedForObject(value)
          }
          return "\(value)"
        case .struct:
          return [:]
        default:
          return value
        }
      }
      if !(value is CustomStringConvertible) {
        if String(describing: value) == "(Function)" {
          return nil
        }
      }
      return value
    } else if value is ExpressibleByNilLiteral && mirror.children.count == 1 {
      if let firstMirrorChild = mirror.children.first {
        return try self.encode(value: firstMirrorChild.value, propertyName: propertyName)
      }
    }
    return try self.encode(object: value, enableCustomizedEncodeping: false)
  }

  func encode<T: Collection>(collection: T) throws -> [Any] {
    var encodedArray = [Any]()
    let encoder = Encoder(context: self.context, dateFormatter: self.dateFormatter)
    for element in collection {
      if let encoded = try encoder.encode(value: element) {
        encodedArray.append(encoded)
      }
    }

    return encodedArray
  }

  func encode<K: Hashable, V>(dictionary: [K : V]) throws -> EncodedDictionary {
    var encodedDictionary = EncodedDictionary()
    let encoder = Encoder(context: self.context, dateFormatter: self.dateFormatter)

    for (key, value) in dictionary {
      let encodedKey: String?
      if let stringKey = key as? String {
        encodedKey = stringKey
      } else if let encodepableKey = key as? EncodableKey {
        encodedKey = encodepableKey.toEncodedKey()
      } else if let stringConvertible = key as? CustomStringConvertible {
        encodedKey = stringConvertible.description
      } else {
        encodedKey = nil
      }
      if let encodedKey = encodedKey {
        encodedDictionary[encodedKey] = try encoder.encode(value: value, propertyName: encodedKey)
      }
    }

    return encodedDictionary
  }

  func encode(date: EncodableDate) -> String {
    let dateFormatter: DateFormatter
    if let existingFormatter = self.dateFormatter {
      dateFormatter = existingFormatter
    } else {
      dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      self.dateFormatter = dateFormatter
    }
    return date.encode(dateFormatter: dateFormatter)
  }

  func performEncodeping<T>(object: T, mirrors: [Mirror]) throws -> EncodedDictionary {
    let customizable = object as? EncodeCustomizable
    var encodedDictionary = EncodedDictionary()
    for mirror in mirrors {
      for property in mirror.children {
        if (property.value as? EncodeOptional)?.isNil == true {
          continue
        }
        guard let propertyName = property.label else {
          continue
        }
        let encodingKey: String?
        if let customizable = customizable {
          encodingKey = customizable.keyForEncodeping(propertyNamed: propertyName)
        } else {
          encodingKey = propertyName
        }
        if let encodingKey = encodingKey {
          if let encodedProperty = try customizable?
              .encode(propertyNamed: propertyName,
                    originalValue: property.value,
                    context: self.context,
                    dateFormatter: self.dateFormatter) {
            encodedDictionary[encodingKey] = encodedProperty
          } else {
            encodedDictionary[encodingKey] = try self.encode(value: property.value,
                                                           propertyName: propertyName)
          }
        }
      }
    }

    return encodedDictionary
  }

  func performCustomEncodeping(object: EncodeCustomizable) throws -> Any {
    guard let encoded = object.encode(context: self.context,
                                      dateFormatter: self.dateFormatter) else {
      throw EncodeError.encodingFailedForObject(object)
    }

    return encoded
  }
}

private protocol EncodeOptional {
  var isNil: Bool { get }
}

extension Optional : EncodeOptional {
  var isNil: Bool {
    switch self {
    case .none:
      return true
    case .some(let encoded):
      if let nillable = encoded as? EncodeOptional {
        return nillable.isNil
      }
      return false
    }
  }
}


// Forked from johnsundell/Unbox
// See LICENSE file.

//MARK: - Decoder

/// Extension making `Array` an decodable collection
extension Array: DecodableCollection {
  public typealias DecodeValue = Element

  public static func decode<T: DecodeCollectionElementTransformer>(
    value: Any,
    allowInvalidElements: Bool,
    transformer: T) throws -> Array? where T.DecodeedElement == DecodeValue {
    guard let array = value as? [T.DecodeRawElement] else {
      return nil
    }

    return try array.enumerated().map(allowInvalidElements: allowInvalidElements) {
      index, element in
      let decodedElement = try transformer.decode(
        element: element,
        allowInvalidCollectionElements: allowInvalidElements)
      return try decodedElement.orThrow(DecodePathError.invalidArrayElement(element, index))
    }
  }
}

/// Extension making `Array` an decode path node
extension Array: DecodePathNode {
  func decodePathValue(forKey key: String) -> Any? {
    guard let index = Int(key) else {
      return nil
    }

    if index >= self.count {
      return nil
    }

    return self[index]
  }
}

/// Extension making `Bool` an Decodable raw type
extension Bool: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> Bool? {
    return decodedNumber.boolValue
  }

  public static func transform(decodedString: String) -> Bool? {
    switch decodedString.lowercased() {
    case "true", "t", "y", "yes":
      return true
    case "false", "f" , "n", "no":
      return false
    default:
      return nil
    }
  }
}

#if !os(Linux)
  import CoreGraphics

  /// Extension making `CGFloat` an Decodable raw type
  extension CGFloat: DecodableByTransform {
    public typealias DecodeRawValue = Double

    public static func transform(decodedValue: Double) -> CGFloat? {
      return CGFloat(decodedValue)
    }
  }
#endif

extension Data {
  func decode<T: Decodable>() throws -> T {
    return try Decoder(data: self).performDecodeing()
  }

  func decode<T: DecodableWithContext>(context: T.DecodeContext) throws -> T {
    return try Decoder(data: self).performDecodeing(context: context)
  }

  func decode<T>(closure: (Decoder) throws -> T?) throws -> T {
    return try closure(Decoder(data: self)).orThrow(DecodeError.customDecodeingFailed)
  }

  func decode<T: Decodable>(allowInvalidElements: Bool) throws -> [T] {
    let array: [DecodableDictionary] = try JSONSerialization.decode(data: self,
                                                                    options: [.allowFragments])
    return try array.map(allowInvalidElements: allowInvalidElements) { dictionary in
      return try Decoder(dictionary: dictionary).performDecodeing()
    }
  }

  func decode<T: DecodableWithContext>(context: T.DecodeContext,
              allowInvalidElements: Bool) throws -> [T] {
    let array: [DecodableDictionary] = try JSONSerialization.decode(data: self,
                                                                    options: [.allowFragments])

    return try array.map(allowInvalidElements: allowInvalidElements) { dictionary in
      return try Decoder(dictionary: dictionary).performDecodeing(context: context)
    }
  }
}

/// Extension making `DateFormatter` usable as an DecodeFormatter
extension DateFormatter: DecodeFormatter {
  public func format(decodedValue: String) -> Date? {
    return self.date(from: decodedValue)
  }
}

/// Extension making `Decimal` an Decodable raw type
extension Decimal: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> Decimal? {
    return Decimal(string: decodedNumber.stringValue)
  }

  public static func transform(decodedString decodedValue: String) -> Decimal? {
    return Decimal(string: decodedValue)
  }
}

/// Extension making `Dictionary` an decodable collection
extension Dictionary: DecodableCollection {
  public typealias DecodeValue = Value

  public static func decode<T: DecodeCollectionElementTransformer>(
    value: Any,
    allowInvalidElements: Bool,
    transformer: T) throws -> Dictionary? where T.DecodeedElement == DecodeValue {
    guard let dictionary = value as? [String : T.DecodeRawElement] else {
      return nil
    }

    let keyTransform = try self.makeKeyTransform()

    return try dictionary.map(allowInvalidElements: allowInvalidElements) { key, value in
      guard let decodedKey = keyTransform(key) else {
        throw DecodePathError.invalidDictionaryKey(key)
      }

      guard let decodedValue = try transformer.decode(
        element: value,
        allowInvalidCollectionElements: allowInvalidElements) else {
          throw DecodePathError.invalidDictionaryValue(value, key)
      }

      return (decodedKey, decodedValue)
    }
  }

  private static func makeKeyTransform() throws -> (String) -> Key? {
    if Key.self is String.Type {
      return { $0 as? Key }
    }

    if let keyType = Key.self as? DecodableKey.Type {
      return { keyType.transform(decodedKey: $0) as? Key }
    }

    throw DecodePathError.invalidDictionaryKeyType(Key.self)
  }
}

/// Extension making `Dictionary` an decode path node
extension Dictionary: DecodePathNode {
  func decodePathValue(forKey key: String) -> Any? {
    return self[key as! Key]
  }
}

private extension Dictionary {
  func map<K, V>(allowInvalidElements: Bool,
           transform: (Key, Value) throws -> (K, V)?) throws -> [K : V]? {
    var transformedDictionary = [K : V]()
    for (key, value) in self {
      do {
        guard let transformed = try transform(key, value) else {
          if allowInvalidElements {
            continue
          }
          return nil
        }
        transformedDictionary[transformed.0] = transformed.1
      } catch {
        if !allowInvalidElements {
          throw error
        }
      }
    }
    return transformedDictionary
  }
}

/// Extension making `Double` an Decodable raw type
extension Double: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> Double? {
    return decodedNumber.doubleValue
  }

  public static func transform(decodedString: String) -> Double? {
    return Double(decodedString)
  }
}

/// Extension making `Float` an Decodable raw type
extension Float: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> Float? {
    return decodedNumber.floatValue
  }

  public static func transform(decodedString: String) -> Float? {
    return Float(decodedString)
  }
}

/// Extension making `Int` an Decodable raw type
extension Int: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> Int? {
    return decodedNumber.intValue
  }

  public static func transform(decodedString: String) -> Int? {
    return Int(decodedString)
  }
}

/// Extension making `Int32` an Decodable raw type
extension Int32: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> Int32? {
    return decodedNumber.int32Value
  }

  public static func transform(decodedString: String) -> Int32? {
    return Int32(decodedString)
  }
}

/// Extension making `Int64` an Decodable raw type
extension Int64: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> Int64? {
    return decodedNumber.int64Value
  }

  public static func transform(decodedString: String) -> Int64? {
    return Int64(decodedString)
  }
}

extension JSONSerialization {
  static func decode<T>(data: Data, options: ReadingOptions = []) throws -> T {
    do {
      return
        try (self.jsonObject(with: data, options: options) as? T).orThrow(DecodeError.invalidData)
    } catch {
      throw DecodeError.invalidData
    }
  }
}

#if !os(Linux)
  extension NSArray: DecodePathNode {
    func decodePathValue(forKey key: String) -> Any? {
      return (self as Array).decodePathValue(forKey: key)
    }
  }
#endif

#if !os(Linux)
  extension NSDictionary: DecodePathNode {
    func decodePathValue(forKey key: String) -> Any? {
      return self[key]
    }
  }
#endif

extension Optional {
  func map<T>(_ transform: (Wrapped) throws -> T?) rethrows -> T? {
    guard let value = self else {
      return nil
    }

    return try transform(value)
  }

  func orThrow<E: Error>(_ errorClosure: @autoclosure () -> E) throws -> Wrapped {
    guard let value = self else {
      throw errorClosure()
    }

    return value
  }
}

extension Sequence {
  func map<T>(allowInvalidElements: Bool, transform: (Iterator.Element) throws -> T) throws -> [T] {
    if !allowInvalidElements {
      return try self.map(transform)
    }

    return self.flatMap {
      return try? transform($0)
    }
  }
}

/// Extension making `Set` an decodable collection
extension Set: DecodableCollection {
  public typealias DecodeValue = Element

  public static func decode<T: DecodeCollectionElementTransformer>(
    value: Any,
    allowInvalidElements: Bool,
    transformer: T) throws -> Set? where T.DecodeedElement == DecodeValue {
    guard let array = try [DecodeValue].decode(value: value,
                                               allowInvalidElements: allowInvalidElements,
                                               transformer: transformer) else {
                                                return nil
    }

    return Set(array)
  }
}

/// Extension making `String` an Decodable raw type
extension String: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> String? {
    return decodedNumber.stringValue
  }

  public static func transform(decodedString: String) -> String? {
    return decodedString
  }
}

/// Type alias defining what type of Dictionary that is Decodable (valid JSON)
public typealias DecodableDictionary = [String : Any]

typealias DecodeTransform<T> = (Any) throws -> T?

/// Extension making UInt an Decodable raw type
extension UInt: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> UInt? {
    return decodedNumber.uintValue
  }

  public static func transform(decodedString: String) -> UInt? {
    return UInt(decodedString)
  }
}

/// Extension making `UInt32` an Decodable raw type
extension UInt32: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> UInt32? {
    return decodedNumber.uint32Value
  }

  public static func transform(decodedString: String) -> UInt32? {
    return UInt32(decodedString)
  }
}

/// Extension making `UInt64` an Decodable raw type
extension UInt64: DecodableRawType {
  public static func transform(decodedNumber: NSNumber) -> UInt64? {
    return decodedNumber.uint64Value
  }

  public static func transform(decodedString: String) -> UInt64? {
    return UInt64(decodedString)
  }
}

/// Extension making `URL` Decodable by transform
extension URL: DecodableByTransform {
  public typealias DecodeRawValue = String

  public static func transform(decodedValue: String) -> URL? {
    return URL(string: decodedValue)
  }
}

/// Decode a JSON dictionary into a model `T`. Throws `DecodeError`.
public func decode<T: Decodable>(dictionary: DecodableDictionary) throws -> T {
  return try Decoder(dictionary: dictionary).performDecodeing()
}

/// Decode a JSON dictionary into a model `T` beginning at a certain key. Throws `DecodeError`.
public func decode<T: Decodable>(dictionary: DecodableDictionary, atKey key: String) throws -> T {
  let container: DecodeContainer<T> = try decode(dictionary: dictionary, context: .key(key))
  return container.model
}

/// Decode a JSON dictionary into a model `T` beginning at a certain key path. Throws `DecodeError`.
public func decode<T: Decodable>(dictionary: DecodableDictionary,
                   atKeyPath keyPath: String) throws -> T {
  let container: DecodeContainer<T> = try decode(dictionary: dictionary, context: .keyPath(keyPath))
  return container.model
}

/// Decode an array of JSON dictionaries into an array of `T`, optionally allowing invalid elements.
/// Throws `DecodeError`.
public func decode<T: Decodable>(dictionaries: [DecodableDictionary],
                   allowInvalidElements: Bool = false) throws -> [T] {
  return try dictionaries.map(allowInvalidElements: allowInvalidElements, transform: decode)
}

/// Decode an array JSON dictionary into an array of model `T` beginning at a certain key,
/// optionally allowing invalid elements. Throws `DecodeError`.
public func decode<T: Decodable>(dictionary: DecodableDictionary,
                   atKey key: String,
                   allowInvalidElements: Bool = false) throws -> [T] {
  let container: DecodeArrayContainer<T> = try decode(dictionary: dictionary,
                                                      context: (.key(key), allowInvalidElements))
  return container.models
}

/// Decode an array JSON dictionary into an array of model `T` beginning at a certain key path,
/// optionally allowing invalid elements. Throws `DecodeError`.
public func decode<T: Decodable>(dictionary: DecodableDictionary,
                   atKeyPath keyPath: String,
                   allowInvalidElements: Bool = false) throws -> [T] {
  let container: DecodeArrayContainer<T> =
    try decode(dictionary: dictionary, context: (.keyPath(keyPath), allowInvalidElements))
  return container.models
}

/// Decode binary data into a model `T`. Throws `DecodeError`.
public func decode<T: Decodable>(data: Data) throws -> T {
  return try data.decode()
}

/// Decode binary data into an array of `T`, optionally allowing invalid elements.
public func decode<T: Decodable>(data: Data,
                   atKeyPath keyPath: String? = nil,
                   allowInvalidElements: Bool = false) throws -> [T] {
  if let keyPath = keyPath {
    return try decode(dictionary: JSONSerialization.decode(data: data),
                      atKeyPath: keyPath,
                      allowInvalidElements: allowInvalidElements)
  }

  return try data.decode(allowInvalidElements: allowInvalidElements)
}

/// Decode a JSON dictionary into a model `T` using a required contextual object.
public func decode<T: DecodableWithContext>(dictionary: DecodableDictionary,
                   context: T.DecodeContext) throws -> T {
  return try Decoder(dictionary: dictionary).performDecodeing(context: context)
}

/// Decode an array of JSON dictionaries into an array of `T` using a required contextual object,
/// optionally allowing invalid elements. Throws `DecodeError`.
public func decode<T: DecodableWithContext>(dictionaries: [DecodableDictionary],
                   context: T.DecodeContext,
                   allowInvalidElements: Bool = false) throws -> [T] {
  return try dictionaries.map(allowInvalidElements: allowInvalidElements, transform: {
    try decode(dictionary: $0, context: context)
  })
}

/// Decode binary data into a model `T` using a required contextual object. Throws `DecodeError`.
public func decode<T: DecodableWithContext>(data: Data, context: T.DecodeContext) throws -> T {
  return try data.decode(context: context)
}

/// Decode binary data into an array of `T` using a required contextual object,
/// optionally allowing invalid elements. Throws `DecodeError`.
public func decode<T: DecodableWithContext>(data: Data,
                   context: T.DecodeContext,
                   allowInvalidElements: Bool = false) throws -> [T] {
  return try data.decode(context: context, allowInvalidElements: allowInvalidElements)
}

/// Decode binary data into a dictionary of type `[String: T]`. Throws `DecodeError`.
public func decode<T: Decodable>(data: Data) throws -> [String: T] {
  let dictionary : [String: [String: Any]] = try JSONSerialization.decode(data: data)
  return try decode(dictionary: dictionary)
}

/// Decode `DecodableDictionary` into a dictionary of type `[String: T]` where `T` is `Decodable`.
public func decode<T: Decodable>(dictionary: DecodableDictionary) throws -> [String: T] {
  var mappedDictionary = [String: T]()
  try dictionary.forEach { key, value in
    guard let innerDictionary = value as? DecodableDictionary else {
      throw DecodeError.invalidData
    }
    let data : T = try decode(dictionary: innerDictionary)
    mappedDictionary[key] = data
  }
  return mappedDictionary
}

struct DecodeArrayContainer<T: Decodable>: DecodableWithContext {
  let models: [T]

  init(decoder: Decoder, context: (path: DecodePath, allowInvalidElements: Bool)) throws {
    switch context.path {
    case .key(let key):
      self.models = try decoder.decode(key: key, allowInvalidElements: context.allowInvalidElements)
    case .keyPath(let keyPath):
      self.models = try decoder.decode(keyPath: keyPath,
                                       allowInvalidElements: context.allowInvalidElements)
    }
  }
}

/// Protocol used to decode an element in a collection.
/// Decode provides default implementations of this protocol.
public protocol DecodeCollectionElementTransformer {
  /// The raw element type that this transformer expects as input
  associatedtype DecodeRawElement
  /// The decoded element type that this transformer outputs
  associatedtype DecodeedElement

  /// Decode an element from a collection, optionally allowing invalid elements for
  /// nested collections
  func decode(element: DecodeRawElement,
              allowInvalidCollectionElements: Bool) throws -> DecodeedElement?
}

/// Protocol that types that can be used in an decoding process must conform to.
/// You don't conform to this protocol yourself.
public protocol DecodeCompatible {
  /// Decode a value, or either throw or return nil if decoding couldn't be performed
  static func decode(value: Any, allowInvalidCollectionElements: Bool) throws -> Self?
}

extension DecodeCompatible {
  static func decode(value: Any) throws -> Self? {
    return try self.decode(value: value, allowInvalidCollectionElements: false)
  }
}

extension DecodeCompatible where Self: Collection {
  static func makeTransform(allowInvalidElements: Bool) -> DecodeTransform<Self> {
    return {
      try self.decode(value: $0, allowInvalidCollectionElements: allowInvalidElements)
    }
  }
}

struct DecodeContainer<T: Decodable>: DecodableWithContext {
  let model: T

  init(decoder: Decoder, context: DecodePath) throws {
    switch context {
    case .key(let key):
      self.model = try decoder.decode(key: key)
    case .keyPath(let keyPath):
      self.model = try decoder.decode(keyPath: keyPath)
    }
  }
}

/// Error type that Decode throws in case an unrecoverable error was encountered
public enum DecodeError: Error {
  /// Invalid data was provided when calling decode(data:...)
  case invalidData
  /// Custom decoding failed, either by throwing or returning `nil`
  case customDecodeingFailed
  /// An error occurred while decoding a value for a path (contains the underlying
  /// path error, and the path)
  case pathError(DecodePathError, String)
}

/// Extension making `DecodeError` conform to `CustomStringConvertible`
extension DecodeError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .invalidData:
      return "[DecodeError] Invalid data."
    case .customDecodeingFailed:
      return "[DecodeError] Custom decoding failed."
    case .pathError(let error, let path):
      return "[DecodeError] An error occurred while decoding path \"\(path)\": \(error)"
    }
  }
}

/// Protocol used by objects that may format raw values into some other value
public protocol DecodeFormatter {
  /// The type of raw value that this formatter accepts as input
  associatedtype DecodeRawValue: DecodableRawType
  /// The type of value that this formatter produces as output
  associatedtype DecodeFormattedType

  /// Format an decoded value into another value (or nil if the formatting failed)
  func format(decodedValue: DecodeRawValue) -> DecodeFormattedType?
}

extension DecodeFormatter {
  func makeTransform() -> DecodeTransform<DecodeFormattedType> {
    return { ($0 as? DecodeRawValue).map(self.format) }
  }

  func makeCollectionTransform<C: DecodableCollection>(
    allowInvalidElements: Bool) -> DecodeTransform<C> where C.DecodeValue == DecodeFormattedType {
    return {
      let transformer = DecodeFormatterCollectionElementTransformer(formatter: self)
      return try C.decode(value: $0,
                          allowInvalidElements: allowInvalidElements,
                          transformer: transformer)
    }
  }
}

private class DecodeFormatterCollectionElementTransformer<T: DecodeFormatter>:
DecodeCollectionElementTransformer {
  private let formatter: T

  init(formatter: T) {
    self.formatter = formatter
  }

  func decode(element: T.DecodeRawValue,
              allowInvalidCollectionElements: Bool) throws -> T.DecodeFormattedType? {
    return self.formatter.format(decodedValue: element)
  }
}

enum DecodePath {
  case key(String)
  case keyPath(String)
}

extension DecodePath: CustomStringConvertible {
  var description: String {
    switch self {
    case .key(let key):
      return key
    case .keyPath(let keyPath):
      return keyPath
    }
  }
}

/// Type for errors that can occur while decoding a certain path
public enum DecodePathError: Error {
  /// An empty key path was given
  case emptyKeyPath
  /// A required key was missing (contains the key)
  case missingKey(String)
  /// An invalid value was found (contains the value, and its key)
  case invalidValue(Any, String)
  /// An invalid collection element type was found (contains the type)
  case invalidCollectionElementType(Any)
  /// An invalid array element was found (contains the element, and its index)
  case invalidArrayElement(Any, Int)
  /// An invalid dictionary key type was found (contains the type)
  case invalidDictionaryKeyType(Any)
  /// An invalid dictionary key was found (contains the key)
  case invalidDictionaryKey(Any)
  /// An invalid dictionary value was found (contains the value, and its key)
  case invalidDictionaryValue(Any, String)
}

extension DecodePathError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .emptyKeyPath:
      return "Key path can't be empty."
    case .missingKey(let key):
      return "The key \"\(key)\" is missing."
    case .invalidValue(let value, let key):
      return "Invalid value (\(value)) for key \"\(key)\"."
    case .invalidCollectionElementType(let type):
      return "Invalid collection element type: \(type). Must be DecodeCompatible or Decodable."
    case .invalidArrayElement(let element, let index):
      return "Invalid array element (\(element)) at index \(index)."
    case .invalidDictionaryKeyType(let type):
      return "Invalid dictionary key type: \(type). Must be either String or DecodableKey."
    case .invalidDictionaryKey(let key):
      return "Invalid dictionary key: \(key)."
    case .invalidDictionaryValue(let value, let key):
      return "Invalid dictionary value (\(value)) for key \"\(key)\"."
    }
  }
}

protocol DecodePathNode {
  func decodePathValue(forKey key: String) -> Any?
}

/// Protocol used to declare a model as being Decodable, for use with the decode() function
public protocol Decodable {
  /// Initialize an instance of this model by decoding a dictionary using an Decoder
  init(decoder: Decoder) throws
}

extension Decodable {
  static func makeTransform() -> DecodeTransform<Self> {
    return { try ($0 as? DecodableDictionary).map(decode) }
  }
}

/// Protocol used to enable any type as being decodable, by transforming a raw value
public protocol DecodableByTransform: DecodeCompatible {
  /// The type of raw value that this type can be transformed from. Must be a valid JSON type.
  associatedtype DecodeRawValue

  /// Attempt to transform a raw decoded value into an instance of this type
  static func transform(decodedValue: DecodeRawValue) -> Self?
}

/// Default implementation of `DecodeCompatible` for transformable types
public extension DecodableByTransform {
  static func decode(value: Any, allowInvalidCollectionElements: Bool) throws -> Self? {
    return (value as? DecodeRawValue).map(self.transform)
  }
}

/// Protocol used to enable collections to be decoded.
/// Default implementations exist for Array & Dictionary
public protocol DecodableCollection: Collection, DecodeCompatible {
  /// The value type that this collection contains
  associatedtype DecodeValue

  /// Decode a value into a collection, optionally allowing invalid elements
  static func decode<T: DecodeCollectionElementTransformer>(
    value: Any,
    allowInvalidElements: Bool,
    transformer: T) throws -> Self? where T.DecodeedElement == DecodeValue
}

// Default implementation of `DecodeCompatible` for collections
public extension DecodableCollection {
  public static func decode(value: Any, allowInvalidCollectionElements: Bool) throws -> Self? {
    if let matchingCollection = value as? Self {
      return matchingCollection
    }

    if let decodableType = DecodeValue.self as? Decodable.Type {
      let transformer = DecodeCollectionElementClosureTransformer<DecodableDictionary, DecodeValue>(){
        element in
        let decoder = Decoder(dictionary: element)
        return try decodableType.init(decoder: decoder) as? DecodeValue
      }

      return try self.decode(value: value,
                             allowInvalidElements: allowInvalidCollectionElements,
                             transformer: transformer)
    }

    if let unboxCompatibleType = DecodeValue.self as? DecodeCompatible.Type {
      let transformer = DecodeCollectionElementClosureTransformer<Any, DecodeValue>() {
        element in
        return try unboxCompatibleType.decode(
          value: element,
          allowInvalidCollectionElements: allowInvalidCollectionElements) as? DecodeValue
      }

      return try self.decode(value: value,
                             allowInvalidElements: allowInvalidCollectionElements,
                             transformer: transformer)
    }

    throw DecodePathError.invalidCollectionElementType(DecodeValue.self)
  }
}

private class DecodeCollectionElementClosureTransformer<I, O>: DecodeCollectionElementTransformer {
  private let closure: (I) throws -> O?

  init(closure: @escaping (I) throws -> O?) {
    self.closure = closure
  }

  func decode(element: I, allowInvalidCollectionElements: Bool) throws -> O? {
    return try self.closure(element)
  }
}

/// Protocol used to enable an enum to be directly decodable
public protocol DecodableEnum: RawRepresentable, DecodeCompatible {}

/// Default implementation of `DecodeCompatible` for enums
public extension DecodableEnum {
  static func decode(value: Any, allowInvalidCollectionElements: Bool) throws -> Self? {
    return (value as? RawValue).map(self.init)
  }
}

/// Protocol used to enable any type to be transformed from a JSON key into a dictionary key
public protocol DecodableKey {
  /// Transform an decoded key into a key that will be used in an decoded dictionary
  static func transform(decodedKey: String) -> Self?
}

/// Protocol used to enable a raw type (such as `Int` or `String`) for Decodeing
public protocol DecodableRawType: DecodeCompatible {
  /// Transform an instance of this type from an decoded number
  static func transform(decodedNumber: NSNumber) -> Self?
  /// Transform an instance of this type from an decoded string
  static func transform(decodedString: String) -> Self?
}

// Default implementation of `DecodeCompatible` for raw types
public extension DecodableRawType {
  static func decode(value: Any, allowInvalidCollectionElements: Bool) throws -> Self? {
    if let matchedValue = value as? Self {
      return matchedValue
    }
    if let string = value as? String {
      return self.transform(decodedString: string)
    }
    if let number = value as? NSNumber {
      return self.transform(decodedNumber: number)
    }
    return nil
  }
}

/// Protocol used to declare a model as being Decodable with a certain context, for use with
/// the decode(context:) function
public protocol DecodableWithContext {
  /// The type of the contextual object that this model requires when decoded
  associatedtype DecodeContext

  /// Initialize an instance of this model by decoding a dictionary & using a context
  init(decoder: Decoder, context: DecodeContext) throws
}

extension DecodableWithContext {
  static func makeTransform(context: DecodeContext) -> DecodeTransform<Self> {
    return {
      try ($0 as? DecodableDictionary).map {
        try decode(dictionary: $0, context: context)
      }
    }
  }

  static func makeCollectionTransform<C: DecodableCollection>(
    context: DecodeContext,
    allowInvalidElements: Bool) -> DecodeTransform<C> where C.DecodeValue == Self {
    return {
      let transformer = DecodableWithContextCollectionElementTransformer<Self>(context: context)
      return try C.decode(value: $0,
                          allowInvalidElements: allowInvalidElements,
                          transformer: transformer)
    }
  }
}

private class DecodableWithContextCollectionElementTransformer<T: DecodableWithContext>:
DecodeCollectionElementTransformer {
  private let context: T.DecodeContext

  init(context: T.DecodeContext) {
    self.context = context
  }

  func decode(element: DecodableDictionary, allowInvalidCollectionElements: Bool) throws -> T? {
    let decoder = Decoder(dictionary: element)
    return try T(decoder: decoder, context: self.context)
  }
}

/// Class used to Decode (decode) values from a dictionary
/// For each supported type, simply call `decode(key: string)` (where `string` is a key
/// in the dictionary that is being decoded)
/// - and the correct type will be returned. If a required (non-optional) value couldn't be
/// decoded `DecodeError` will be thrown.

public final class Decoder {
  /// The underlying JSON dictionary that is being decoded
  public let dictionary: DecodableDictionary

  /// Initialize an instance with a dictionary that can then be decoded using the `decode()` methods.
  public init(dictionary: DecodableDictionary) {
    self.dictionary = dictionary
  }

  /// Initialize an instance with binary data than can then be decoded using the `decode()` methods.
  /// Throws `DecodeError` for invalid data.
  public init(data: Data) throws {
    self.dictionary = try JSONSerialization.decode(data: data)
  }

  /// Perform custom decoding using an Decoder (created from a dictionary) passed to a closure,
  /// or throw an DecodeError
  public static func performCustomDecodeing<T>(dictionary: DecodableDictionary,
                                            closure: (Decoder) throws -> T?) throws -> T {
    return try Decoder(dictionary: dictionary).performCustomDecodeing(closure: closure)
  }

  /// Perform custom decoding on an array of dictionaries, executing a closure with a new Decoder
  /// for each one, or throw an DecodeError
  public static func performCustomDecodeing<T>(array: [DecodableDictionary],
                                            allowInvalidElements: Bool = false,
                                            closure: (Decoder) throws -> T?) throws -> [T] {
    return try array.map(allowInvalidElements: allowInvalidElements) {
      try Decoder(dictionary: $0).performCustomDecodeing(closure: closure)
    }
  }

  /// Perform custom decoding using an Decoder (created from binary data) passed to a closure,
  /// or throw an DecodeError
  public static func performCustomDecodeing<T>(
    data: Data,
    closure: @escaping (Decoder) throws -> T?) throws -> T {
    return try data.decode(closure: closure)
  }

  /// Decode a required value by key
  public func decode<T: DecodeCompatible>(key: String) throws -> T {
    return try self.decode(path: .key(key), transform: T.decode)
  }

  /// Decode a required collection by key
  public func decode<T: DecodableCollection>(key: String, allowInvalidElements: Bool) throws -> T {
    let transform = T.makeTransform(allowInvalidElements: allowInvalidElements)
    return try self.decode(path: .key(key), transform: transform)
  }

  /// Decode a required Decodable type by key
  public func decode<T: Decodable>(key: String) throws -> T {
    return try self.decode(path: .key(key), transform: T.makeTransform())
  }

  /// Decode a required DecodableWithContext type by key
  public func decode<T: DecodableWithContext>(key: String, context: T.DecodeContext) throws -> T {
    return try self.decode(path: .key(key), transform: T.makeTransform(context: context))
  }

  /// Decode a required collection of DecodableWithContext values by key
  public func decode<C: DecodableCollection, V: DecodableWithContext>(
    key: String,
    context: V.DecodeContext,
    allowInvalidElements: Bool = false) throws -> C where C.DecodeValue == V {
    return try self.decode(path: .key(key), transform: V.makeCollectionTransform(
      context: context,
      allowInvalidElements: allowInvalidElements))
  }

  /// Decode a required value using a formatter by key
  public func decode<F: DecodeFormatter>(key: String, formatter: F) throws -> F.DecodeFormattedType {
    return try self.decode(path: .key(key), transform: formatter.makeTransform())
  }

  /// Decode a required collection of values using a formatter by key
  public func decode<C: DecodableCollection, F: DecodeFormatter>(
    key: String,
    formatter: F,
    allowInvalidElements: Bool = false) throws -> C where C.DecodeValue == F.DecodeFormattedType {
    return try self.decode(
      path: .key(key),
      transform: formatter.makeCollectionTransform(allowInvalidElements: allowInvalidElements))
  }

  /// Decode a required value by key path
  public func decode<T: DecodeCompatible>(keyPath: String) throws -> T {
    return try self.decode(path: .keyPath(keyPath), transform: T.decode)
  }

  /// Decode a required collection by key path
  public func decode<T: DecodeCompatible>(keyPath: String,
                     allowInvalidElements: Bool) throws -> T where T: Collection{
    let transform = T.makeTransform(allowInvalidElements: allowInvalidElements)
    return try self.decode(path: .keyPath(keyPath), transform: transform)
  }

  /// Decode a required Decodable by key path
  public func decode<T: Decodable>(keyPath: String) throws -> T {
    return try self.decode(path: .keyPath(keyPath), transform: T.makeTransform())
  }

  /// Decode a required DecodableWithContext type by key path
  public func decode<T: DecodableWithContext>(keyPath: String,
                     context: T.DecodeContext) throws -> T {
    return try self.decode(path: .keyPath(keyPath), transform: T.makeTransform(context: context))
  }

  /// Decode a required collection of DecodableWithContext values by key path
  public func decode<C: DecodableCollection, V: DecodableWithContext>(
    keyPath: String,
    context: V.DecodeContext,
    allowInvalidElements: Bool = false) throws -> C where C.DecodeValue == V {
    return try self.decode(
      path: .keyPath(keyPath),
      transform: V.makeCollectionTransform(context: context,
                                           allowInvalidElements: allowInvalidElements))
  }

  /// Decode a required value using a formatter by key path
  public func decode<F: DecodeFormatter>(keyPath: String,
                     formatter: F) throws -> F.DecodeFormattedType {
    return try self.decode(path: .keyPath(keyPath), transform: formatter.makeTransform())
  }

  /// Decode a required collection of values using a formatter by key path
  public func decode<C: DecodableCollection, F: DecodeFormatter>(
    keyPath: String,
    formatter: F,
    allowInvalidElements: Bool = false) throws -> C where C.DecodeValue == F.DecodeFormattedType {
    return try self.decode(
      path: .keyPath(keyPath),
      transform: formatter.makeCollectionTransform(allowInvalidElements: allowInvalidElements))
  }

  /// Decode an optional value by key
  public func decode<T: DecodeCompatible>(key: String) -> T? {
    return try? self.decode(key: key)
  }

  /// Decode an optional collection by key
  public func decode<T: DecodableCollection>(key: String, allowInvalidElements: Bool) -> T? {
    return try? self.decode(key: key, allowInvalidElements: allowInvalidElements)
  }

  /// Decode an optional Decodable type by key
  public func decode<T: Decodable>(key: String) -> T? {
    return try? self.decode(key: key)
  }

  /// Decode an optional DecodableWithContext type by key
  public func decode<T: DecodableWithContext>(key: String, context: T.DecodeContext) -> T? {
    return try? self.decode(key: key, context: context)
  }

  /// Decode an optional collection of DecodableWithContext values by key
  public func decode<C: DecodableCollection, V: DecodableWithContext>(
    key: String,
    context: V.DecodeContext,
    allowInvalidElements: Bool = false) -> C? where C.DecodeValue == V {
    return try? self.decode(key: key, context: context, allowInvalidElements: allowInvalidElements)
  }

  /// Decode an optional value using a formatter by key
  public func decode<F: DecodeFormatter>(key: String, formatter: F) -> F.DecodeFormattedType? {
    return try? self.decode(key: key, formatter: formatter)
  }

  /// Decode an optional collection of values using a formatter by key
  public func decode<C: DecodableCollection, F: DecodeFormatter>(
    key: String,
    formatter: F,
    allowInvalidElements: Bool = false) -> C? where C.DecodeValue == F.DecodeFormattedType {
    return try? self.decode(key: key,
                            formatter: formatter,
                            allowInvalidElements: allowInvalidElements)
  }

  /// Decode an optional value by key path
  public func decode<T: DecodeCompatible>(keyPath: String) -> T? {
    return try? self.decode(keyPath: keyPath)
  }

  /// Decode an optional collection by key path
  public func decode<T: DecodableCollection>(keyPath: String, allowInvalidElements: Bool) -> T? {
    return try? self.decode(keyPath: keyPath, allowInvalidElements: allowInvalidElements)
  }

  /// Decode an optional Decodable type by key path
  public func decode<T: Decodable>(keyPath: String) -> T? {
    return try? self.decode(keyPath: keyPath)
  }

  /// Decode an optional DecodableWithContext type by key path
  public func decode<T: DecodableWithContext>(keyPath: String, context: T.DecodeContext) -> T? {
    return try? self.decode(keyPath: keyPath, context: context)
  }

  /// Decode an optional collection of DecodableWithContext values by key path
  public func decode<C: DecodableCollection, V: DecodableWithContext>(
    keyPath: String,
    context: V.DecodeContext,
    allowInvalidElements: Bool = false) -> C? where C.DecodeValue == V {
    return try? self.decode(keyPath: keyPath,
                            context: context,
                            allowInvalidElements: allowInvalidElements)
  }

  /// Decode an optional value using a formatter by key path
  public func decode<F: DecodeFormatter>(keyPath: String, formatter: F) -> F.DecodeFormattedType? {
    return try? self.decode(keyPath: keyPath, formatter: formatter)
  }

  /// Decode an optional collection of values using a formatter by key path
  public func decode<C: DecodableCollection, F: DecodeFormatter>(
    keyPath: String,
    formatter: F,
    allowInvalidElements: Bool = false) -> C? where C.DecodeValue == F.DecodeFormattedType {
    return try? self.decode(keyPath: keyPath,
                            formatter: formatter,
                            allowInvalidElements: allowInvalidElements)
  }
}

extension Decoder {
  func performDecodeing<T: Decodable>() throws -> T {
    return try T(decoder: self)
  }

  func performDecodeing<T: DecodableWithContext>(context: T.DecodeContext) throws -> T {
    return try T(decoder: self, context: context)
  }
}

private extension Decoder {
  func decode<R>(path: DecodePath, transform: DecodeTransform<R>) throws -> R {
    do {
      switch path {
      case .key(let key):
        let value = try self.dictionary[key].orThrow(DecodePathError.missingKey(key))
        return try transform(value).orThrow(DecodePathError.invalidValue(value, key))
      case .keyPath(let keyPath):
        var node: DecodePathNode = self.dictionary
        let components = keyPath.components(separatedBy: ".")
        let lastKey = components.last
        for key in components {
          guard let nextValue = node.decodePathValue(forKey: key) else {
            throw DecodePathError.missingKey(key)
          }
          if key == lastKey {
            return try transform(nextValue).orThrow(DecodePathError.invalidValue(nextValue, key))
          }
          guard let nextNode = nextValue as? DecodePathNode else {
            throw DecodePathError.invalidValue(nextValue, key)
          }
          node = nextNode
        }

        throw DecodePathError.emptyKeyPath
      }
    } catch {
      if let publicError = error as? DecodeError {
        throw publicError
      } else if let pathError = error as? DecodePathError {
        throw DecodeError.pathError(pathError, path.description)
      }

      throw error
    }
  }

  func performCustomDecodeing<T>(closure: (Decoder) throws -> T?) throws -> T {
    return try closure(self).orThrow(DecodeError.customDecodeingFailed)
  }
}
