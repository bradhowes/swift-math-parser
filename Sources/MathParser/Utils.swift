// Copyright © 2023 Brad Howes. All rights reserved.

import Foundation

@inlinable
func multiply(lhs: Token, rhs: Token) -> Token { Token.reducer(lhs: lhs, rhs: rhs, op: (*), name: "*") }

@usableFromInline
typealias SplitResult = (token: Token, remaining: Substring)

@inlinable
func splitIdentifier(_ identifier: Substring, state: EvalState) -> SplitResult? {
  if let value = state.findVariable(name: identifier) {
    return (token: .constant(value: value), identifier.dropLast(identifier.count))
  }
  for count in 1..<identifier.count {
    let name = identifier.dropLast(count)
    let value = state.findVariable(name: name)
    if let value = value {
      let lhs: Token = .constant(value: value)
      let rightIdent = identifier.suffix(count)
      if let (rhs, remaining) = splitIdentifier(rightIdent, state: state) {
        return (token: multiply(lhs: lhs, rhs: rhs), remaining: remaining)
      }
      return (token: lhs, remaining: rightIdent)
    }
  }
  return nil
}

@usableFromInline
typealias SearchResult = (op: MathParser.UnaryFunction, name: Substring)

@inlinable
func searchForUnaryIdentifier(_ identifier: Substring, state: EvalState) -> SearchResult? {
  for count in 0..<identifier.count {
    let name = identifier.dropFirst(count)
    if let op = state.findUnary(name: name) {
      return (op: op, name: name)
    }
  }
  return nil
}

@inlinable
func splitUnaryIdentifier(_ identifier: Substring, arg: Token, state: EvalState) -> Token? {
  if let op = searchForUnaryIdentifier(identifier, state: state),
     let split = splitIdentifier(identifier.dropLast(op.name.count), state: state) {
    if split.remaining.isEmpty {
      return multiply(lhs: split.token, rhs: .unaryCall(op: op.op, name: op.name, arg: arg))
    }
    return nil
  }

  if let split = splitIdentifier(identifier, state: state),
     split.remaining.isEmpty {
    return multiply(lhs: split.token, rhs: arg)
  }

  return nil
}
