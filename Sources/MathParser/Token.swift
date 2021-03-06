// Copyright © 2021 Brad Howes. All rights reserved.

import Foundation

/**
 Enumeration of the various components identified in a parse of an expression. If an expression can be fully evaluated
 (eg `1 + 2`) then it will result in a `.constant` token with the final value. Otherwise, calling `eval` with
 additional symbols/functions will return a value, though it may be NaN if there were still unresolved symbols or
 functions in the token(s).
 */
public enum Token {

  /// Numerical value from parse
  case constant(Double)

  /// Unresolved variable/symbol during parse
  case variable(String)

  /// Unresolved function and/or unresolved argument during parse
  indirect case function(String, Token)

  /// Unresolved math operation due to one or both operands being unresolved during parse
  indirect case mathOp(Token, Token, (Double, Double) -> Double)

  /**
   Evaluate the token to obtain a Double value. Resolves variables and functions using the given mappings. If there
   remain unresolved tokens, the result will be a NaN.

   - parameter variables: optional mapping to use to resolve symbols
   - parameter functions: optional mapping to use to resolve functions
   - returns: result of evaluation. May be NaN if unresolved symbol or function still exists
   */
  @inlinable
  public func eval(_ variables: @escaping MathParser.SymbolMap, _ functions: @escaping MathParser.FunctionMap) -> Double {
    let resolve: (Token) -> Double = { $0.eval(variables, functions) }
    switch self {
    case .constant(let value):              return value
    case .variable(let name):               return variables(name) ?? .nan
    case .function(let name, let arg):      return functions(name)?(resolve(arg)) ?? .nan
    case .mathOp(let lhs, let rhs, let op): return op(resolve(lhs), resolve(rhs))
    }
  }
}

