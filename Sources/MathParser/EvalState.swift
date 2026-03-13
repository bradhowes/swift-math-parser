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
  func findVariable(name: String) -> Double? {
    self.variables?(name) ?? MathParser.defaultVariables[name]
  }

  @inlinable
  func findUnary(name: String) -> MathParser.UnaryFunction? {
    self.unaryFunctions?(name) ?? MathParser.defaultUnaryFunctions[name]
  }

  @inlinable
  func findBinary(name: String) -> MathParser.BinaryFunction? {
    self.binaryFunctions?(name) ?? MathParser.defaultBinaryFunctions[name]
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
