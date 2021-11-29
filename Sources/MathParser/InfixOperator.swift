// Copyright © 2021 Brad Howes. All rights reserved.

import Foundation
import Parsing

/**
 Parser for left-associative infix operators. Takes a parser for operators to recognize and a parser for values to use
 with the operator which could include operations that are of higher precedence than those parsed by the first parser.

 NOTE: this parser will succeed if it can parse at least one operand value. This can be problematic if you want to
 have an `orElse` case for a failed binary expression.

 Based on InfixOperator found in the Arithmetic perf test of https://github.com/pointfreeco/swift-parsing
 */
internal struct InfixOperator<Operator, Operand>: Parser
where Operator: Parser, Operand: Parser,
      Operator.Input == Operand.Input,
      Operator.Output == (Operand.Output, Operand.Output) -> Operand.Output
{
  @usableFromInline
  let parser: (inout Operand.Input) -> Operand.Output?

  /**
   Construct new parser

   - parameter operator: the parser that recognizes valid operators at a certain precedence level
   - parameter operand: the parser for values to provide to the operator that may include operations at a higher
   precedence level
   */
  @inlinable
  init(operator: Operator, higher operand: Operand) {
    self.parser = { Self.leftAssociative(input: &$0, operand: operand, operator: `operator`) }
  }

  /**
   Implementation of Parser method. Looks for "operand operator operand" sequences, but also succeeds on just a
   sole initial "operand" parse for the left-hand or right-hand side of the expression (depending on the associativity
   value given in the constructor).

   - parameter input: the input stream to parse
   - returns: the next output value found in the stream, or nil if no match
   */
  @inlinable
  func parse(_ input: inout Operand.Input) -> Operand.Output? {
    self.parser(&input)
  }

  @usableFromInline
  static func leftAssociative(input: inout Operand.Input, operand: Operand, operator: Operator) -> Operand.Output? {
    guard var lhs = operand.parse(&input) else { return nil }
    var rest = input
    while
      let operation = `operator`.parse(&input),
      let rhs = operand.parse(&input)
    {
      rest = input
      lhs = operation(lhs, rhs)
    }
    input = rest
    return lhs
  }
}

