// Copyright © 2023 Brad Howes. All rights reserved.

import Foundation

/**
 Enumeration of the various components identified in a parse of an expression. If an expression can be fully evaluated
 (eg `1 + 2`) then it will result in a ``.constant`` token with the final value. Otherwise, calling ``eval`` with
 additional symbols/functions will return a value, though it may be NaN if there were still unresolved symbols or
 functions in the token(s).
 */
@usableFromInline
enum Token {
  /// Numerical value from parse
  case constant(value: Double)
  /// Unresolved variable symbol
  case variable(name: String)
  /// Unresolved 1-arg function call
  indirect case unaryCall(op: MathParser.UnaryFunction?, name: String, arg: Token)
  /// Unresolved 2-arg function call
  indirect case binaryCall(op: MathParser.BinaryFunction?, name: String, arg1: Token, arg2: Token)
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
      if let value = state.variables(name) {
        return value
      } else if state.usingImpliedMultiplication,
                let token = Token.attemptImpliedMultiplication(name: name.prefix(name.count),
                                                               variables: state.variables) {
        return try token.eval(state: state)
      } else {
        throw MathParserError(description: "Variable '\(name)' not found")
      }

    case let .unaryCall(op, name, arg):
      if let op = op { return op(try arg.eval(state: state)) }
      if let op = state.unaryFunctions(name) { return op(try arg.eval(state: state)) }
      if state.usingImpliedMultiplication,
         let token = Token.attemptImpliedMultiplication(name: name.prefix(name.count),
                                                        arg: arg,
                                                        variables: state.variables,
                                                        unaryFunctions: state.unaryFunctions) {
        return try token.eval(state: state)
      }
      throw MathParserError(description: "Function '\(name)' not found")

    case let .binaryCall(op, name, arg1, arg2):
      if let op = op { return op(try arg1.eval(state: state), try arg2.eval(state: state)) }
      guard let op = state.binaryFunctions(name) else {
        throw MathParserError(description: "Function '\(name)' not found")
      }
      return op(try arg1.eval(state: state), try arg2.eval(state: state))
    }
  }
  // swiftlint:enable cyclomatic_complexity
}

extension Token {

  /// Obtain the unresolved symbols for this token an all those that it references in graph form.
  var unresolved: Unresolved {
    var variables: Set<String> = .init()
    var unaryFunctions: Set<String> = .init()
    var binaryFunctions: Set<String> = .init()

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
    case let .variable(name: name): return name
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
  static func reducer(lhs: Token, rhs: Token, op: @escaping MathParser.BinaryFunction, name: String) -> Token {
    if case let .constant(value: lhs) = lhs,
       case let .constant(value: rhs) = rhs {
      return .constant(value: op(lhs, rhs))
    }
    return .binaryCall(op: op, name: name, arg1: lhs, arg2: rhs)
  }

  /**
   Attempt to split a symbol into multiplication of two or more items. This is used when ``enableImpliedMultiplication``
   is `true`. It takes a simple approach of looking for known symbols at the start and end of a symbol name. When a
   match is found, it constructs a multiplication of two new symbols, one of which is converted into a constant.

   This routine is used both during the initial parse of the function definition *and* during the evaluation of the
   function if there are unknown symbols in need of resolution.

   - parameter name: the name to split
   - parameter variables: the map to use to locate a known symbol name
   - returns: optional ``Token`` that describes one or more multiplications that came from the given name
   */
  @usableFromInline
  static func attemptImpliedMultiplication(name: Substring, variables: MathParser.VariableMap) -> Token? {
    for count in 1..<name.count {
      let lhsName = name.dropLast(count)
      let rhsName = name.suffix(count)
      if let value = variables(String(lhsName)) {
        let lhs: Token = .constant(value: value)
        let rhs = attemptImpliedMultiplication(name: rhsName, variables: variables) ?? .variable(name: String(rhsName))
        return Token.reducer(lhs: lhs, rhs: rhs, op: (*), name: "*")
      } else if let value = variables(String(rhsName)) {
        let lhs = attemptImpliedMultiplication(name: lhsName, variables: variables) ?? .variable(name: String(lhsName))
        let rhs: Token = .constant(value: value)
        return Token.reducer(lhs: lhs, rhs: rhs, op: (*), name: "*")
      }
    }
    return nil
  }

  /**
   Attempt to split a unary function name into multiplication of two or more values and a function call. This is used
   when ``enableImpliedMultiplication``
   is `true`. It takes a simple approach of looking for known symbols at the start and end of a symbol name. When a
   match is found, it constructs a multiplication of two new symbols, one of which is converted into a constant, and
   the other is a call to a unary function.

   This routine is used both during the initial parse of the function definition *and* during the evaluation of the
   function if there are unknown symbols in need of resolution.

   Example: `tsin(abc)`: here `name` is "tsin" and it will be evaluated at split points in order to resolve names to
   known symbols. If `t` and `abc` are variables, then the code should reduce to the operations
   `t * sin(abc)` (with `t` and `abc` being resolved to their actual values). Note that parsing has already taken
   place on the argument `abc`, and it might have earlier determined that it was made up of `a * b * c`. Also, if
   `sin` resolved to a variable, then the expression would ultimately resolve to `t * sin * (a * b * c)` instead
   of the function call `sin`.

   - parameter name: the name to split
   - parameter arg: the argument given to the unary function
   - parameter variables: the symbol map to use to locate a known symbol name
   - parameter unaryFunctions: the symbol map to use to locate a known unary function
   - returns: optional Token that describes one or more multiplications that came from the given name
   */
  @usableFromInline
  static func attemptImpliedMultiplication(name: Substring, arg: Token, variables: MathParser.VariableMap,
                                           unaryFunctions: MathParser.UnaryFunctionMap) -> Token? {
    for count in 1..<name.count {
      let lhsName = name.prefix(count)
      let rhsName = String(name.dropFirst(count))
      if let rhsValue = unaryFunctions(rhsName) {

        // Found the largest sequence that matched a known unary function
        if let lhsValue = variables(String(lhsName)) {

          // Found a value to multiply with
          return .reducer(lhs: .constant(value: lhsValue),
                          rhs: .unaryCall(op: rhsValue, name: rhsName, arg: arg),
                          op: (*), name: "*")
        } else if let lhsValue = attemptImpliedMultiplication(name: lhsName, variables: variables) {

          // Found some implied multiplications on the left to multiply with the function result
          return .reducer(lhs: lhsValue,
                          rhs: .unaryCall(op: rhsValue, name: rhsName, arg: arg),
                          op: (*), name: "*")
        }
      }
    }

    return nil
  }
}

/**
 Collection of unresolved names from parse. Attempts to evaluate a token with unresolved names will result in a
 NaN.
 */
public struct Unresolved {
  /// The unresolved variables
  public let variables: Set<String>
  /// The unresolved unary function names
  public let unaryFunctions: Set<String>
  /// The unresolved binary function names
  public let binaryFunctions: Set<String>
  /// True if there are no unresolved symbols
  public var isEmpty: Bool { variables.isEmpty && unaryFunctions.isEmpty && binaryFunctions.isEmpty }
  /// Obtain the number of unresolved symbols
  public var count: Int { [variables, unaryFunctions, binaryFunctions]
    .map { $0.count }
    .sum()
  }

  init(variables: Set<String>, unaryFunctions: Set<String>, binaryFunctions: Set<String>) {
    self.variables = variables
    self.unaryFunctions = unaryFunctions
    self.binaryFunctions = binaryFunctions
  }
}

private extension Sequence where Element: AdditiveArithmetic {
  func sum() -> Element { reduce(.zero, +) }
}
