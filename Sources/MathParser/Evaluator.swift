// Copyright © 2021 Brad Howes. All rights reserved.

/**
 Evaluator of parsed tokens.

 An evaluator attempts to resolve any remaining symbols in order to return a value from a parsed expression.
 The ``eval(variables:unaryFunctions:binaryFunctions:)`` and
 ``evalResult(_:value:)`` methods accept additional definitions for variables and functions. If all are then
 resolved, then the evaluator can return a specific value from the parsed expression.
 */
public struct Evaluator {

  public typealias Result = Swift.Result<Double, MathParserError>

  /// The parsed token chain that can be evaluated
  @usableFromInline let token: Token

  /// True if using implied multiplication to resolve symbols
  @usableFromInline let usingImpliedMultiplication: Bool

  /// Obtain unresolved names of symbols for variables and functions
  public var unresolved: Unresolved { token.unresolved }

  /**
   Construct new evaluator. This is constructed and returned by `MathParser.parse`.

   - parameter token: the token to evaluate
   - parameter usingImpliedMultiplication: if true then try to decompose symbols into pairs that are multiplied together
   */
  init(token: Token, usingImpliedMultiplication: Bool = false) {
    self.token = token
    self.usingImpliedMultiplication = usingImpliedMultiplication
  }
}

public extension Evaluator {

  /// Resolve a parsed expression to a value. If the expression has unresolved symbols this will return NaN.
  var value: Double { return self.eval(variables: nil) }

  /**
   Evaluate the token to obtain a value. By default will use symbol map and function map given to `init`.

   - parameter variables: optional mapping of names to constants to use during evaluation in addition to
   `MathParser.defaultVariables`
   - parameter unaryFunctions: optional mapping of names to 1 parameter functions to use during evaluation in addition
   to `MathParser.defaultUnaryFunctions`
   - parameter binaryFunctions: optional mapping of names to 2 parameter functions to use during evaluation in addition
   to `MathParser.defaultBinaryFunctions`
   - returns: Double value that is NaN when evaluation cannot finish due to unresolved symbol
   */
  @inlinable
  func eval(variables: MathParser.VariableMap? = nil,
            unaryFunctions: MathParser.UnaryFunctionMap? = nil,
            binaryFunctions: MathParser.BinaryFunctionMap? = nil) -> Double {
    (try? token.eval(state: .init(variables: variables ?? MathParser.defaultVariables.producer,
                                  unaryFunctions: unaryFunctions ?? MathParser.defaultUnaryFunctions.producer,
                                  binaryFunctions: binaryFunctions ?? MathParser.defaultBinaryFunctions.producer,
                                  usingImpliedMultiplication: usingImpliedMultiplication))) ?? .nan
  }

  /**
   Evaluate the token to obtain a `Result` value that indicates a success or failure. The `.success` case holds a valid
   `Double` value, while the `.failure` case holds a string describing the failure.

   - parameter variables: optional mapping of names to constants to use during evaluation in addition to
   `MathParser.defaultVariables`
   - parameter unaryFunctions: optional mapping of names to 1 parameter functions to use during evaluation in addition
   to `MathParser.defaultUnaryFunctions`
   - parameter binaryFunctions: optional mapping of names to 2 parameter functions to use during evaluation in addition
   to `MathParser.defaultBinaryFunctions`
   - returns: `Result` enum which hold value on success or error description on failure.
   */
  @inlinable
  func evalResult(variables: MathParser.VariableMap? = nil,
                  unaryFunctions: MathParser.UnaryFunctionMap? = nil,
                  binaryFunctions: MathParser.BinaryFunctionMap? = nil) -> Result {
    do {
      let result = try token.eval(
        state: .init(variables: variables ?? MathParser.defaultVariables.producer,
                     unaryFunctions: unaryFunctions ?? MathParser.defaultUnaryFunctions.producer,
                     binaryFunctions: binaryFunctions ?? MathParser.defaultBinaryFunctions.producer,
                     usingImpliedMultiplication: usingImpliedMultiplication))
      return .success(result)
    } catch {
      // swiftlint:disable force_cast
      return .failure(error as! MathParserError)
      // swiftlint:enable force_cast
    }
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   - parameter name: the name of a symbol to resolve
   - parameter value: the value to use for the symbol
   */
  @inlinable
  func eval(_ name: String, value: Double) -> Double {
    eval(variables: {$0 == name ? value : nil})
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   - parameter name: the name of a symbol to resolve
   - parameter value: the value to use for the symbol
   */
  @inlinable
  func evalResult(_ name: String, value: Double) -> Result {
    evalResult(variables: {$0 == name ? value : nil})
  }
}

/**
 Collection of symbol maps to use for evaluating a Token
 */
@usableFromInline
struct EvalState {
  /// Map to use any unresolved symbols from parse
  @usableFromInline let variables: MathParser.VariableMap?
  /// Map to use any unresolved unary functions from parse
  @usableFromInline let unaryFunctions: MathParser.UnaryFunctionMap?
  /// Map to use any unresolved binary functions from parse
  @usableFromInline let binaryFunctions: MathParser.BinaryFunctionMap?
  /// True if using implied multiplication to resolve symbols
  @usableFromInline let usingImpliedMultiplication: Bool

  @inlinable
  public func findVariable(name: Substring) -> Double? {
    self.variables?(String(name)) ?? MathParser.defaultVariables.producer(String(name))
  }

  @inlinable
  public func findUnary(name: Substring) -> MathParser.UnaryFunction? {
    self.unaryFunctions?(String(name)) ?? MathParser.defaultUnaryFunctions.producer(String(name))
  }

  @inlinable
  public func findBinary(name: Substring) -> MathParser.BinaryFunction? {
    self.binaryFunctions?(String(name)) ?? MathParser.defaultBinaryFunctions.producer(String(name))
  }

  // swiftlint:disable unneeded_synthesized_initializer
  @usableFromInline
  init(variables: MathParser.VariableMap?,
       unaryFunctions: MathParser.UnaryFunctionMap?,
       binaryFunctions: MathParser.BinaryFunctionMap?,
       usingImpliedMultiplication: Bool) {
    self.variables = variables
    self.unaryFunctions = unaryFunctions
    self.binaryFunctions = binaryFunctions
    self.usingImpliedMultiplication = usingImpliedMultiplication
  }
  // swiftlint:enable unneeded_synthesized_initializer
}
