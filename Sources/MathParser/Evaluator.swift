// Copyright © 2021 Brad Howes. All rights reserved.

/**
 Evaluator of parsed tokens.
 */
public struct Evaluator {

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

   - parameter variables: optional mapping of names to constants to use during evaluation
   - parameter unaryFunctions: optional mapping of names to 1 parameter functions to use during evaluation
   - parameter binaryFunctions: optional mapping of names to 2 parameter functions to use during evaluation
   - returns: Double value that is NaN when evaluation cannot finish due to unresolved symbol
   */
  @inlinable
  func eval(variables: MathParser.VariableMap? = nil,
            unaryFunctions: MathParser.UnaryFunctionMap? = nil,
            binaryFunctions: MathParser.BinaryFunctionMap? = nil) -> Double {
    (try? token.eval(state: .init(variables: variables,
                                  unaryFunctions: unaryFunctions,
                                  binaryFunctions: binaryFunctions,
                                  usingImpliedMultiplication: usingImpliedMultiplication))) ?? .nan
  }

  /**
   Evaluate the token to obtain a `Result` value that indicates a success or failure. The `.success` case holds a valid
   `Double` value, while the `.failure` case holds a string describing the failure.

   - parameter variables: optional mapping of names to constants to use during evaluation
   - parameter unaryFunctions: optional mapping of names to 1 parameter functions to use during evaluation
   - parameter binaryFunctions: optional mapping of names to 2 parameter functions to use during evaluation
   - returns: `Result` enum
   */
  @inlinable
  func evalResult(variables: MathParser.VariableMap? = nil,
                  unaryFunctions: MathParser.UnaryFunctionMap? = nil,
                  binaryFunctions: MathParser.BinaryFunctionMap? = nil) -> Result<Double, Error> {
    do {
      return .success(try token.eval(state: .init(variables: variables,
                                                  unaryFunctions: unaryFunctions,
                                                  binaryFunctions: binaryFunctions,
                                                  usingImpliedMultiplication: usingImpliedMultiplication)))
    } catch {
      return .failure(error)
    }
  }

  @available(*, deprecated, message: "Use init with variables parameter.")
  @inlinable
  func eval(symbols: MathParser.SymbolMap?,
            unaryFunctions: MathParser.UnaryFunctionMap? = nil,
            binaryFunctions: MathParser.BinaryFunctionMap? = nil) -> Double {
    (try? token.eval(state: .init(variables: symbols,
                                  unaryFunctions: unaryFunctions,
                                  binaryFunctions: binaryFunctions,
                                  usingImpliedMultiplication: usingImpliedMultiplication))) ?? .nan
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   - parameter name: the name of a symbol to resolve
   - parameter value: the value to use for the symbol
   */
  @inlinable
  func eval(_ name: String, value: Double) -> Double {
    (try? token.eval(state: .init(variables: {$0 == name ? value : nil},
                                  unaryFunctions: nil,
                                  binaryFunctions: nil,
                                  usingImpliedMultiplication: usingImpliedMultiplication))) ?? .nan
  }
}

/**
 Collection of symbol maps to use for evaluating a Token
 */
@usableFromInline
struct EvalState {
  /// Map to use any unresolved symbols from parse
  @usableFromInline let variables: MathParser.VariableMap
  /// Map to use any unresolved unary functions from parse
  @usableFromInline let unaryFunctions: MathParser.UnaryFunctionMap
  /// Map to use any unresolved binary functions from parse
  @usableFromInline let binaryFunctions: MathParser.BinaryFunctionMap
  /// True if using implied multiplication to resolve symbols
  @usableFromInline let usingImpliedMultiplication: Bool

  @usableFromInline
  init(variables: MathParser.VariableMap?,
       unaryFunctions: MathParser.UnaryFunctionMap?,
       binaryFunctions: MathParser.BinaryFunctionMap?,
       usingImpliedMultiplication: Bool) {
    self.variables = variables ?? { _ in nil }
    self.unaryFunctions = unaryFunctions ?? { _ in nil }
    self.binaryFunctions = binaryFunctions ?? { _ in nil }
    self.usingImpliedMultiplication = usingImpliedMultiplication
  }
}

