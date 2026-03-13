// Copyright © 2026 Brad Howes. All rights reserved.

/**
 Collection of symbol maps to use for evaluating a Token.
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
  func findVariable(name: Substring) -> Double? {
    self.variables?(String(name)) ?? MathParser.defaultVariables[String(name)]
  }

  @inlinable
  func findUnary(name: Substring) -> MathParser.UnaryFunction? {
    self.unaryFunctions?(String(name)) ?? MathParser.defaultUnaryFunctions[String(name)]
  }

  @inlinable
  func findBinary(name: Substring) -> MathParser.BinaryFunction? {
    self.binaryFunctions?(String(name)) ?? MathParser.defaultBinaryFunctions[String(name)]
  }

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
}
