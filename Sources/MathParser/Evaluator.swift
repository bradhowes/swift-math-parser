// Copyright © 2021 Brad Howes. All rights reserved.

/**
 Evaluator of parsed tokens.
 */
public struct Evaluator {
  @usableFromInline
  internal let token: Token
  @usableFromInline
  internal let symbols: MathParser.SymbolMap
  @usableFromInline
  internal let unaryFunctions: MathParser.UnaryFunctionMap
  @usableFromInline
  internal let binaryFunctions: MathParser.BinaryFunctionMap

  /**
   Construct new evaluator.

   - parameter token: the token to evaluate
   - parameter symbols: the mapping of names to constants to use during evaluation
   - parameter unaryFunctions: the mapping of names to functions to use during evaluation
   */
  internal init(token: Token, symbols: @escaping MathParser.SymbolMap,
                unaryFunctions: @escaping MathParser.UnaryFunctionMap,
                binaryFunctions: @escaping MathParser.BinaryFunctionMap) {
    self.token = token
    self.symbols = symbols
    self.unaryFunctions = unaryFunctions
    self.binaryFunctions = binaryFunctions
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
    token.eval(symbols ?? self.symbols, unaryFunctions ?? self.unaryFunctions, binaryFunctions ?? self.binaryFunctions)
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   - parameter name: the name of a symbol to resolve
   - parameter value: the value to use for the symbol
   */
  @inlinable
  public func eval(_ name: String, value: Double) -> Double {
    token.eval({$0 == name ? value : symbols(name)}, unaryFunctions, binaryFunctions)
  }
}
