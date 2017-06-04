// Forked from johnsundell/Wrap
// See LICENSE file.

import Foundation

/// Type alias defining what type of Dictionary that Encode produces
public typealias EncodedDictionary = [String : Any]

/**
 *  Encode any object or value, encoding it into a JSON compatible Dictionary
 *
 *  - Parameter object: The object to encode
 *  - Parameter context: An optional contextual object that will be available throughout
 *    the encoding process. Can be used to inject extra information or objects needed to
 *    perform the encoding.
 *  - Parameter dateFormatter: Optionally pass in a date formatter to use to encode any
 *    `NSDate` values found while encoding the object. If this is `nil`, any found date
 *    values will be encoded using the "yyyy-MM-dd HH:mm:ss" format.
 *
 *  All the type's stored properties (both public & private) will be recursively
 *  encoded with their property names as the key.
 *
 *  The object passed to this function must be an instance of a Class, or a value
 *  based on a Struct. Standard library values, such as Ints, Strings, etc are not
 *  valid input.
 *
 *  Throws a EncodeError if the operation could not be completed.
 *
 *  For more customization options, make your type conform to `EncodeCustomizable`,
 *  that lets you override encoding keys and/or the whole encoding process.
 *
 *  See also `EncodableKey` (for dictionary keys) and `EncodableEnum` for Enum values.
 */
public func encode<T>(_ object: T,
                    context: Any? = nil,
                    dateFormatter: DateFormatter? = nil) throws -> EncodedDictionary {
  return try Encoder(context: context, dateFormatter: dateFormatter)
      .encode(object: object, enableCustomizedEncodeping: true)
}

/**
 *  Alternative `encode()` overload that returns JSON-based `Data`
 *
 *  See the documentation for the dictionary-based `encode()` function for more information
 */
public func encode<T>(_ object: T,
                    writingOptions: JSONSerialization.WritingOptions? = nil,
                    context: Any? = nil, dateFormatter: DateFormatter? = nil) throws -> Data {
  return try Encoder(context: context, dateFormatter: dateFormatter)
      .encode(object: object, writingOptions: writingOptions ?? [])
}

/**
 *  Alternative `encode()` overload that encodes an array of objects into an array of dictionaries
 *
 *  See the documentation for the dictionary-based `encode()` function for more information
 */
public func encode<T>(_ objects: [T],
                    context: Any? = nil,
                    dateFormatter: DateFormatter? = nil) throws -> [EncodedDictionary] {
  return try objects.map { try encode($0, context: context, dateFormatter: dateFormatter) }
}

/**
 *  Alternative `encode()` overload that encodes an array of objects into JSON-based `Data`
 *
 *  See the documentation for the dictionary-based `encode()` function for more information
 */
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

/**
 *  Protocol providing the main customization point for Encode
 *
 *  It's optional to implement all of the methods in this protocol, as Encode
 *  supplies default implementations of them.
 */
public protocol EncodeCustomizable {
  /**
   *  The style that encode should apply to the keys of a encoded dictionary
   *
   *  The value of this property is ignored if a type provides a custom
   *  implementation of the `keyForEncodeping(propertyNamed:)` method.
   */
  var encodeKeyStyle: EncodeKeyStyle { get }
  /**
   *  Override the encoding process for this type
   *
   *  All top-level types should return a `EncodedDictionary` from this method.
   *
   *  You may use the default encoding implementation by using a `Encoder`, but
   *  never call `encode()` from an implementation of this method, since that might
   *  cause an infinite recursion.
   *
   *  The context & dateFormatter passed to this method is any formatter that you
   *  supplied when initiating the encoding process by calling `encode()`.
   *
   *  Returning nil from this method will be treated as an error, and cause
   *  a `EncodeError.encodingFailedForObject()` error to be thrown.
   */
  func encode(context: Any?, dateFormatter: DateFormatter?) -> Any?
  /**
   *  Override the key that will be used when encoding a certain property
   *
   *  Returning nil from this method will cause Encode to skip the property
   */
  func keyForEncodeping(propertyNamed propertyName: String) -> String?
  /**
   *  Override the encoding of any property of this type
   *
   *  The original value passed to this method will be the original value that the
   *  type is currently storing for the property. You can choose to either use this,
   *  or just access the property in question directly.
   *
   *  The dateFormatter passed to this method is any formatter that you supplied
   *  when initiating the encoding process by calling `encode()`.
   *
   *  Returning nil from this method will cause Encode to use the default
   *  encoding mechanism for the property, so you can choose which properties
   *  you want to customize the encoding for.
   *
   *  If you encounter an error while attempting to encode the property in question,
   *  you can choose to throw. This will cause a EncodeError.EncodepingFailedForObject
   *  to be thrown from the main `encode()` call that started the process.
   */
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

/**
 *  Protocol implemented by Enums to enable them to be directly encoded
 *
 *  If an Enum implementing this protocol conforms to `RawRepresentable` (it's based
 *  on a raw type), no further implementation is required. If you wish to customize
 *  how the Enum is encoded, you can use the APIs in `EncodeCustomizable`.
 */
public protocol EncodableEnum: EncodeCustomizable {}

/// Protocol implemented by Date types to enable them to be encoded
public protocol EncodableDate {
  /// Encode the date using a date formatter, generating a string representation
  func encode(dateFormatter: DateFormatter) -> String
}

/**
 *  Class used to encode an object or value. Use this in any custom `encode()` implementations
 *  in case you only want to add on top of the default implementation.
 *
 *  You normally don't have to interact with this API. Use the `encode()` function instead
 *  to encode an object from top-level code.
 */
public class Encoder {
  fileprivate let context: Any?
  fileprivate var dateFormatter: DateFormatter?

  /**
   *  Initialize an instance of this class
   *
   *  - Parameter context: An optional contextual object that will be available throughout the
   *    encoding process. Can be used to inject extra information or objects needed to perform
   *    the encoding.
   *  - Parameter dateFormatter: Any specific date formatter to use to encode any found `NSDate`
   *    values. If this is `nil`, any found date values will be encoded using the "yyyy-MM-dd
   *    HH:mm:ss" format.
   */
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

// MARK: - Default protocol implementations

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

// MARK: - Private

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

// MARK: - Nil Handling

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
