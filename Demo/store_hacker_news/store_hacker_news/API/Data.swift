import Foundation

struct Identifier<T>: Codable, Identifiable, ExpressibleByIntegerLiteral, Equatable, Hashable {
  typealias IntegerLiteralType = Int
  /// The wrapped identifier.
  let id: Int
    
  /// Creates an instance initialized to the specified integer value.
  init(integerLiteral value: Int) {
    id = value
  }
  
  /// Creates a new instance by decoding from the given decoder.
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    id = try container.decode(Int.self)
  }
  
  /// Encodes this value into the given encoder.
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(id)
  }
}

enum ItemType: String, Codable {
  case job, story, comment, poll, pollopt
}

struct Item: Codable, Identifiable {
  /// The item's unique id.
  let id: Identifier<Item>
  /// `true` if the item is deleted.
  let deleted: Bool?
  /// The type of item.
  let type: ItemType
  /// The username of the item's author.
  let by: String
  /// Creation date of the item, in Unix Time.
  let time: Int
  /// The comment, story or poll text. HTML.
  let text: String?
  /// The comment's parent: either another comment or the relevant story.
  let parent: Identifier<Item>?
  /// The pollopt's associated poll.
  let poll: Identifier<Item>?
  /// The ids of the item's comments, in ranked display order.
  let kids: [Identifier<Item>]?
  /// The URL of the story.
  let url: String?
  /// The story's score, or the votes for a pollopt.
  let score: Int?
  /// The title of the story, poll or job. HTML.
  let title: String
  /// A list of related pollopts, in display order.
  let parts: [Identifier<Item>]?
  /// In the case of stories or polls, the total comment count.
  let descendants: Int?
}

struct User: Codable, Identifiable {
  /// The user's unique username. Case-sensitive. Required.
  let id: String
  /// Creation date of the user, in Unix Time.
  let created: Int
  /// The user's karma.
  let karma: Int
  /// List of the user's stories, polls and comments.
  let submitted: [Identifier<Item>]?
}
