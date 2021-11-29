// Copyright © 2021 Brad Howes. All rights reserved.

import Foundation

/**
 Evaluator of parsed tokens.
 */
public struct Evaluator {
  @usableFromInline
  internal let token: Token
  @usableFromInline
  internal let symbols: MathParser.SymbolMap
  @usableFromInline
  internal let functions: MathParser.FunctionMap

  /**
   Construct new evaluator.

   - parameter token: the token to evaluate
   - parameter symbols: the mapping of names to constants to use during evaluation
   - parameter functions: the mapping of names to functions to use during evaluation
   */
  internal init(token: Token, symbols: @escaping MathParser.SymbolMap, functions: @escaping MathParser.FunctionMap) {
    self.token = token
    self.symbols = symbols
    self.functions = functions
  }

  /**
   Evaluate the token to obtain a value. By default will use symbol map and function map given to `init`.

   - parameter symbols: optional mapping of names to constants to use during evaluation
   - parameter functions: optional mapping of names to functions to use during evaluation
   */
  @inlinable
  public func eval(symbols: MathParser.SymbolMap? = nil, functions: MathParser.FunctionMap? = nil) -> Double {
    token.eval(symbols ?? self.symbols, functions ?? self.functions)
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   - parameter name: the name of a symbol to resolve
   - parameter value: the value to use for the symbol
   */
  @inlinable
  public func eval(_ name: String, value: Double) -> Double {
    token.eval({$0 == name ? value : symbols(name)}, functions)
  }
}
