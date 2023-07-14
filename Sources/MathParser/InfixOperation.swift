// Copyright © 2021 Brad Howes. All rights reserved.

import Parsing

/**
 Parser for left-associative infix operations. Takes a parser for operators to recognize and a parser for values to use
 with the operator which could include operations that are of higher precedence than those parsed by the first parser.

 NOTE: this parser will succeed if it can parse at least one operand value. This can be problematic if you want to
 have an alternative case for a failed binary expression.

 Based on InfixOperator found in the Arithmetic perf test of https://github.com/pointfreeco/swift-parsing
 */
struct InfixOperation: Parser {
  typealias Input = Substring
  typealias Output = Token

  private let name: String
  private let associativity: Associativity
  private let `operator`: any TokenReducerParser
  private let operand: any TokenParser
  private let impliedOperation: TokenReducer?
  public var logging: Bool

  /**
   Construct new parser

   - parameter name: the name assigned to the parser
   - parameter associativity: determines how operators bind to their operands
   - parameter operator: the parser that recognizes valid operators at a certain precedence level
   - parameter operand: the parser for values to provide to the operator that may include operations at a higher
   precedence level
   - parameter impliedOperation: optional ``TokenReducer`` that if present will be used if there is no operator token
   */
  @inlinable
  init(name: String,
       associativity: Associativity,
       operator: any TokenReducerParser,
       operand: any TokenParser,
       implied: TokenReducer? = nil,
       logging: Bool = false) {
    self.name = name
    self.associativity = associativity
    self.operator = `operator`
    self.operand = operand
    self.impliedOperation = implied
    self.logging = logging
  }
}

extension InfixOperation {

  /**
   Implementation of Parser method. Looks for "operand operator operand" sequences. There is a special case when
   `self.implied` is not nil: if two operands follow one another, then the operator from `self.implied` will be used
   for the "missing" operator.

   - parameter input: the input stream to parse
   - returns: the next output value found in the stream
   */
  @inlinable
  func parse(_ input: inout Input) throws -> Token {
    log("parse", rest: input.prefix(40))
    switch self.associativity {
    case .left:
      var lhs = try self.operand.parse(&input)
      log("got", lhs: lhs)
      var rest = input
      while true {
        if let operation = (try? self.operator.parse(&input)) ?? impliedOperation {
          log("got op")
          do {
            let rhs = try self.operand.parse(&input)
            log("got", rhs: rhs)
            rest = input
            lhs = operation(lhs, rhs)
            log("new", lhs: lhs)
            continue
          } catch {
          }
        }
        // Reset and end parse
        input = rest
        log("done", rest: rest.prefix(40))
        return lhs
      }
    case .right:

      // Build up successive right-associative operations in a stack, which are then applied in reverse order using the
      // final right-hand operand.
      var lhs: [(TokenReducer, Token)] = []
      while true {
        let rhs = try self.operand.parse(&input)
        do {
          let operation = try self.operator.parse(&input)
          lhs.append((operation, rhs))
        } catch {
          return lhs.reversed().reduce(rhs) { $1.0($1.1, $0) }
        }
      }
    }
  }

  // Default action is to print log messages. Test case adapts to check logging is working.
  static var logSink: (String) -> Void = { print($0) }

  private func log(_ msg: String, lhs: Token? = nil, rhs: Token? = nil, rest: Substring? = nil) {
    guard self.logging else { return }
    var msg = "\(name) - \(msg)"
    if let lhs = lhs { msg += " lhs: \(lhs)" }
    if let rhs = rhs { msg += " rhs: \(rhs)" }
    if let rest = rest { msg += " rest: \(rest)" }
    Self.logSink(msg)
  }
}
