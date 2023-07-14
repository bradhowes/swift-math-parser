// Copyright © 2023 Brad Howes. All rights reserved.

import Foundation

@inlinable
func multiply(lhs: Token, rhs: Token) -> Token { Token.reducer(lhs: lhs, rhs: rhs, op: (*), name: "*") }

@usableFromInline
typealias SplitResult = (token: Token, remaining: Substring)

@inlinable
func splitIdentifier(_ identifier: Substring, variables: MathParser.VariableMap) -> SplitResult? {
  if let value = variables(String(identifier)) {
    return (token: .constant(value: value), identifier.dropLast(identifier.count))
  }
  for count in 1..<identifier.count {
    if let value = variables(String(identifier.dropLast(count))) {
      let lhs: Token = .constant(value: value)
      let rightIdent = identifier.suffix(count)
      if let (rhs, remaining) = splitIdentifier(rightIdent, variables: variables) {
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
func searchForUnaryIdentifier(_ identifier: Substring, unaries: MathParser.UnaryFunctionMap) -> SearchResult? {
  for count in 0..<identifier.count {
    if let op = unaries(String(identifier.dropFirst(count))) {
      return (op: op, name: identifier.dropFirst(count))
    }
  }
  return nil
}

@inlinable
func splitUnaryIdentifier(_ identifier: Substring, arg: Token, unaries: MathParser.UnaryFunctionMap,
                          variables: MathParser.VariableMap) -> Token? {
  if let op = searchForUnaryIdentifier(identifier, unaries: unaries),
     let split = splitIdentifier(identifier.dropLast(op.name.count), variables: variables) {
    if split.remaining.isEmpty {
      return multiply(lhs: split.token, rhs: .unaryCall(op: op.op, name: op.name, arg: arg))
    }
    return nil
  }

  if let split = splitIdentifier(identifier, variables: variables),
     split.remaining.isEmpty {
    return multiply(lhs: split.token, rhs: arg)
  }

  return nil
}
