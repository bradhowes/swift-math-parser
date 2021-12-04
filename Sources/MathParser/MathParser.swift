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

  private static func join(lhs: Token, rhs: Token, op: @escaping (Double, Double) -> Double) -> Token {
    if case let .constant(lhs) = lhs, case let .constant(rhs) = rhs {
      return .constant(op(lhs, rhs))
    }
    return .mathOp(lhs, rhs, op)
  }

  private typealias TokenParser = AnyParser<Substring.UTF8View, Token>

  private let ignoreSpaces = Skip(Whitespace())

  /// Parser for start of identifier
  private lazy var firstLetter = ignoreSpaces.pullback(\.utf8).take(Prefix(1) { $0.isLetter })

  /// Parser for remaining parts of identifier
  private let remaining = Prefix { $0.isNumber || $0.isLetter }

  /// Parser for a numeric constant
  private lazy var constant: TokenParser = ignoreSpaces
    .take(Double.parser().map { Token.constant($0) })
    .eraseToAnyParser()

  /// Parser for identifier
  private lazy var identifier = firstLetter.take(remaining).map { ($0.0 + $0.1) }

  /// Parser for addition / subtraction operations. This is the starting point of precedence-involved parsing.
  private lazy var additionAndSubtraction: TokenParser = InfixOperator(
    operator: ignoreSpaces
      .take(OneOfMany(
        "+".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (+)) } },
        "-".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (-)) } }
      )),
    higher: multiplicationAndDivision
  ).eraseToAnyParser()

  private let enableImpliedMultiplication: Bool

  /// Parser for multiplication / division operations. Higher precedence than + -
  /// NOTE: slight hack to support common math idiom of two values `X Y` indicating an implied multiplication. This is
  /// probably not the best way to do this, but I _don't_ think it can lead to invalid results. Better would be to redo
  /// operand parsing to specifically recognize and allow such expressions in the stream of parsed tokens. This would
  /// then allow stuff like `2(a + b)` which is not recognized here because there is no space between `2` and `(`.
  private lazy var multiplicationAndDivision: TokenParser = InfixOperator(
    operator:
      enableImpliedMultiplication ?
    Conditional.first(
      OneOfMany(
        ignoreSpaces
          .take("*".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (*)) } }).eraseToAnyParser(),
        ignoreSpaces
          .take("/".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (/)) } }).eraseToAnyParser(),
        " ".utf8.map({ { Self.join(lhs: $0, rhs: $1, op: (*)) } }).eraseToAnyParser()
      )
    )
    : Conditional.second(
      ignoreSpaces
        .take(OneOfMany(
          "*".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (*)) } },
          "/".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (/)) } }
        ))
    ),
    higher: exponent
  ).eraseToAnyParser()

  /// Parser for exponentiation operation. Higher precedence than * /
  private lazy var exponent: TokenParser = InfixOperator(
    operator: ignoreSpaces
      .take("^".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (pow)) } }),
    higher: operand
  ).eraseToAnyParser()

  /// Parser for a symbol. If symbol exists during parse, parser returns `.constant`. Otherwise, parser returns
  /// `.symbol` for later evaluation when the symbol is known.
  private lazy var symbolOrVariable: TokenParser = identifier
    .utf8
    .map { name in
      let name = String(name)
      guard let value = self.symbols(name) else { return .variable(name) }
      return .constant(value)
    }
    .eraseToAnyParser()

  /// Parser for expression in parentheses
  private lazy var parenthetical: TokenParser = ignoreSpaces
    .take("(".utf8)
    .take(Lazy { self.additionAndSubtraction })
    .skip(Whitespace())
    .take(")".utf8)
    .map { $0.1 }
    .eraseToAnyParser()

  /// Parser for a single argument function call (eg `sin`). If function is known and argument is `.constant`, the
  /// function is called and the parser returns `.constant` with the result. Otherwise, parser returns `.function`
  /// for later evaluation when the function and argument is known.
  private lazy var function: TokenParser = identifier
    .utf8
    .take(parenthetical)
    .map { tuple in
      let name = String(tuple.0)
      let token = tuple.1
      guard let function = self.functions(name),
            case .constant(let value) = token
      else {
        return .function(name, token)
      }
      return .constant(function(value))
    }
    .eraseToAnyParser()

  /// Parser for an operand of an expression.
  private lazy var operand: TokenParser = OneOfMany(
    function,
    parenthetical,
    constant,
    symbolOrVariable
  ).eraseToAnyParser()

  /// Parser for a math expression. Checks that there is nothing remaining to be parsed.
  private lazy var expression: TokenParser = additionAndSubtraction
    .skip(Whitespace())
    .skip(End())
    .eraseToAnyParser()

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
    guard let token = expression.parse(text) else { return nil }
    return Evaluator(token: token, symbols: self.symbols, functions: self.functions)
  }
}
