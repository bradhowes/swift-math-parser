// Copyright © 2023 Brad Howes. All rights reserved.

import Parsing
import Foundation

/**
 A parser for simple math expressions made up of five common operations addition, subtraction, multiplication,
 division, and exponentiation, as well as one- and two-argument functions like `sqrt` and `sin`, and named
 variables / symbols.

 The expression

 ```
 4 * sin(t * π)
 ```

 is a legal math expression according to the parser. It references the known `sin` function, the known `pi` constant
 (here using the symbol π),
 and an unknown variable `t`. Parsing a legal expression results in an ``Evaluator`` instance that can be used to obtain
 `Double` results from the expression, such as when the value for `t` is known.
 */

final public class MathParser {
  /// Type definition for a mapping of one `Double` value to another such as by a 1-argument function.
  public typealias UnaryFunction = (Double) -> Double
  /// Type definition for a reduction of two `Double` values to one such as by a 2-argument function.
  public typealias BinaryFunction = (Double, Double) -> Double
  /// Deprecated
  @available(*, deprecated, message: "Use VariableMap instead.")
  public typealias SymbolMap = (String) -> Double?
  /// Mapping of variable names to an optional Double.
  public typealias VariableMap = (String) -> Double?
  /// Dictionary of variable names and their values.
  public typealias VariableDict = [String: Double]
  /// Mapping of names to an optional transform function of 1 argument.
  public typealias UnaryFunctionMap = (String) -> UnaryFunction?
  /// Dictionary of unary function names and their implementations.
  public typealias UnaryFunctionDict = [String: UnaryFunction]
  /// Mapping of names to an optional transform function of 2 arguments
  public typealias BinaryFunctionMap = (String) -> BinaryFunction?
  /// Dictionary of binary function names and their implementations.
  public typealias BinaryFunctionDict = [String: BinaryFunction]

  /**
   Default symbols to use for parsing.

   - `pi` -- the transcendental number that is the ratio of a circle's circumference to it's diameter
   - `π` -- same as above but as a Unicode symbol
   - `e` -- the transcendental number that is the base of natural logarithms
   */
  public static let defaultVariables: [String: Double] = ["pi": .pi, "π": .pi, "e": .e]

  @available(*, deprecated, message: "Use defaultVariables class attribute instead.")
  public static var defaultSymbols: [String: Double] { defaultVariables }

  /**
   Default 1-argument functions to use for parsing and evaluation.

   - `sin` -- trigonometric function of an angle Θ in radians that represents the the ratio of the length of the side
   of a right triangle that is opposite to angle Θ and to the length of the hypotenuse.
   - `cos` -- trigonometric function of an angle Θ in radians that represents the the ratio of the length of the side
   of a right triangle that is adjacent to angle Θ and to the length of the hypotenuse.
   - `tan` -- trigonometric function that is the ratio of the opposite and adjacent sides of the triangle.
   - `log10` -- the base-10 logarithm of the given number.
   - `ln` -- the natural (base-e) logarithm of the given number.
   - `loge` -- alias for `ln`.
   - `log2` -- the base-2 logarithm of the given number.
   - `exp` -- the exponentiation of e to the given number (the inverse of the `ln` function).
   - `ceil` -- the largest integral value that is less than or equal to the given value.
   - `floor` -- the smallest integral value that is greater than or equal to the given value.
   - `round` -- computes the nearest integral value, rounding halfway cases away from zero.
   - `sqrt` -- computes the square-root of the given number
   - `√` -- same as above but as a Unicode symbol
   - `cbrt` -- computes the cube-root of the given number
   */
  public static let defaultUnaryFunctions: UnaryFunctionDict = [
    "sin": sin, "cos": cos, "tan": tan,
    "log10": log10, "ln": log, "loge": log, "log2": log2, "exp": exp,
    "ceil": ceil, "floor": floor, "round": round,
    "sqrt": sqrt, "√": sqrt,
    "cbrt": cbrt // cube root
  ]

  /**
   Default 2-argument functions to use for parsing and evaluation.

   - `atan2` -- calculate the angle measure in radians between the x-axis and a ray from the origin to a point (x, y).
   Note that the argument order to `atan2` is `y` then `x` by convention.
   - `hypot` -- returns the length of a ray from the origin to a point (x, y).
   Note that the argument order to `hypot` is `x` then `y` unlike that of `atan2`.
   - `pow` -- calculate the result of raising the first argument to the power of the second. Thus `pow(x, y)` is the
   same as writing `x ^ y`.
  */
  public static let defaultBinaryFunctions: BinaryFunctionDict = [
    "atan2": atan2,
    "hypot": hypot,
    "pow": pow // Redundant since we support x^b expressions
  ]

  /// Symbol/variable mapping to use during parsing and perhaps evaluation
  public let variables: VariableMap

  /// Symbol/variable mapping to use during parsing and perhaps evaluation
  @available(*, deprecated, message: "Use variables attribute instead.")
  public var symbols: VariableMap { variables }

  /// Function mapping to use during parsing and perhaps evaluation
  public let unaryFunctions: UnaryFunctionMap

  /// Function mapping to use during parsing and perhaps evaluation
  public let binaryFunctions: BinaryFunctionMap

  private let customVariableDict: VariableDict?
  private let customUnaryFunctionDict: UnaryFunctionDict?
  private let customBinaryFunctionDict: BinaryFunctionDict?

  /**
   Construct new parser.

   All parameters are optional; ``MathParser`` will work as you would expect without any configuration.

   - parameter variables: optional mapping of names to variables. If not given, ``defaultVariables`` will be used
   - parameter variableDict: optional dictionary that maps a name to a constant. Note that this will be ignored if
   ``variables`` is also given.
   - parameter unaryFunctions: optional mapping of names to 1-ary functions. If not given, ``defaultUnaryFunctions`` will
   be used
   - parameter variableDict: optional dictionary that maps a name to a closure that maps a double to another.
   Note that this will be ignored if ``unaryFunctions`` is also given.
   - parameter binaryFunctions: optional mapping of names to 2-ary functions. If not given, ``defaultBinaryFunctions``
   will be used
   - parameter binaryFunctionDict: optional dictionary that maps a name to a closure that maps two doubles into one.
   Note that this will be ignored if ``binaryFunctions`` is also given.
   - parameter enableImpliedMultiplication: if true treat expressions like `2π` as valid and same as `2 * π`
   */
  public init(variables: VariableMap? = nil,
              variableDict: VariableDict? = nil,
              unaryFunctions: UnaryFunctionMap? = nil,
              unaryFunctionDict: UnaryFunctionDict? = nil,
              binaryFunctions: BinaryFunctionMap? = nil,
              binaryFunctionDict: BinaryFunctionDict? = nil,
              enableImpliedMultiplication: Bool = false
  ) {
    precondition(!enableImpliedMultiplication, "enableImpliedMultiplication unsupported due to errors")
    self.customVariableDict = variableDict
    self.customUnaryFunctionDict = unaryFunctionDict
    self.customBinaryFunctionDict = binaryFunctionDict

    self.variables = variables ?? variableDict?.producer ?? Self.defaultVariables.producer
    self.unaryFunctions = unaryFunctions ?? unaryFunctionDict?.producer ?? Self.defaultUnaryFunctions.producer
    self.binaryFunctions = binaryFunctions ?? binaryFunctionDict?.producer ?? Self.defaultBinaryFunctions.producer
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }

  @available(*, deprecated, message: "Use init with variables and binaryFunction parameters.")
  public init(symbols: SymbolMap?,
              unaryFunctions: UnaryFunctionMap? = nil,
              binaryFunctions: BinaryFunctionMap? = nil,
              enableImpliedMultiplication: Bool = false) {
    self.variables = symbols ?? Self.defaultVariables.producer
    self.unaryFunctions = unaryFunctions ?? Self.defaultUnaryFunctions.producer
    self.binaryFunctions = binaryFunctions ?? Self.defaultBinaryFunctions.producer
    self.enableImpliedMultiplication = enableImpliedMultiplication
    self.customVariableDict = nil
    self.customUnaryFunctionDict = nil
    self.customBinaryFunctionDict = nil
  }

  @available(*, deprecated, message: "Use init with variables and binaryFunction parameters.")
  public init(symbols: SymbolMap?,
              functions: UnaryFunctionMap? = nil,
              enableImpliedMultiplication: Bool = false) {
    self.variables = symbols ?? Self.defaultVariables.producer
    self.unaryFunctions = functions ?? Self.defaultUnaryFunctions.producer
    self.binaryFunctions = Self.defaultBinaryFunctions.producer
    self.enableImpliedMultiplication = enableImpliedMultiplication
    self.customVariableDict = nil
    self.customUnaryFunctionDict = nil
    self.customBinaryFunctionDict = nil
  }

  // MARK: -

  /**
   Parse an expression into a token that can be evaluated at a later time.

   - parameter text: the expression to parse
   - returns: optional Evaluator to use to obtain results from the parsed expression. This is nil if
   the given expression is not valid.
   */
  public func parse(_ text: String) -> Evaluator? {
    guard let token = try? expression.parse(text) else { return nil }
    return Evaluator(token: token, usingImpliedMultiplication: enableImpliedMultiplication)
  }

  /**
   Parse an expression into a token that can be evaluated at a later time. Returns a `Result` enum with two cases:

   - `.success` -- holds an ``Evaluator`` instance for evaluations of the parsed expression
   - `.failure` -- holds a ``MathParserError`` instance that describes the parse failure

   - parameter text: the expression to parse
   - returns: `Result` enum
   */
  public func parseResult(_ text: String) -> Result<Evaluator, MathParserError> {
    do {
      let token = try expression.parse(text)
      return .success(Evaluator(token: token, usingImpliedMultiplication: enableImpliedMultiplication))
    } catch {
      return .failure(MathParserError(description: "\(error)"))
    }
  }

  // MARK: - implementation details

  /// When true, two parsed operands in a row implies multiplication
  private let enableImpliedMultiplication: Bool

  /// Type of the parser that returns a Token
  private typealias TokenParser = Parser<Substring, Token>
  private typealias Ary2Parser = Parser<Substring, (Token, Token)>
  private typealias TokenReducer = (Token, Token) -> Token

  /// Parser for start of identifier (constant, variable, function). All must start with a letter.
  private let identifierStart = Parse(input: Substring.self) { Prefix(1) { $0.isLetter } }

  /// Parser for remaining parts of identifier (constant, variable, function)
  private let identifierRemaining = Parse(input: Substring.self) {
    Prefix { $0.isNumber || $0.isLetter || $0 == Character("_") }
  }
  /// Parser for a numeric constant
  private let constant: some TokenParser = Parse { Double.parser().map { Token.constant(value: $0) } }

  /// Parser for addition / subtraction operator.
  private let additionOrSubtractionOperator: some Parser<Substring, TokenReducer> = Parse {
    ignoreSpaces
    OneOf {
      "+".map { { Token.reducer(lhs: $0, rhs: $1, op: (+), name: "+") } }
      "-".map { { Token.reducer(lhs: $0, rhs: $1, op: (-), name: "-") } }
    }
  }

  /// Parser for multiplication / division operator. Also recognizes × for multiplication and ÷ for division.
  private let multiplicationOrDivisionOperator: some Parser<Substring, TokenReducer> = Parse {
    ignoreSpaces
    OneOf {
      "*".map { { Token.reducer(lhs: $0, rhs: $1, op: (*), name: "*") } }
      "×".map { { Token.reducer(lhs: $0, rhs: $1, op: (*), name: "*") } }
      "/".map { { Token.reducer(lhs: $0, rhs: $1, op: (/), name: "/") } }
      "÷".map { { Token.reducer(lhs: $0, rhs: $1, op: (/), name: "/") } }
    }
  }

  /// Parser for exponentiation (power) operator
  private let exponentiationOperator: some Parser<Substring, TokenReducer> = Parse {
    ignoreSpaces
    "^".map { { Token.reducer(lhs: $0, rhs: $1, op: (pow), name: "^") } }
  }

  /// Parser for identifier such as a function name or a symbol.
  private lazy var identifier = Parse(input: Substring.self) {
    identifierStart
    identifierRemaining
  }.map { $0.0 + $0.1 }

  /// Parser for valid addition / subtraction operations. This is the starting point of precedence-involved parsing.
  /// Use type erasure due to circular references to this parser in others that follow.
  private lazy var additionAndSubtraction: some TokenParser = InfixOperation(
    associativity: .left,
    operator: additionOrSubtractionOperator,
    higher: multiplicationAndDivision
  ).eraseToAnyParser()

  /// Parser for multiplication / division operations. Higher precedence than + and -.
  private lazy var multiplicationAndDivision: some TokenParser = InfixOperation(
    associativity: .left,
    operator: multiplicationOrDivisionOperator,
    higher: exponentiation
  )

  /// Parser for exponentiation operation. Higher precedence than * and /.
  private lazy var exponentiation: some TokenParser = InfixOperation(
    associativity: .right,
    operator: exponentiationOperator,
    higher: operand
  )

  private lazy var symbolOrVariable: some TokenParser = Parse {
    identifier
  }.map { (name: Substring) -> Token in

    // If the symbol is defined, use its value.
    if let value = self.variables(String(name)) {
      return .constant(value: value)
    }

    // If implied-multiplication is allowed, look for symbols next to other symbols. This is risky if one symbol name
    // is a substring of another symbol name -- say `e` and a variable called `value` which will be taken as `value * e`
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

  /// Parser for expression term. Starts at the lowest precedence operation.
  private lazy var term: some TokenParser = Lazy {
    self.additionAndSubtraction
    ignoreSpaces
  }

  /// Parser for expression in parentheses.
  private lazy var parenthetical: some TokenParser = Lazy {
    "("
    self.term
    ")"
  }

  /// Parser for a single argument function call (eg `sin`).
  private lazy var unaryCall: some TokenParser = Parse {
    self.identifier
    "("
    self.term
    ")"
  }.map { (identifier: Substring, arg: Token) -> Token in
    let name = String(identifier)
    guard let resolved = self.unaryFunctions(name) else {
      return .unaryCall(op: nil, name: name, arg: arg)
    }
    if case .constant(let value) = arg {
      return .constant(value: resolved(value))
    } else {
      return .unaryCall(op: resolved, name: name, arg: arg)
    }
  }

  /// Parser for a two-argument function call (eg `atan2`).
  private lazy var binaryCall: some TokenParser = Parse {
    self.identifier
    "("
    self.term
    ","
    self.term
    ")"
  }.map { (identifier: Substring, arg1: Token, arg2: Token) -> Token in
    let name = String(identifier)
    guard let resolved = self.binaryFunctions(name) else {
      return .binaryCall(op: nil, name: name, arg1: arg1, arg2: arg2)
    }
    if case let .constant(value1) = arg1,
       case let .constant(value2) = arg2 {
      return .constant(value: resolved(value1, value2))
    } else {
      return .binaryCall(op: resolved, name: name, arg1: arg1, arg2: arg2)
    }
  }

  /// Parser for negation
  private lazy var nonNegatedOperand: some TokenParser = Parse {
    ignoreSpaces
    OneOf {
      binaryCall
      unaryCall
      parenthetical
      symbolOrVariable
      constant
    }
  }

  /// Parser for negation
  private lazy var negatedOperand: some Parser<Substring, Token> = Parse {
    ignoreSpaces
    "-"
    nonNegatedOperand
  }.map { Token.reducer(lhs: .constant(value: -1.0), rhs: $0, op: (*), name: "*") }


  /// Parser for an operand of an expression. Note that order is important: a function call is made up of an identifier
  /// followed by a parenthetical expression, so it must be before ``parenthetical`` and ``symbolOrVariable``.
  private lazy var operand: some TokenParser = Parse {
    OneOf {
      negatedOperand
      nonNegatedOperand
    }
  }

  /// Parser for a math expression. Checks that there is nothing remaining to be parsed.
  private lazy var expression: some TokenParser = Parse {
    self.term
    End()
  }
}

/// Common expression for ignoring spaces in other parsers
private let ignoreSpaces = Skip { Optionally { Prefix<Substring> { $0.isWhitespace } } }
