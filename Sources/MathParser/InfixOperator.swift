// Copyright © 2021 Brad Howes. All rights reserved.

import Parsing

/**
 Parser for left-associative infix operations. Takes a parser for operators to recognize and a parser for values to use
 with the operator which could include operations that are of higher precedence than those parsed by the first parser.

 NOTE: this parser will succeed if it can parse at least one operand value. This can be problematic if you want to
 have an alternative case for a failed binary expression.

 Based on InfixOperator found in the Arithmetic perf test of https://github.com/pointfreeco/swift-parsing
 If you want support for right-associative operators, check there for a more robust implementation that does both kinds.
 */
internal struct LeftAssociativeInfixOperation<Operator, Operand>: Parser
where Operator: Parser, Operand: Parser,
      Operator.Input == Operand.Input,
      Operator.Output == (Operand.Output, Operand.Output) -> Operand.Output {
  let `operator`: Operator
  let operand: Operand
  var implied: Operator.Output?

  /**
   Construct new parser

   - parameter operator: the parser that recognizes valid operators at a certain precedence level
   - parameter operand: the parser for values to provide to the operator that may include operations at a higher
   precedence level
   - parameter implied: an `Operator.Output` value to use when there is no operator to be found in the parse. This is
   only used to inject a multiplication operation between to operands when configured to do so.
   */
  @inlinable
  init(_ operator: Operator, higher operand: Operand, implied: Operator.Output? = nil) {
    self.operator = `operator`
    self.operand = operand
    self.implied = implied
  }

  /**
   Implementation of Parser method. Looks for "operand operator operand" sequences, but also succeeds on just a
   sole initial "operand" parse for the left-hand side of the expression. Raises exceptions on parser failures.

   - parameter input: the input stream to parse
   - returns: the next output value found in the stream
   */
  @inlinable
  func parse(_ input: inout Operand.Input) rethrows -> Operand.Output {
    var lhs = try self.operand.parse(&input)
    var rest = input
    while true {

      // If we can handle a missing operator, try for another operand
      if let implied = self.implied {
        do {
          let rhs = try self.operand.parse(&input)
          rest = input
          lhs = implied(lhs, rhs)
          continue
        } catch {
          input = rest
        }
      }

      // Parse operator followed by operand.
      do {
        let operation = try self.operator.parse(&input)
        let rhs = try self.operand.parse(&input)
        rest = input
        lhs = operation(lhs, rhs)
      } catch {
        input = rest
        return lhs
      }
    }
  }
}
