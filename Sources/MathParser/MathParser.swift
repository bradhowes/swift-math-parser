// Copyright © 2021 Brad Howes. All rights reserved.

import Parsing
import XCTest
import Foundation

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#endif

/**
 General-purpose parser for simple math expressions made up of the common operations as well as single argument
 functions like `sqrt` and `sin` and named variables / symbols. For instance, the expression `4 * sin(t * pi)` is
 legal and references the `sin` function, the `pi` constant, and an unknown variable `t`. Parsing a legal expression
 results in an `Evaluator` that can be used to obtain Double results from the expression, such as when the
 value for `t` is known.
 */
final public class MathParser {

  /// Mapping of symbol names to an optional Double.
  public typealias SymbolMap = (String) -> Double?

  /// Mapping of names to an optional transform function
  public typealias FunctionMap = (String) -> ((Double) -> Double)?

  /// Default symbols to use for parsing.
  public static let defaultSymbols: [String: Double] = ["pi": .pi, "π": .pi, "e": Darwin.M_E]

  /// Default functions to use for parsing.
  public static let defaultFunctions: [String: (Double) -> Double] = [
    "sin": sin, "cos": cos, "tan": tan,
    "log10": log10, "ln": log, "loge": log, "log2": log2, "exp": exp,
    "ceil": ceil, "floor": floor, "round": round,
    "sqrt": sqrt
  ]

  /// Symbol mapping to use during parsing and perhaps evaluation
  public let symbols: SymbolMap

  /// Function mapping to use during parsing and perhaps evaluation
  public let functions: FunctionMap

  /// Parser for start of identifier (constant, variable, function)
  private lazy var identifierStart = Parse  {
    Prefix(1) { $0.isLetter }
  }

  /// Parser for remaining parts of identifier (constant, variable, function)
  private lazy var identifierRemaining = Parse {
    Prefix { $0.isNumber || $0.isLetter }
  }

  /// Parser for identifier
  private lazy var identifier = Parse {
    identifierStart
    identifierRemaining
  }.map { $0.0 + $0.1 }

  /// Type of the parser that returns a Token
  private typealias TokenParser = AnyParser<Substring, Token>

  /// Parser for a numeric constant
  private lazy var constant = Double.parser(of: Substring.self).map { Token.constant($0) }

  /// Parser for addition / subtraction operator.
  private lazy var additionOrSubtractionOperator = Parse {
    ignoreSpaces
    OneOf {
      "+".map { { tokenReducer(lhs: $0, rhs: $1, op: (+)) } }
      "-".map { { tokenReducer(lhs: $0, rhs: $1, op: (-)) } }
    }
  }

  /// Parser for valid addition / subtraction operations. This is the starting point of precedence-involved parsing.
  private lazy var additionAndSubtraction: TokenParser = LeftAssociativeInfixOperation(
    additionOrSubtractionOperator,
    higher: multiplicationAndDivision
  ).eraseToAnyParser()

  /// When true, two parsed operands in a row implies multiplication
  private let enableImpliedMultiplication: Bool

  /// Parser for multiplication / division operator.
  private lazy var multiplicationOrDivisionOperator = Parse {
    ignoreSpaces
    OneOf {
      "*".map { { tokenReducer(lhs: $0, rhs: $1, op: (*)) } }
      "/".map { { tokenReducer(lhs: $0, rhs: $1, op: (/)) } }
    }
  }

  /// Parser for valid multiplication / division operations. Higher precedence than + and -
  /// If `enableImpliedMultiplication` is `true` then one can list two operands together
  /// like `2x` and have it treated as a multiplication of `2` and the value in `x`.
  private lazy var multiplicationAndDivision = LeftAssociativeInfixOperation(
    multiplicationOrDivisionOperator,
    higher: exponentiation,
    implied: enableImpliedMultiplication ? { tokenReducer(lhs: $0, rhs: $1, op: (*)) } : nil
  )

  /// Parser for exponentiation (power) operator
  private lazy var exponentiationOperator = Parse {
    ignoreSpaces
    "^".map { { tokenReducer(lhs: $0, rhs: $1, op: (pow)) } }
  }

  /// Parser for exponentiation operation. Higher precedence than * /
  private lazy var exponentiation = LeftAssociativeInfixOperation(
    exponentiationOperator,
    higher: operand
  )

  /// Parser for a symbol. If symbol exists during parse, parser returns `.constant` token. Otherwise, parser returns
  /// `.symbol` token for later evaluation when the symbol is known.
  private lazy var symbolOrVariable = Parse {
    identifier
  }.map { (name: Substring) -> Token in
    let name = String(name)
    guard let value = self.symbols(name) else { return .variable(name) }
    return .constant(value)
  }

  /// Parser for expression in parentheses. Use Lazy due to recursive nature of this definition.
  private lazy var parenthetical = Lazy {
    "("
    self.additionAndSubtraction
    ignoreSpaces
    ")"
  }

  /// Parser for a single argument function call (eg `sin`). There are three Token types that this will resolve to:
  ///
  /// * `.constant` -- when function is already known and argument is `.constant`, this holds the result of calling the
  ///   function on the constant value.
  /// * `.function` -- token for later evaluation when the function and argument is known.
  /// * `.mathOp` -- implied multiplication operation when `enableImpliedMultiplication` is `true`.
  private lazy var function = Parse {
    identifier
    parenthetical
  }.map { (tuple) -> Token in
    let name = String(tuple.0)
    let token = tuple.1
    if let resolved = self.functions(name) {
      if case .constant(let value) = token {
        return .constant(resolved(value))
      }
      return .function(name, token)
    }
    if self.enableImpliedMultiplication {
      return tokenReducer(lhs: .variable(name), rhs: token, op: (*))
    }
    return .function(name, token)
  }

  /// Parser for an operand of an expression. Note that order is important: a function is made up of an identifier
  /// followed by a parenthetical expression, so it must be before `parenthetical` and `symbolOrVariable`.
  private lazy var operand = Parse {
    ignoreSpaces
    OneOf {
      function
      parenthetical
      symbolOrVariable
      constant
    }
  }

  /// Parser for a math expression. Checks that there is nothing remaining to be parsed.
  private lazy var expression = Parse {
    additionAndSubtraction
    ignoreSpaces
    End()
  }

  /**
   Construct new parser

   - parameter symbols: optional mapping of names to constants. If not given, `defaultSymbols` will be used
   - parameter functions: optional mapping of names to functions. If not given, `defaultFunctions` will be used
   - parameter enableImpliedMultiplication: if true treat expressions like `2 π` as valid and same as `2 * π`
   */
  public init(symbols: SymbolMap? = nil, functions: FunctionMap? = nil, enableImpliedMultiplication: Bool = false) {
    self.symbols = symbols ?? { Self.defaultSymbols[$0] }
    self.functions = functions ?? { Self.defaultFunctions[$0] }
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }
}

extension MathParser {

  /**
   Parse an expression into a token that can be evaluated at a later time.

   - parameter text: the expression to parse
   - returns: optional Evaluator to use to obtain results from the parsed expression. This is nil if expression was not
   valid.
   */
  public func parse(_ text: String) -> Evaluator? {
    guard let token = try? expression.parse(text) else { return nil }
    return Evaluator(token: token, symbols: self.symbols, functions: self.functions)
  }
}

fileprivate let ignoreSpaces = Skip { Optionally { Prefix { $0.isWhitespace } } }

/// All of our basic math operations reduce two inputs into one output.
fileprivate typealias Operation = (Double, Double) -> Double

fileprivate func tokenReducer(lhs: Token, rhs: Token, op: @escaping Operation) -> Token {
  if case let .constant(lhs) = lhs, case let .constant(rhs) = rhs {
    return .constant(op(lhs, rhs))
  }
  return .mathOp(lhs, rhs, op)
}
