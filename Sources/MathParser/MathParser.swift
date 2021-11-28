import Parsing
import XCTest
import Foundation

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#endif

private enum Associativity {
  case left
  case right
}

/**
 Parser for infix operators. Takes a parser for operators to recognize and a parser for values to use with the
 operator which could include operations that are of higher precedence than those parsed by the first parser.

 NOTE: this parser will succeed if it can parse at least one operand value. This can be problematic if you want to
 have an `orElse` case for a failed binary expression.

 Based on InfixOperator found in the Arithmetic perf test of https://github.com/pointfreeco/swift-parsing
 */
private struct InfixOperator<Operator, Operand>: Parser
where Operator: Parser, Operand: Parser,
      Operator.Input == Operand.Input,
      Operator.Output == (Operand.Output, Operand.Output) -> Operand.Output
{
  @usableFromInline
  let parser: (inout Operand.Input) -> Operand.Output?

  /**
   Construct new parser

   - parameter operator: the parser that recognizes valid operators at a certain precedence level
   - parameter associativity: the associativity for these operators
   - parameter operand: the parser for values to provide to the operator that may include operations at a higher
   precedence level
   */
  @inlinable
  public init(operator: Operator, associativity: Associativity, higher operand: Operand) {
    switch associativity {
    case .left: self.parser = { Self.leftAssociative(input: &$0, operand: operand, operator: `operator`) }
    case .right: self.parser = { Self.rightAssociative(input: &$0, operand: operand, operator: `operator`) }
    }
  }

  /**
   Implementation of Parser method. Looks for "operand operator operand" sequences, but also succeeds on just a
   sole initial "operand" parse for the left-hand or right-hand side of the expression (depending on the associativity
   value given in the constructor).

   - parameter input: the input stream to parse
   - returns: the next output value found in the stream, or nil if no match
   */
  @inlinable
  public func parse(_ input: inout Operand.Input) -> Operand.Output? {
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

  @usableFromInline
  static func rightAssociative(input: inout Operand.Input, operand: Operand, operator: Operator) -> Operand.Output? {
    var lhs: [(Operand.Output, Operator.Output)] = []
    while let rhs = operand.parse(&input) {
      guard let operation = `operator`.parse(&input)
      else {
        return lhs.reversed().reduce(rhs) { rhs, pair in
          let (lhs, operation) = pair
          return operation(lhs, rhs)
        }
      }
      lhs.append((rhs, operation))
    }
    return nil
  }
}

/**
 General-purpose parser for simple math expressions made up of the common operations as well as single argument
 functions like `sqrt` and `sin` and named variables / symbols. For instance, the expression `4 * sin(t * pi)` is
 legal and references the `sin` function, the `pi` constant, and an unknown variable `t`. Parsing a legal expression
 results in a `MathParser.Evaluator` that can be used to obtain actual results from the expression, such as when the
 value for `t` is known.
 */
public class MathParser {

  /// Mapping of symbol names to an optional Double.
  public typealias SymbolMap = (String) -> Double?
  /// Mapping of names to an optional transform function
  public typealias FunctionMap = (String) -> ((Double) -> Double)?

  /**
   Enumeration of the various components identified in a parse of an expression. If an expression can be fully evaluated
   (eg `1 + 2`) then it will result in a `.constant` token with the final value. Otherwise, calling `eval` with
   additional will return a value, though it may be NaN if there were any unresolved symbols or functions.
   */
  public enum Token {
    case constant(Double)
    case variable(String)
    indirect case function(String, Token)
    indirect case parenthetical(Token)
    indirect case mathOp(Token, Token, (Double, Double) -> Double)

    /**
     Evaluate the token to obtain a Double value.

     - parameter variables: optional mapping to use to resolve symbols
     - parameter functions: optional mapping to use to resolve functions
     - returns: result of evaluation. May be NaN if unresolved symbol or function still exists
     */
    public func eval(_ variables: @escaping SymbolMap, _ functions: @escaping FunctionMap) -> Double {
      let resolve: (Token) -> Double = { $0.eval(variables, functions) }
      switch self {
      case .constant(let value):           return value
      case .variable(let name):            return variables(name) ?? .nan
      case .function(let name, let arg):   return functions(name)?(resolve(arg)) ?? .nan
      case .parenthetical(let token):      return resolve(token)
      case .mathOp(let lhs, let rhs, let op): return op(resolve(lhs), resolve(rhs))
      }
    }
  }

  /// Default symbols to use for parsing.
  public static let defaultSymbols: [String: Double] = ["pi": .pi, "π": .pi, "e": Darwin.M_E]

  /// Default functions to use for parsing.
  public static let defaultFunctions: [String: (Double) -> Double] = [
    "sin": sin, "cos": cos, "tan": tan,
    "log10": log10, "ln": log, "loge": log, "log2": log2, "exp": exp,
    "ceil": ceil, "floor": floor, "round": round,
    "sqrt": sqrt
  ]

  private static func join(lhs: Token, rhs: Token, op: @escaping (Double, Double) -> Double) -> Token {
    if case let .constant(lhs) = lhs, case let .constant(rhs) = rhs {
      return .constant(op(lhs, rhs))
    }
    return .mathOp(lhs, rhs, op)
  }

  private typealias TokenParser = AnyParser<Substring.UTF8View, Token>

  /// Symbol mapping to use during parsing and perhaps evaluation
  public let symbols: SymbolMap

  /// Function mapping to use during parsing and perhaps evaluation
  public let functions: FunctionMap

  /// Parser for start of identifier
  private let firstLetter = Skip(Whitespace()).pullback(\.utf8).take(Prefix(1) { $0.isLetter })

  /// Parser for remaining parts of identifier
  private let remaining = Prefix { $0.isNumber || $0.isLetter }

  /// Parser for a numeric constant
  private let constant: TokenParser = Skip(Whitespace())
    .take(Double.parser().map { Token.constant($0) })
    .eraseToAnyParser()

  /// Parser for identifier
  private lazy var identifier = firstLetter.take(remaining).map { ($0.0 + $0.1) }

  /// Parser for addition / subtraction operations. This is the starting point of precedence-involved parsing.
  private lazy var additionAndSubtraction: TokenParser = InfixOperator(
    operator: Skip(Whitespace())
      .take(OneOfMany(
        "+".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (+)) } },
        "-".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (-)) } }
      )),
    associativity: .left,
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
        Skip(Whitespace())
          .take("*".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (*)) } }).eraseToAnyParser(),
        Skip(Whitespace())
          .take("/".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (/)) } }).eraseToAnyParser(),
        " ".utf8.map({ { Self.join(lhs: $0, rhs: $1, op: (*)) } }).eraseToAnyParser()
      )
    )
    : Conditional.second(
      Skip(Whitespace())
        .take(OneOfMany(
          "*".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (*)) } },
          "/".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (/)) } }
        ))
    ),
    associativity: .left,
    higher: exponent
  ).eraseToAnyParser()

  /// Parser for exponentiation operation. Higher precedence than * /
  private lazy var exponent: TokenParser = InfixOperator(
    operator: Skip(Whitespace())
      .take("^".utf8.map { { Self.join(lhs: $0, rhs: $1, op: (pow)) } }),
    associativity: .left,
    higher: operand
  ).eraseToAnyParser()

  /// Parser for a symbol. If symbol exists during parse, parser returns `.constant`. Otherwise, parser returns
  /// `.symbol` for later evaluation when the symbol is known.
  private lazy var symbolOrVariable: TokenParser = identifier
    .utf8
    .map { name in
      let name = String(name)
      if let value = self.symbols(name) {
        return .constant(value)
      }
      return .variable(name)
    }
    .eraseToAnyParser()

  /// Parser for expression in parentheses
  private lazy var parenthetical: TokenParser = Skip(Whitespace())
    .take("(".utf8)
    .take(Lazy { self.additionAndSubtraction })
    .skip(Whitespace())
    .take(")".utf8)
    .map { $0.1 }
    .eraseToAnyParser()

  /// Parser for a single argument function call (eg `sin`). If it function is known and argument is `.constant`, the
  /// function will be called and the parser returns `.constant` with the value. Otherwise, parser returns `.function`
  /// for later evaluation when the function and/or argument is known.
  private lazy var function: TokenParser = identifier
    .utf8
    .take(parenthetical)
    .map { tuple in
      let name = String(tuple.0)
      guard let function = self.functions(name) else { return .function(name, tuple.1) }
      switch tuple.1 {
      case .constant(let value): return .constant(function(value))
      default: return .function(name, tuple.1)
      }
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
   */
  public init(symbols: SymbolMap? = nil, functions: FunctionMap? = nil, enableImpliedMultiplication: Bool = false) {
    self.symbols = symbols ?? { Self.defaultSymbols[$0] }
    self.functions = functions ?? { Self.defaultFunctions[$0] }
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }

  /**
   Evaluator of parsed tokens.
   */
  public struct Evaluator {
    private let token: Token
    private let symbols: SymbolMap
    private let functions: FunctionMap

    /**
     Construct new evaluator.

     - parameter token: the token to evaluate
     - parameter symbols: the mapping of names to constants to use during evaluation
     - parameter functions: the mapping of names to functions to use during evaluation
     */
    public init(token: Token, symbols: @escaping SymbolMap, functions: @escaping FunctionMap) {
      self.token = token
      self.symbols = symbols
      self.functions = functions
    }

    /**
     Evaluate the token to obtain a value. By default will use symbol map and function map given to `init`.

     - parameter symbols: optional mapping of names to constants to use during evaluation
     - parameter functions: optional mapping of names to functions to use during evaluation
     */
    public func eval(symbols: SymbolMap? = nil, functions: FunctionMap? = nil) -> Double {
      token.eval(symbols ?? self.symbols, functions ?? self.functions)
    }

    /**
     Convenience method to evaluate an expression with one unknown symbol.

     - parameter name: the name of a symbol to resolve
     - parameter value: the value to use for the symbol
     */
    public func eval(_ name: String, value: Double) -> Double {
      token.eval({$0 == name ? value : symbols(name)}, functions)
    }
  }

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
