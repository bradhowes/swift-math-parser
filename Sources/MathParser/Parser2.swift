import Parsing
import Foundation

struct Parser2 {

  typealias TokenParser = Parser<Substring, Token>

  /// Parser for start of identifier (constant, variable, function). All must start with a letter.
  let identifierStart = Parse(input: Substring.self) { Prefix(1) { $0.isLetter } }

  /// Parser for remaining parts of identifier (constant, variable, function)
  let identifierRemaining = Parse(input: Substring.self) {
    Prefix { $0.isNumber || $0.isLetter || $0 == Character("_") }
  }

  /// Parser for identifier such as a function name or a symbol.
  lazy var identifier = Parse(input: Substring.self) {
    identifierStart
    identifierRemaining
  }.map { $0.0 + $0.1 }

  let constant: any TokenParser = Parse { Double.parser().map { Token.constant(value: $0) } }
}
