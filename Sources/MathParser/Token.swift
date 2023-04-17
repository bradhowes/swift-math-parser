// Copyright © 2021 Brad Howes. All rights reserved.

/**
 Enumeration of the various components identified in a parse of an expression. If an expression can be fully evaluated
 (eg `1 + 2`) then it will result in a `.constant` token with the final value. Otherwise, calling `eval` with
 additional symbols/functions will return a value, though it may be NaN if there were still unresolved symbols or
 functions in the token(s).
 */
@usableFromInline
enum Token {

  @usableFromInline
  enum UnaryProc {
    // Unresolved unary function
    case name(String)
    // Resolved unary function
    case proc(MathParser.UnaryFunction)
  }

  @usableFromInline
  enum BinaryProc {
    // Unresolved binary function
    case name(String)
    // Resolved binary function
    case proc(MathParser.BinaryFunction)
  }

  /// Numerical value from parse
  case constant(value: Double)

  /// Unresolved variable symbol
  case variable(name: String)

  /// Unresolved 1-arg function call
  indirect case unaryCall(proc: UnaryProc, arg: Token)

  /// Unresolved 2-arg function call
  indirect case binaryCall(proc: BinaryProc, arg1: Token, arg2: Token)

  /// Unresolved math operation due to one or both operands being unresolved
  indirect case mathOp(lhs: Token, rhs: Token, op: (Double, Double) -> Double)
}

extension Token {

  /**
   Evaluate the token to obtain a Double value. Resolves variables and functions using the given mappings. If there
   remain unresolved tokens, the result will be a NaN.

   - returns: result of evaluation. May be NaN if unresolved symbol or function still exists
   */
  @inlinable
  func eval(state: EvalState) -> Double {
    switch self {
    case .constant(let value):
      return value

    case .variable(let name):
      if let value = state.variables(name) {
        return value
      } else if state.usingImpliedMultiplication,
                let token = Token.attemptImpliedMultiplication(name: name.prefix(name.count), variables: state.variables) {
        return token.eval(state: state)
      } else {
        return .nan
      }

    case .unaryCall(let proc, let arg):
      switch proc {
      case .name(let name):
        if let proc = state.unaryFunctions(name) {
          return proc(arg.eval(state: state))
        } else if state.usingImpliedMultiplication,
                  let token = Token.attemptImpliedMultiplication(name: name.prefix(name.count),
                                                                 arg: arg,
                                                                 variables: state.variables,
                                                                 unaryFunctions: state.unaryFunctions) {
          return token.eval(state: state)
        } else {
          return .nan
        }

      case .proc(let proc):
        return proc(arg.eval(state: state))
      }

    case .binaryCall(let proc, let arg1, let arg2):
      switch proc {
      case .name(let name):
        if let proc = state.binaryFunctions(name) {
          return proc(arg1.eval(state: state),
                      arg2.eval(state: state))
        } else {
          print("** binary function '\(name)' is unresolved")
          return .nan
        }

      case .proc(let proc):
        return proc(arg1.eval(state: state), arg2.eval(state: state))
      }

    case .mathOp(let lhs, let rhs, let operation):
      return operation(lhs.eval(state: state), rhs.eval(state: state))
    }
  }
}

extension Token {

  var unresolved: Unresolved {
    var variables: Set<String> = .init()
    var unaryFunctions: Set<String> = .init()
    var binaryFunctions: Set<String> = .init()
    var pending :[Token] = .init()

    pending.append(self)
    while let token = pending.popLast() {
      switch token {
      case .constant: break
      case let .variable(name: name): variables.insert(name)
      case let .unaryCall(proc: proc, arg: arg):
        pending.append(arg)
        switch proc {
        case let .name(name): unaryFunctions.insert(name)
        case .proc: break
        }
      case let .binaryCall(proc: proc, arg1: arg1, arg2: arg2):
        pending.append(arg1)
        pending.append(arg2)
        switch proc {
        case let .name(name): binaryFunctions.insert(name)
        case .proc: break
        }
      case let .mathOp(lhs: lhs, rhs: rhs, op: _):
        pending.append(lhs)
        pending.append(rhs)
      }
    }
    return .init(variables: variables, unaryFunctions: unaryFunctions, binaryFunctions: binaryFunctions)
  }
}

extension Token {

  /**
   Attempt to reduce two operand Tokens and an operator. If constants, reduce to the operator applied to the
   constants. Otherwise, return a `.mathOp` token for future evaluation.

   - parameter lhs: left-hand value
   - parameter rhs: right-hand value
   - parameter operation: two-value math operation to perform
   - returns: `.constant` token if reduction took place; otherwise `.mathOp` token
   */
  @inlinable
  static func reducer(lhs: Token, rhs: Token, operation: @escaping (Double, Double) -> Double) -> Token {
    if case let .constant(value: lhs) = lhs, case let .constant(value: rhs) = rhs {
      return .constant(value: operation(lhs, rhs))
    }
    return .mathOp(lhs: lhs, rhs: rhs, op: operation)
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
  static func attemptImpliedMultiplication(name: Substring, variables: MathParser.VariableMap) -> Token? {
    for count in 1..<name.count {
      let lhsName = name.dropLast(count)
      let rhsName = name.suffix(count)
      if let value = variables(String(lhsName)) {
        let lhs: Token = .constant(value: value)
        let rhs = attemptImpliedMultiplication(name: rhsName, variables: variables) ?? .variable(name: String(rhsName))
        return Token.reducer(lhs: lhs, rhs: rhs, operation: (*))
      }
      else if let value = variables(String(rhsName)) {
        let lhs = attemptImpliedMultiplication(name: lhsName, variables: variables) ?? .variable(name: String(lhsName))
        let rhs: Token = .constant(value: value)
        return Token.reducer(lhs: lhs, rhs: rhs, operation: (*))
      }
    }
    return nil
  }

  /**
   Attempt to split a function name into multiplication of two or more values and a function call. This is used
   when `enableImpliedMultiplication`
   is `true`. It takes a simple approach of looking for known symbols at the start and end of a symbol name. When a
   match is found, it constructs a multiplication of two new symbols, one of which is converted into a constant.

   This routine is used both during the initial parse of the function definition *and* during the evaluation of the
   function if there are unknown symbols in need of resolution.

   - parameter name: the name to split
   - parameter symbols: the symbol map to use to locate a known symbol name
   - returns: optional Token that describes one or more multiplications that came from the given name
   */
  @usableFromInline
  static func attemptImpliedMultiplication(name: Substring, arg: Token, variables: MathParser.VariableMap,
                                           unaryFunctions: MathParser.UnaryFunctionMap) -> Token? {
    for count in 1..<name.count {
      let lhsName = name.prefix(count)
      let rhsName = name.dropFirst(count)
      if let rhsValue = unaryFunctions(String(rhsName)) {

        // Found the largest sequence that matched a known unary function
        if let lhsValue = variables(String(lhsName)) {

          // Found a value to multiply with
          return .reducer(lhs: .constant(value: lhsValue),
                          rhs: .unaryCall(proc: .proc(rhsValue), arg: arg),
                          operation: *)
        } else if let lhsValue = attemptImpliedMultiplication(name: lhsName, variables: variables) {

          // Found some implied multiplications on the left to multiply with the function result
          return .reducer(lhs: lhsValue,
                          rhs: .unaryCall(proc: .proc(rhsValue), arg: arg),
                          operation: *)
        }
      }
    }

    return nil
  }
}
