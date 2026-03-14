// Copyright © 2022-2026 Brad Howes. All rights reserved.

internal import Foundation

/**
 Error type that describes a failure in either text parsing or token evaluation.
 */
public enum MathParserError: Error, Equatable {
  /// Holds error description from swift-parsing library when parsing fails
  case parseFailure(context: String)
  /// Holds error when evaluation fails to find a variable
  case variableNotFound(name: String)
  /// Holds error when evaluation fails to find a unary function
  case unaryFunctionNotFound(name: String)
  /// Holds error when evaluation vails to find a binary function
  case binaryFunctionNotFound(name: String)
  /// Eval without symbol name is not supported when usingImpliedMultiplication is true
  case unsupportedEvalUnderImpliedMultiplication
}

extension MathParserError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .parseFailure(let context): return context
    case .variableNotFound(let name): return "Variable '\(name)' not found"
    case .unaryFunctionNotFound(let name): return "Function '\(name)' not found"
    case .binaryFunctionNotFound(let name): return "Function '\(name)' not found"
    case .unsupportedEvalUnderImpliedMultiplication: return "Eval without symbol name when usingImpliedMultiplication is true"
    }
  }
}
