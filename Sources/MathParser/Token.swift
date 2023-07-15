// Copyright © 2023 Brad Howes. All rights reserved.

import Foundation

/**
 Enumeration of the various components identified in a parse of an expression. If an expression can be fully evaluated
 (eg `1 + 2`) then it will result in a ``.constant`` token with the final value. Otherwise, calling ``eval`` with
 additional symbols/functions will return a value, though it may be NaN if there were still unresolved symbols or
 functions in the token(s).
 */
@usableFromInline
enum Associativity {
  case left
  case right
}

@usableFromInline
enum Token {
  /// Numerical value from parse
  case constant(value: Double)
  /// Unresolved variable symbol
  case variable(name: Substring)
  /// Unresolved 1-arg function call
  indirect case unaryCall(op: MathParser.UnaryFunction?, name: Substring, arg: Token)
  /// Unresolved 2-arg function call
  indirect case binaryCall(op: MathParser.BinaryFunction?, name: Substring, arg1: Token, arg2: Token)
}

extension Token {
  // swiftlint:disable cyclomatic_complexity

  /**
   Evaluate the token to obtain a Double value. Resolves variables and functions using the given mappings. If there
   remain unresolved tokens, the result will be a NaN.

   - parameter state: collection of values to use to resolve any remaing symbols in the token
   - returns: result of evaluation. May be NaN if unresolved symbol or function still exists
   */
  @inlinable
  func eval(state: EvalState) throws -> Double {
    switch self {

    case .constant(let value):
      return value

    case .variable(let name):
      // Resolved variable, return value
      if let value = state.findVariable(name: name) { return value }
      // Attempt to convert name into combination of multiplications
      if state.usingImpliedMultiplication,
         let result = splitIdentifier(name, state: state),
         result.remaining.isEmpty {
        return try result.token.eval(state: state)
      }
      throw MathParserError.variableNotFound(name: name)

    case let .unaryCall(op, name, arg):
      // Have function, call on evaluated argument
      if let op = op { return op(try arg.eval(state: state)) }
      // Resolved function, call on evaluated argument
      if let op = state.findUnary(name: name) { return op(try arg.eval(state: state)) }
      // Attempt to convert name into combination of multiplications and perhaps a function call.
      if state.usingImpliedMultiplication,
         let token = splitUnaryIdentifier(name, arg: arg, state: state) {
        return try token.eval(state: state)
      }
      throw MathParserError.unaryFunctionNotFound(name: name)

    case let .binaryCall(op, name, arg1, arg2):
      if let op = op { return op(try arg1.eval(state: state), try arg2.eval(state: state)) }
      if let op = state.findBinary(name: name) { return op(try arg1.eval(state: state), try arg2.eval(state: state)) }
      throw MathParserError.binaryFunctionNotFound(name: name)
    }
  }
  // swiftlint:enable cyclomatic_complexity
}

extension Token {

  /// Obtain the unresolved symbols for this token an all those that it references in graph form.
  var unresolved: Unresolved {
    var variables: Set<Substring> = .init()
    var unaryFunctions: Set<Substring> = .init()
    var binaryFunctions: Set<Substring> = .init()

    // Using a stack to remember what needs to be worked on next. We don't care about order and we are by definition
    // directed acyclic so this is sufficient (we don't need a queue)
    var pending: [Token] = .init()

    pending.append(self)
    while let token = pending.popLast() {
      switch token {
      case .constant: break
      case let .variable(name: name): variables.insert(name)
      case let .unaryCall(op, name, arg):
        pending.append(arg)
        if op == nil { unaryFunctions.insert(name) }
      case let .binaryCall(op, name, arg1, arg2):
        pending.append(arg1)
        pending.append(arg2)
        if op == nil { binaryFunctions.insert(name) }
      }
    }
    return .init(variables: variables, unaryFunctions: unaryFunctions, binaryFunctions: binaryFunctions)
  }
}

extension Token: CustomStringConvertible {

  /// Obtain the unresolved symbols for this token an all those that it references in graph form.
  @usableFromInline
  var description: String {
    switch self {
    case let .constant(value: value): return "\(value)"
    case let .variable(name: name): return String(name)
    case let .unaryCall(_, name, arg): return "\(name)(\(arg.description))"
    case let .binaryCall(_, name, arg1, arg2): return "\(name)(\(arg1.description), \(arg2.description))"
    }
  }
}

extension Token {

  /**
   Attempt to reduce two operand Tokens and an operator. If the operands are constants, reduce to the operator
   applied to the constants. Otherwise, return a ``.binaryCall`` token for future evaluation.

   - parameter lhs: left-hand value
   - parameter rhs: right-hand value
   - parameter operation: the two-value math operation to perform
   - returns: ``.constant`` token if reduction took place; otherwise ``.binaryCall`` token
   */
  @inlinable
  static func reducer(lhs: Token, rhs: Token, op: @escaping MathParser.BinaryFunction, name: Substring) -> Token {
    if case let .constant(value: lhs) = lhs,
       case let .constant(value: rhs) = rhs {
      return .constant(value: op(lhs, rhs))
    }
    return .binaryCall(op: op, name: name, arg1: lhs, arg2: rhs)
  }
}

/**
 Collection of unresolved names from parse. Attempts to evaluate a token with unresolved names will result in a
 NaN.
 */
public struct Unresolved {
  /// The unresolved variables
  public let variables: Set<Substring>
  /// The unresolved unary function names
  public let unaryFunctions: Set<Substring>
  /// The unresolved binary function names
  public let binaryFunctions: Set<Substring>
  /// True if there are no unresolved symbols
  public var isEmpty: Bool { variables.isEmpty && unaryFunctions.isEmpty && binaryFunctions.isEmpty }
  /// Obtain the number of unresolved symbols
  public var count: Int { [variables, unaryFunctions, binaryFunctions].map { $0.count }.reduce(.zero, (+)) }

  init(variables: Set<Substring>, unaryFunctions: Set<Substring>, binaryFunctions: Set<Substring>) {
    self.variables = variables
    self.unaryFunctions = unaryFunctions
    self.binaryFunctions = binaryFunctions
  }
}
