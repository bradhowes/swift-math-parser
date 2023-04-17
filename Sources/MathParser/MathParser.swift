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
  public typealias UnaryFunction = (Double) -> Double
  public typealias BinaryFunction = (Double, Double) -> Double

  /// Deprecated
  @available(*, deprecated, message: "Use VariableMap instead.")
  public typealias SymbolMap = (String) -> Double?

  /// Mapping of variable names to an optional Double.
  public typealias VariableMap = (String) -> Double?

  /// Mapping of names to an optional transform function of 1 argument
  public typealias UnaryFunctionMap = (String) -> UnaryFunction?

  /// Mapping of names to an optional transform function of 2 arguments
  public typealias BinaryFunctionMap = (String) -> BinaryFunction?

  /// Default symbols to use for parsing.
  public static let defaultVariables: [String: Double] = ["pi": .pi, "π": .pi, "e": .e]
  public static var defaultSymbols: [String: Double] { defaultVariables }

  /// Default 1-ary functions to use for parsing.
  public static let defaultUnaryFunctions: [String: UnaryFunction] = [
    "sin": sin, "cos": cos, "tan": tan,
    "log10": log10, "ln": log, "loge": log, "log2": log2, "exp": exp,
    "ceil": ceil, "floor": floor, "round": round,
    "sqrt": sqrt, "√": sqrt,
    "cbrt": cbrt // cube root
  ]

  /// Default 2-ary functions to use for parsing.
  public static let defaultBinaryFunctions: [String: BinaryFunction] = [
    "atan2": atan2,
    "hypot": hypot,
    "pow": pow // Redundant since we support x^b expressions
  ]

  /// Symbol mapping to use during parsing and perhaps evaluation
  public let variables: VariableMap

  /// Symbol mapping to use during parsing and perhaps evaluation
  @available(*, deprecated, message: "Use variables attribute instead.")
  public var symbols: VariableMap { variables }

  /// Function mapping to use during parsing and perhaps evaluation
  public let unaryFunctions: UnaryFunctionMap

  /// Function mapping to use during parsing and perhaps evaluation
  public let binaryFunctions: BinaryFunctionMap

  /**
   Construct new parser.

   - parameter variables: optional mapping of names to variables. If not given, `defaultVariables` will be used
   - parameter unaryFunctions: optional mapping of names to 1-ary functions. If not given, `defaultUnaryFunctions` will
   be used
   - parameter binaryFunctions: optional mapping of names to 2-ary functions. If not given, `defaultBinaryFunctions`
   will be used
   - parameter enableImpliedMultiplication: if true treat expressions like `2π` as valid and same as `2 * π`
   */
  public init(variables: VariableMap? = nil,
              unaryFunctions: UnaryFunctionMap? = nil,
              binaryFunctions: BinaryFunctionMap? = nil,
              enableImpliedMultiplication: Bool = false) {
    self.variables = variables ?? { Self.defaultVariables[$0] }
    self.unaryFunctions = unaryFunctions ?? { Self.defaultUnaryFunctions[$0] }
    self.binaryFunctions = binaryFunctions ?? { Self.defaultBinaryFunctions[$0] }
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }

  @available(*, deprecated, message: "Use init with variables and binaryFunction parameters.")
  public init(symbols: SymbolMap?,
              unaryFunctions: UnaryFunctionMap? = nil,
              binaryFunctions: BinaryFunctionMap? = nil,
              enableImpliedMultiplication: Bool = false) {
    self.variables = symbols ?? { Self.defaultVariables[$0] }
    self.unaryFunctions = unaryFunctions ?? { Self.defaultUnaryFunctions[$0] }
    self.binaryFunctions = binaryFunctions ?? { Self.defaultBinaryFunctions[$0] }
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }

  @available(*, deprecated, message: "Use init with variables and binaryFunction parameters.")
  public init(symbols: SymbolMap?,
              functions: UnaryFunctionMap? = nil,
              enableImpliedMultiplication: Bool = false) {
    self.variables = symbols ?? { Self.defaultVariables[$0] }
    self.unaryFunctions = functions ?? { Self.defaultUnaryFunctions[$0] }
    self.binaryFunctions = { Self.defaultBinaryFunctions[$0] }
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
    return Evaluator(token: token, usingImpliedMultiplication: enableImpliedMultiplication)
  }

  // MARK: - implementation details

  /// Parser for start of identifier (constant, variable, function). All must start with a letter.
  private var identifierStart = Parse(input: Substring.self) { Prefix(1) { $0.isLetter } }

  /// Parser for remaining parts of identifier (constant, variable, function)
  private var identifierRemaining = Parse(input: Substring.self) { Prefix { $0.isNumber || $0.isLetter } }

  /// Parser for identifier such as a function name or a symbol.
  private lazy var identifier = Parse(input: Substring.self) {
    identifierStart
    identifierRemaining
  }.map { $0.0 + $0.1 }

  /// Type of the parser that returns a Token
  private typealias TokenParser = Parser<Substring, Token>
  private typealias Ary2Parser = Parser<Substring, (Token, Token)>
  private typealias TR = (Token, Token) -> Token

  /// Parser for a numeric constant
  private var constant: some TokenParser = Parse { Double.parser().map { Token.constant(value: $0) } }

  /// Parser for addition / subtraction operator.
  private var additionOrSubtractionOperator: some Parser<Substring, TR> = Parse {
    ignoreSpaces
    OneOf {
      "+".map { { Token.reducer(lhs: $0, rhs: $1, operation: (+)) } }
      "-".map { { Token.reducer(lhs: $0, rhs: $1, operation: (-)) } }
    }
  }

  /// Parser for valid addition / subtraction operations. This is the starting point of precedence-involved parsing.
  /// Use type erasure due to circular references to this parser in others that follow.
  private lazy var additionAndSubtraction: some TokenParser = LeftAssociativeInfixOperation(
    additionOrSubtractionOperator,
    higher: multiplicationAndDivision
  ).eraseToAnyParser()

  /// When true, two parsed operands in a row implies multiplication
  private let enableImpliedMultiplication: Bool

  /// Parser for multiplication / division operator. Also recognizes × for multiplication and ÷ for division.
  private var multiplicationOrDivisionOperator: some Parser<Substring, TR> = Parse {
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
  private lazy var multiplicationAndDivision: some TokenParser = LeftAssociativeInfixOperation(
    multiplicationOrDivisionOperator,
    higher: exponentiation,
    implied: enableImpliedMultiplication ? { Token.reducer(lhs: $0, rhs: $1, operation: (*)) } : nil
  )

  /// Parser for exponentiation (power) operator
  private var exponentiationOperator: some Parser<Substring, TR> = Parse {
    ignoreSpaces
    "^".map { { Token.reducer(lhs: $0, rhs: $1, operation: (pow)) } }
  }

  /// Parser for exponentiation operation. Higher precedence than * and /
  private lazy var exponentiation: some TokenParser = LeftAssociativeInfixOperation(
    exponentiationOperator,
    higher: operand
  )

  /// Parser for a symbol. If symbol exists during parse, parser returns `.constant` token. Otherwise, parser returns
  /// `.symbol` token for later evaluation when the symbol is known.
  private lazy var symbolOrVariable: some TokenParser = Parse {
    identifier
  }.map { (name: Substring) -> Token in

    // If the symbol is defined, use its value.
    if let value = self.variables(String(name)) {
      return .constant(value: value)
    }

    // If implied-multiplication is allowed, look for symbols next to other symbols. This is risky if one symbol name
    // is a substring of another symbol name -- say `e` and a variable called `value` which will be taken as `valu * e`
    // by the following code. Two solutions to that: don't enable implied multiplication or avoid names that start/end
    // with other symbols.
    if self.enableImpliedMultiplication {
      if let token = Token.attemptImpliedMultiplication(name: name, variables: self.variables) {
        return token
      }
    }

    // Treat as a symbol that will be resolved when evaluated for a result.
    return .variable(name: String(name))
  }

  /// Parser for expression in parentheses. Use Lazy due to recursive nature of this definition.
  private lazy var parenthetical: some TokenParser = Lazy {
    "("
    self.additionAndSubtraction
    ignoreSpaces
    ")"
  }

  /// Parser for function call of 1 parameter. Use Lazy due to recursive nature of this definition.
  private lazy var unaryCallArg: some TokenParser = Lazy {
    self.additionAndSubtraction
    ignoreSpaces
  }

  /// Parser for a single argument function call (eg `sin`).
  private lazy var unaryCall: some TokenParser = Parse {
    identifier
    "("
    unaryCallArg
    ")"
  }.map { (tuple) -> Token in
    let name = String(tuple.0)
    let arg = tuple.1
    if let resolved = self.unaryFunctions(name) {
      // Known function name
      if case .constant(let value) = arg {
        // Known constant value -- evaluate function with it and return new constant value
        return .constant(value: resolved(value))
      }
      return .unaryCall(proc: .proc(resolved), arg: arg)
    }
    return .unaryCall(proc: .name(name), arg: arg)
  }

  /// Parser for function call of 2 parameters. Use Lazy due to recursive nature of this definition.
  private lazy var binaryCallArgs: some Ary2Parser = Lazy {
    self.additionAndSubtraction
    ignoreSpaces
    ","
    ignoreSpaces
    self.additionAndSubtraction
    ignoreSpaces
  }

  /// Parser for a single argument function call (eg `atan2`).
  private lazy var binaryCall: some TokenParser = Parse  {
    identifier
    "("
    binaryCallArgs
    ")"
  }.map { (tuple) -> Token in
    let name = String(tuple.0)
    let arg1 = tuple.1.0
    let arg2 = tuple.1.1
    if let resolved = self.binaryFunctions(name) {
      if case let .constant(value1) = arg1,
         case let .constant(value2) = arg2 {
        return .constant(value: resolved(value1, value2))
      }
      return .binaryCall(proc: .proc(resolved), arg1: arg1, arg2: arg2)
    }
    return .binaryCall(proc: .name(name), arg1: arg1, arg2: arg2)
  }

  /// Parser for an operand of an expression. Note that order is important: a function is made up of an identifier
  /// followed by a parenthetical expression, so it must be before `parenthetical` and `symbolOrVariable`.
  private lazy var operand: some TokenParser = Parse {
    ignoreSpaces
    OneOf {
      binaryCall
      unaryCall
      parenthetical
      symbolOrVariable
      constant
    }
  }

  /// Parser for a math expression. Checks that there is nothing remaining to be parsed.
  private lazy var expression: some TokenParser = Parse {
    additionAndSubtraction
    ignoreSpaces
    End()
  }
}

/// Common expression for ignoring spaces in other parsers
private let ignoreSpaces = Skip { Optionally { Prefix<Substring> { $0.isWhitespace } } }
