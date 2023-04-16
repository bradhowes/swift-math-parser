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
  static func reducer(lhs: Token, rhs: Token, operation: @escaping (Double, Double) -> Double) -> Token {
    if case let .constant(lhs) = lhs, case let .constant(rhs) = rhs {
      return .constant(operation(lhs, rhs))
    }
    return .mathOp(lhs, rhs, operation)
  }

  @usableFromInline
  var noBinaryFuncs: MathParser.BinaryFunctionMap { { _ in nil } }

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
    eval(variables, functions, noBinaryFuncs, enableImpliedMultiplication)
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
        if let token = Token.attemptToSplitForMultiplication(name: name.prefix(name.count), symbols: variables) {
          return token.eval(variables, unaryFunctions, binaryFunctions, enableImpliedMultiplication)
        }
      }
      return variables(name) ?? .nan
    case .function1(let name, let arg): return unaryFunctions(name)?(
      arg.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication)) ?? .nan
    case .function2(let name, let arg1, let arg2):
      return binaryFunctions(name)?(
      arg1.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication),
      arg2.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication)) ?? .nan
    case .mathOp(let lhs, let rhs, let operation): return operation(
      lhs.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication),
      rhs.eval(variables, unaryFunctions, binaryFunctions,enableImpliedMultiplication))
    }
  }

  /**
   Attempt to split a symbol into multiplication of two or more items. This is used when `enableImpliedMultiplication`
   is `true`. It takes a simple approach of looking for known symbols at the start and end of a symbol name. When a
   match is found, it constructs a multiplication of two new symbols, one of which is converted into a constant.

   This routine is used both during the initial parse of the function definition *and* during the evaluation of the
   function if there are unknown symbols in need of resolution.

   - parameter name: the name to split
   - parameter symbols: the symbol map to use to locate a known symbol name
   - returns: optional Token that describes one or more multiplications that came from the given name
   */
  @usableFromInline
  static func attemptToSplitForMultiplication(name: Substring, symbols: MathParser.SymbolMap) -> Token? {
    for count in 1..<name.count {
      let lhsName = name.dropLast(count)
      let rhsName = name.suffix(count)
      if let value = symbols(String(lhsName)) {
        let lhs: Token = .constant(value)
        let rhs = attemptToSplitForMultiplication(name: rhsName, symbols: symbols) ?? .variable(String(rhsName))
        return Token.reducer(lhs: lhs, rhs: rhs, operation: (*))
      }
      else if let value = symbols(String(rhsName)) {
        let lhs = attemptToSplitForMultiplication(name: lhsName, symbols: symbols) ?? .variable(String(lhsName))
        let rhs: Token = .constant(value)
        return Token.reducer(lhs: lhs, rhs: rhs, operation: (*))
      }
    }
    return nil
  }
}
