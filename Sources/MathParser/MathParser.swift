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
  /// Return value for the ``MathParser/parseResult(_:)`` method.
  public typealias Result = Swift.Result<Evaluator, MathParserError>
  /**
   Default symbols to use for parsing.

   - `pi` -- the transcendental number that is the ratio of a circle's circumference to it's diameter
   - `π` -- same as above but as a Unicode symbol
   - `e` -- the transcendental number that is the base of natural logarithms
   */
  public static let defaultVariables: [String: Double] = ["pi": .pi, "π": .pi, "e": .e]

  /**
   Default 1-argument functions to use for parsing and evaluation.

   - `sin` -- trigonometric function of an angle Θ in radians that represents the the ratio of the length of the side
   of a right triangle that is opposite to angle Θ and to the length of the hypotenuse.
   - `asin` -- calculates the arc sine of the value such that asin(sin(X)) == X for X in [-1, 1]
   - `cos` -- trigonometric function of an angle Θ in radians that represents the the ratio of the length of the side
   of a right triangle that is adjacent to angle Θ and to the length of the hypotenuse.
   - `acos` -- calculates the arc cosine of the value such that acos(cos(X)) == X for X in [-1, 1]
   - `tan` -- trigonometric function that is the ratio of the opposite and adjacent sides of the triangle.
   - `atan` -- calculates the arc tangent of the value such that atan(tan(x)) == X
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
   - `abs` -- always return a positive value
   - `sgn` -- return -1 if the given value is negative and 1 if it is positive. If zero, return 0.
   */
  public static let defaultUnaryFunctions: UnaryFunctionDict = [
    "sin": sin, "asin": asin, "cos": cos, "acos": acos, "tan": tan, "atan": atan,
    "sinh": sinh, "asinh": asinh, "cosh": cosh, "acosh": acosh, "tanh": tanh, "atanh": atanh,
    "log": log10, "log10": log10, "ln": log, "loge": log, "log2": log2, "exp": exp, 
    "ceil": ceil, "floor": floor, "round": round,
    "sqrt": sqrt, "√": sqrt,
    "cbrt": cbrt, // cube root,
    "abs": abs,
    "sgn": { $0 < 0 ? -1 : $0 > 0 ? 1 : 0 },
    "!": { factorial($0) },
    "sec": { 1 / cos($0) },
    "csc": { 1 / sin($0) },
    "cot": { 1 / tan($0) }
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
    "pow": pow, // Redundant since we support x^b expressions
   "mod": { $0.truncatingRemainder(dividingBy: $1) }
  ]

  /// Symbol/variable mapping to use during parsing and perhaps evaluation
  public let variables: VariableMap
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
    self.customVariableDict = variableDict
    self.customUnaryFunctionDict = unaryFunctionDict
    self.customBinaryFunctionDict = binaryFunctionDict

    self.variables = variables ?? variableDict?.producer ?? Self.defaultVariables.producer
    self.unaryFunctions = unaryFunctions ?? unaryFunctionDict?.producer ?? Self.defaultUnaryFunctions.producer
    self.binaryFunctions = binaryFunctions ?? binaryFunctionDict?.producer ?? Self.defaultBinaryFunctions.producer
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }

  // MARK: -

  /**
   Parse an expression into a token that can be evaluated at a later time.

   - parameter text: the expression to parse
   - returns: optional ``Evaluator`` to use to obtain results from the parsed expression. This is nil if
   the given expression to parse is not valid.
   */
  public func parse(_ text: String) -> Evaluator? {
    guard let token = try? expression.parse(text) else { return nil }
    return Evaluator(token: token, usingImpliedMultiplication: enableImpliedMultiplication)
  }

  /**
   Parse an expression into a token that can be evaluated at a later time, and returns a `Result` value that conveys
   information about the parsing result.

   The `Result` enum has two cases:

   - `.success` -- holds an ``Evaluator`` instance for evaluations of the parsed expression
   - `.failure` -- holds a ``MathParserError`` instance that describes the parse failure

   - parameter text: the expression to parse
   - returns: `Result` enum
   */
  public func parseResult(_ text: String) -> Result {
    do {
      let token = try expression.parse(text)
      return .success(Evaluator(token: token, usingImpliedMultiplication: enableImpliedMultiplication))
    } catch {
      return .failure(.parseFailure(context: "\(error)"))
    }
  }

  // MARK: - implementation details

  // When true, two parsed operands in a row implies multiplication
  private let enableImpliedMultiplication: Bool

  // Any of these will terminate an identifier (as well as whitespace). NOTE: this must be kept up-to-date with any
  // changes to the symbols being recognized by the parser.
  private let identifierTerminalSymbols: Set<Character> = [
    "+",
    "-",
    "*",
    "×",
    "/",
    "÷",
    "^",
    "(",
    ")",
    ","
  ]

  /*
   Parser for a numeric constant. NOTE: we disallow signed numbers here due to ambiguities that are introduced if
   implied multiplication mode is enabled. We allow for negative values through the negation operation which demands
   that the "-" appear just before the number without any spaces between them.
   */
  private let constant: some TokenParser = Parse {
    Not {
      OneOf {
        "+"
        "-"
      }
    }
    Double.parser()
  }.map { Token.constant(value: $0) }

  private let multiplicationReducer: TokenReducer = { Token.reducer(lhs: $0, rhs: $1, op: (*), name: "*") }
  private let divisionReducer: TokenReducer = { Token.reducer(lhs: $0, rhs: $1, op: (/), name: "/") }

  // MARK: - Token Parsers

  // Entry point for math parsing
  private lazy var expression: some TokenParser = Parse {
    self.subexpression
    End()
  }

  // NOTE: the chain of expression parsers from here to exponentiation causes a loop so we need to be "lazy" here.
  private lazy var subexpression: some TokenParser = Lazy {
    self.additionAndSubtraction
  }

  private lazy var additionAndSubtraction = InfixOperation(
    name: "+|-",
    associativity: .left,
    operator: additionOrSubtractionOperator,
    operand: multiplicationAndDivision
  )

  private lazy var multiplicationAndDivision = InfixOperation(
    name: "*|/",
    associativity: .left,
    operator: multiplicationOrDivisionOperator,
    operand: exponentiation,
    implied: enableImpliedMultiplication ? self.multiplicationReducer : nil
  )

  private lazy var exponentiation = InfixOperation(
    name: "Pow",
    associativity: .right,
    operator: exponentiationOperator,
    operand: operand
  )

  // Semi-hacky support of a factorial operation. This works but implies that the factorial operation is at the highest
  // precedence of all other math operations (reasonable). We only operate on positive values so we don't have to handle
  // the error case if the value is negative.
  private lazy var operand: some TokenParser = Parse {
    ignoreSpaces
    OneOf {
      negatedOperand
      Parse {
        nonNegatedOperand
        Optionally {
          "!"
        }
      }.map { (operand, factorialOp) in
        guard let factorialOp = factorialOp else { return operand }
        guard case let Token.constant(value) = operand else {
          return .unaryCall(op: self.findUnary(name: "!"), name: "!", arg: operand)
        }
        return Token.constant(value: factorial(value))
      }
    }
  }

  // NOTE: there must not be any separation between the "-" and the operand.
  private lazy var negatedOperand: some TokenParser = Parse {
    "-"
    nonNegatedOperand
  }.map { multiply(lhs: .constant(value: -1.0), rhs: $0) }

  // NOTE: order is important since a function call is made up of an identifier followed by a parenthetical expression.
  private lazy var nonNegatedOperand: some TokenParser = OneOf {
    symbolOrCall
    parenthetical
    constant
  }

  // Try to parse an identifier, if possible a one or two arg function call. NOTE: for a function call the name must
  // be immediately followed by a "(".
  private lazy var symbolOrCall: some TokenParser = Parse {
    identifier
    Optionally {
      "("
      self.subexpression
      Optionally {
        ignoreSpaces
        ","
        self.subexpression
      }
      ignoreSpaces
      ")"
    }
  }.map { (identifier: Substring, call: (Token, Token?)?) -> Token in
    // Variable if no call information
    guard let call = call else {
      if let value = self.findVariable(name: identifier) {
        return .constant(value: value)
      }
      return .variable(name: identifier)
    }

    // 2-arg function call if valid second argument
    let arg1 = call.0
    if let arg2 = call.1 {
      let op = self.findBinary(name: identifier)
      if let op = op,
         case let .constant(value1) = arg1,
         case let .constant(value2) = arg2 {
        return .constant(value: op(value1, value2))
      }
      return .binaryCall(op: op, name: identifier, arg1: arg1, arg2: arg2)
    }

    // 1-arg function call
    let op = self.findUnary(name: identifier)
    if let op = op,
       case let .constant(value1) = arg1 {
      return .constant(value: op(value1))
    }

    return .unaryCall(op: op, name: identifier, arg: arg1)
  }

  // For our purposes, an identifier for a variable or function is anything that does not:
  //   - contain whitespace
  //   - start with a number
  //   - contain a math operator, parentheses or a comma
  //
  // This means that they can include anything else that is representable in UTF-8, including
  // emoji and other characters and symbols, including non-Latin languages.
  private lazy var identifier = Parse(input: Substring.self) {
    Prefix(1) { !(self.identifierTerminalSymbols.contains($0) || $0.isNumber || $0.isWhitespace) }
    Prefix { !(self.identifierTerminalSymbols.contains($0) || $0.isWhitespace) }
  }.map { $0 + $1 }

  private lazy var parenthetical: some TokenParser = Lazy {
    "("
    self.subexpression
    ")"
  }

  // MARK: - Operator Parsers

  private let additionOrSubtractionOperator: some TokenReducerParser = Parse {
    ignoreSpaces
    OneOf {
      "+".map { { Token.reducer(lhs: $0, rhs: $1, op: (+), name: "+") } }
      "-".map { { Token.reducer(lhs: $0, rhs: $1, op: (-), name: "-") } }
    }
  }

  private lazy var multiplicationOrDivisionOperator: some TokenReducerParser = Parse {
    ignoreSpaces
    OneOf {
      "*".map { self.multiplicationReducer }
      "×".map { self.multiplicationReducer }
      "/".map { self.divisionReducer }
      "÷".map { self.divisionReducer }
    }
  }

  private let exponentiationOperator: some TokenReducerParser = Parse {
    ignoreSpaces
    "^".map { { Token.reducer(lhs: $0, rhs: $1, op: (pow), name: "^") } }
  }

  private func findVariable(name: Substring) -> Double? { self.variables(String(name)) }
  private func findBinary(name: Substring) -> BinaryFunction? { self.binaryFunctions(String(name)) }
  private func findUnary(name: Substring) -> UnaryFunction? { self.unaryFunctions(String(name)) }
}

/// Common expression for ignoring spaces in other parsers
private let ignoreSpaces = Skip { Optionally { Prefix<Substring> { $0.isWhitespace } } }

typealias TokenParser = Parser<Substring, Token>
typealias TokenReducer = (Token, Token) -> Token
typealias TokenReducerParser = Parser<Substring, TokenReducer>
