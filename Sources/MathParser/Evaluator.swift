// Copyright © 2021 Brad Howes. All rights reserved.

/**
 Evaluator of parsed tokens.
 */
public struct Evaluator {
  @usableFromInline
  let token: Token
  @usableFromInline
  let enableImpliedMultiplication: Bool
  /**
   Construct new evaluator. This is constructed and returned by `MathParser.parse`.

   - parameter token: the token to evaluate
   - parameter enableImpliedMultiplication: if true then try to decompose symbols into pairs that are multiplied together
   */
  init(token: Token, enableImpliedMultiplication: Bool = false) {
    self.token = token
    self.enableImpliedMultiplication = enableImpliedMultiplication
  }

  /// Resolve a parsed expression to a value. If the expression has unresolved symbols this will return NaN.
  public var value: Double { return self.eval() }

  /**
   Evaluate the token to obtain a value. By default will use symbol map and function map given to `init`.

   - parameter symbols: optional mapping of names to constants to use during evaluation
   - parameter unaryFunctions: optional mapping of names to 1 parameter functions to use during evaluation
   - parameter binaryFunctions: optional mapping of names to 2 parameter functions to use during evaluation
   */
  @inlinable
  public func eval(symbols: MathParser.SymbolMap? = nil,
                   unaryFunctions: MathParser.UnaryFunctionMap? = nil,
                   binaryFunctions: MathParser.BinaryFunctionMap? = nil) -> Double {
    token.eval(symbols: symbols ?? { _ in nil },
               unaryFunctions: unaryFunctions ?? { _ in nil },
               binaryFunctions: binaryFunctions ?? { _ in nil },
               enableImpliedMultiplication: enableImpliedMultiplication)
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   - parameter name: the name of a symbol to resolve
   - parameter value: the value to use for the symbol
   */
  @inlinable
  public func eval(_ name: String, value: Double) -> Double {
    token.eval(symbols: {$0 == name ? value : nil},
               unaryFunctions: { _ in nil },
               binaryFunctions: { _ in nil },
               enableImpliedMultiplication: enableImpliedMultiplication)}
}
