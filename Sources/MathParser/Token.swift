// Copyright © 2021 Brad Howes. All rights reserved.

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

  /// Unresolved 1-arg function and/or unresolved argument during parse
  indirect case function1(String, Token)

  /// Unresolved 2-arg function and/or unresolved arguments during parse
  indirect case function2(String, Token, Token)

  /// Unresolved math operation due to one or both operands being unresolved during parse
  indirect case mathOp(Token, Token, (Double, Double) -> Double)

  /**
   Attempt to reduce two operand Tokens and an operator. If constants, reduce to the operator applied to the
   constants. Otherwise, return a `.mathOp` token for future evaluation.

   - parameter lhs: left-hand value
   - parameter rhs: right-hand value
   - parameter operation: two-value math operation to perform
   - returns: `.constant` token if reduction took place; otherwise `.mathOp` token
   */
  static internal func reducer(lhs: Token, rhs: Token, operation: @escaping (Double, Double) -> Double) -> Token {
    if case let .constant(lhs) = lhs, case let .constant(rhs) = rhs {
      return .constant(operation(lhs, rhs))
    }
    return .mathOp(lhs, rhs, operation)
  }

  /**
   Evaluate the token to obtain a Double value. Resolves variables and functions using the given mappings. If there
   remain unresolved tokens, the result will be a NaN.

   - parameter variables: optional mapping to use to resolve symbols
   - parameter functions: optional mapping to use to resolve functions
   - returns: result of evaluation. May be NaN if unresolved symbol or function still exists
   */
  @available(*, deprecated, message: "Migrate to the new eval() to support 2-argument function calls.")
  @inlinable
  public func eval(_ variables: MathParser.SymbolMap,
                   _ functions: MathParser.UnaryFunctionMap,
                   _ enableImpliedMultiplication: Bool = false) -> Double {
    switch self {
    case .constant(let value): return value
    case .variable(let name):
      if enableImpliedMultiplication {
        if let token = MathParser.attemptToSplitForMultiplication(name: name[...], symbols: variables) {
          return token.eval(variables, functions, enableImpliedMultiplication)
        }
      }
      return variables(name) ?? .nan
    case .function1(let name, let arg): return functions(name)?(
      arg.eval(variables, functions, enableImpliedMultiplication)) ?? .nan
    case .function2: return .nan
    case .mathOp(let lhs, let rhs, let operation): return operation(
      lhs.eval(variables, functions, enableImpliedMultiplication),
      rhs.eval(variables, functions, enableImpliedMultiplication))
    }
  }

  /**
   Evaluate the token to obtain a Double value. Resolves variables and functions using the given mappings. If there
   remain unresolved tokens, the result will be a NaN.

   - parameter variables: optional mapping to use to resolve symbols
   - parameter functions: optional mapping to use to resolve functions
   - returns: result of evaluation. May be NaN if unresolved symbol or function still exists
   */
  @inlinable
  public func eval(_ variables: MathParser.SymbolMap,
                   _ unaryFunctions: MathParser.UnaryFunctionMap,
                   _ binaryFunctions: MathParser.BinaryFunctionMap,
                   _ enableImpliedMultiplication: Bool = false) -> Double {
    switch self {
    case .constant(let value): return value
    case .variable(let name):
      if enableImpliedMultiplication {
        if let token = MathParser.attemptToSplitForMultiplication(name: name[...], symbols: variables) {
          return token.eval(variables, unaryFunctions, binaryFunctions, enableImpliedMultiplication)
        }
      }
      return variables(name) ?? .nan
    case .function1(let name, let arg): return unaryFunctions(name)?(
      arg.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication)) ?? .nan
    case .function2(let name, let arg1, let arg2): return binaryFunctions(name)?(
      arg1.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication),
      arg2.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication)) ?? .nan
    case .mathOp(let lhs, let rhs, let operation): return operation(
      lhs.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication),
      rhs.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication))
    }
  }
}
