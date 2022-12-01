// Copyright © 2021 Brad Howes. All rights reserved.

import Parsing
import XCTest

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

  /// Mapping of names to an optional transform function of 1 argument
  public typealias UnaryFunctionMap = (String) -> ((Double) -> Double)?

  /// Mapping of names to an optional transform function of 2 arguments
  public typealias BinaryFunctionMap = (String) -> ((Double, Double) -> Double)?

  /// Default symbols to use for parsing.
  public static let defaultSymbols: [String: Double] = ["pi": .pi, "π": .pi, "e": .e]

  /// Default 1-ary functions to use for parsing.
  public static let defaultUnaryFunctions: [String: (Double) -> Double] = [
    "sin": sin, "cos": cos, "tan": tan,
    "log10": log10, "ln": log, "loge": log, "log2": log2, "exp": exp,
    "ceil": ceil, "floor": floor, "round": round,
    "sqrt": sqrt, "√": sqrt,
    // cube root
    "cbrt": cbrt
  ]

  /// Default 2-ary functions to use for parsing.
  public static let defaultBinaryFunctions: [String: (Double, Double) -> Double] = [
    "atan2": atan2,
    "hypot": hypot,
    "pow": pow // Redundant since we support x^b expressions
  ]

  /// Symbol mapping to use during parsing and perhaps evaluation
  public let symbols: SymbolMap

  /// Function mapping to use during parsing and perhaps evaluation
  public let unaryFunctions: UnaryFunctionMap

  /// Function mapping to use during parsing and perhaps evaluation
  public let binaryFunctions: BinaryFunctionMap

  /**
   Construct new parser. Only supports unary functions

   - parameter symbols: optional mapping of names to constants. If not given, `defaultSymbols` will be used
   - parameter functions: optional mapping of names to 1-ary functions. If not given, `defaultUnaryFunctions` will be
   used
   - parameter enableImpliedMultiplication: if true treat expressions like `2π` as valid and same as `2 * π`
   */
  public init(symbols: SymbolMap? = nil,
              functions: UnaryFunctionMap? = nil,
              enableImpliedMultiplication: Bool = false) {
    self.symbols = symbols ?? { Self.defaultSymbols[$0] }
    self.unaryFunctions = functions ?? { Self.defaultUnaryFunctions[$0] }
    self.binaryFunctions = { Self.defaultBinaryFunctions[$0] }
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }

  /**
   Construct new parser that supports unary and binary functions.

   - parameter symbols: optional mapping of names to constants. If not given, `defaultSymbols` will be used
   - parameter unaryFunctions: optional mapping of names to 1-ary functions. If not given, `defaultUnaryFunctions` will
   be used
   - parameter binaryFunctions: optional mapping of names to 2-ary functions. If not given, `defaultBinaryFunctions`
   will be used
   - parameter enableImpliedMultiplication: if true treat expressions like `2π` as valid and same as `2 * π`
   */
  public init(symbols: SymbolMap? = nil,
              unaryFunctions: UnaryFunctionMap? = nil,
              binaryFunctions: BinaryFunctionMap? = nil,
              enableImpliedMultiplication: Bool = false) {
    self.symbols = symbols ?? { Self.defaultSymbols[$0] }
    self.unaryFunctions = unaryFunctions ?? { Self.defaultUnaryFunctions[$0] }
    self.binaryFunctions = binaryFunctions ?? { Self.defaultBinaryFunctions[$0] }
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }

  // MARK: -

  /**
   Parse an expression into a token that can be evaluated at a later time.

   - parameter text: the expression to parse
   - returns: optional Evaluator to use to obtain results from the parsed expression. This is nil if expression was not
   valid.
   */
  public func parse(_ text: String) -> Evaluator? {
    guard let token = try? expression.parse(text) else { return nil }
    return Evaluator(token: token, symbols: self.symbols, unaryFunctions: self.unaryFunctions,
                     binaryFunctions: self.binaryFunctions)
  }

  // MARK: -

  /// Parser for start of identifier (constant, variable, function). All must start with a letter.
  private lazy var identifierStart = Parse { Prefix(1) { $0.isLetter } }

  /// Parser for remaining parts of identifier (constant, variable, function)
  private lazy var identifierRemaining = Parse { Prefix { $0.isNumber || $0.isLetter } }

  /// Parser for identifier such as a function name or a symbol.
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
      "+".map { { Token.reducer(lhs: $0, rhs: $1, operation: (+)) } }
      "-".map { { Token.reducer(lhs: $0, rhs: $1, operation: (-)) } }
    }
  }

  /// Parser for valid addition / subtraction operations. This is the starting point of precedence-involved parsing.
  /// Use type erasure due to circular references to this parser in others that follow.
  private lazy var additionAndSubtraction: TokenParser = LeftAssociativeInfixOperation(
    additionOrSubtractionOperator,
    higher: multiplicationAndDivision
  ).eraseToAnyParser()

  /// When true, two parsed operands in a row implies multiplication
  private let enableImpliedMultiplication: Bool

  /// Parser for multiplication / division operator. Also recognizes × for multiplication and ÷ for division.
  private lazy var multiplicationOrDivisionOperator = Parse {
    ignoreSpaces
    OneOf {
      "*".map { { Token.reducer(lhs: $0, rhs: $1, operation: (*)) } }
      "×".map { { Token.reducer(lhs: $0, rhs: $1, operation: (*)) } }
      "/".map { { Token.reducer(lhs: $0, rhs: $1, operation: (/)) } }
      "÷".map { { Token.reducer(lhs: $0, rhs: $1, operation: (/)) } }
    }
  }

  /// Parser for valid multiplication / division operations. Higher precedence than + and -
  /// If `enableImpliedMultiplication` is `true` then one can list two operands together
  /// like `2x` and have it treated as a multiplication of `2` and the value in `x`. Note that this does not work for
  /// expression `x2` since that would be treated as the name of a symbol or function.
  private lazy var multiplicationAndDivision = LeftAssociativeInfixOperation(
    multiplicationOrDivisionOperator,
    higher: exponentiation,
    implied: enableImpliedMultiplication ? { Token.reducer(lhs: $0, rhs: $1, operation: (*)) } : nil
  )

  /// Parser for exponentiation (power) operator
  private lazy var exponentiationOperator = Parse {
    ignoreSpaces
    "^".map { { Token.reducer(lhs: $0, rhs: $1, operation: (pow)) } }
  }

  /// Parser for exponentiation operation. Higher precedence than * and /
  private lazy var exponentiation = LeftAssociativeInfixOperation(
    exponentiationOperator,
    higher: operand
  )

  /**
   Attempt to split a symbol into multiplication of two or more items. This is used when `enableImpliedMultiplication`
   is `true`. It takes a simple approach of looking for known symbols at the start and end of a symbol name. When a
   match is found, it constructs a multiplication of two new symbols, one of which is converted into a constant.

   This routine is used both during the initial parse of the function definition *and* during the evaluation of the
   function if there are unknown symbols in need of resolution.

   - parameter name: the name to split
   - parameter symbols: the symbol map to use to locate a known symbol name
   - returns: optional Token that describes one or more multiplications that came from the given name
   */
  public static func attemptToSplitForMultiplication(name: Substring, symbols: SymbolMap) -> Token? {
    for count in 1..<name.count {
      let lhsName = name.dropLast(count)
      let rhsName = name.suffix(count)
      if let value = symbols(String(lhsName)) {
        let lhs: Token = .constant(value)
        let rhs = attemptToSplitForMultiplication(name: rhsName, symbols: symbols) ?? .variable(String(rhsName))
        return Token.reducer(lhs: lhs, rhs: rhs, operation: (*))
      }
      else if let value = symbols(String(rhsName)) {
        let lhs = attemptToSplitForMultiplication(name: lhsName, symbols: symbols) ?? .variable(String(lhsName))
        let rhs: Token = .constant(value)
        return Token.reducer(lhs: lhs, rhs: rhs, operation: (*))
      }
    }
    return nil
  }

  /// Parser for a symbol. If symbol exists during parse, parser returns `.constant` token. Otherwise, parser returns
  /// `.symbol` token for later evaluation when the symbol is known.
  private lazy var symbolOrVariable = Parse {
    identifier
  }.map { (name: Substring) -> Token in

    // If the symbol is defined, use its value.
    if let value = self.symbols(String(name)) {
      return .constant(value)
    }

    // If implied-multiplication is allowed, look for symbols next to other symbols. This is risky if one symbol name
    // is a substring of another symbol name -- say `e` and a variable called `value` which will be taken as `valu * e`
    // by the following code. Two solutions to that: don't enable implied multiplication or avoid names that start/end
    // with other symbols.
    if self.enableImpliedMultiplication {
      if let token = MathParser.attemptToSplitForMultiplication(name: name, symbols: self.symbols) {
        return token
      }
    }

    // Treat as a symbol that will be resolved when evaluated for a result.
    return .variable(String(name))
  }

  /// Parser for expression in parentheses. Use Lazy due to recursive nature of this definition.
  private lazy var parenthetical = Lazy {
    "("
    self.additionAndSubtraction
    ignoreSpaces
    ")"
  }

  /// Parser for function call of 1 parameter. Use Lazy due to recursive nature of this definition.
  private lazy var functionArgs1 = Lazy {
    self.additionAndSubtraction
    ignoreSpaces
  }

  /// Parser for a single argument function call (eg `sin`).
  private lazy var function1 = Parse {
    identifier
    "("
    functionArgs1
    ")"
  }.map { (tuple) -> Token in
    let name = String(tuple.0)
    let token = tuple.1
    if let resolved = self.unaryFunctions(name) {
      // Known function name
      if case .constant(let value) = token {
        // Known constant value -- evaluate function with it and return new constant value
        return .constant(resolved(value))
      }
      return .function1(name, token)
    }

    // We don't know the function at this time, should we treat as a variable multiplying a parenthetical expression?
    return self.enableImpliedMultiplication ? Token.reducer(lhs: .variable(name), rhs: token, operation: (*)) :
      .function1(name, token)
  }

  /// Parser for function call of 2 parameters. Use Lazy due to recursive nature of this definition.
  private lazy var functionArgs2 = Lazy {
    self.additionAndSubtraction
    ignoreSpaces
    ","
    ignoreSpaces
    self.additionAndSubtraction
    ignoreSpaces
  }

  /// Parser for a single argument function call (eg `atan2`).
  private lazy var function2 = Parse {
    identifier
    "("
    functionArgs2
    ")"
  }.map { (tuple) -> Token in
    let name = String(tuple.0)
    let arg1 = tuple.1.0
    let arg2 = tuple.1.1
    if let resolved = self.binaryFunctions(name),
       case .constant(let value1) = arg1,
       case .constant(let value2) = arg2 {
      // Known constant values -- evaluate function with it and return new constant value
      return .constant(resolved(value1, value2))
    }
    // Cannot reduce to a value at this time
    return .function2(name, arg1, arg2)
  }

  /// Parser for an operand of an expression. Note that order is important: a function is made up of an identifier
  /// followed by a parenthetical expression, so it must be before `parenthetical` and `symbolOrVariable`.
  private lazy var operand = Parse {
    ignoreSpaces
    OneOf {
      function2
      function1
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
}

/// Common expression for ignoring spaces in other parsers
private let ignoreSpaces = Skip { Optionally { Prefix { $0.isWhitespace } } }
