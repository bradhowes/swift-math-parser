// Copyright © 2021 Brad Howes. All rights reserved.

import XCTest
@testable import MathParser

final class TokenTests: XCTestCase {

  let variables = ["a": 3.0, "b": 4.0, "ab": 99.0]
  let unaryFuncs: MathParser.UnaryFunctionMap = { name in
    if name == "FOO" { return { $0 * 2.0 } }
    return nil
  }
  let binaryFuncs: MathParser.BinaryFunctionMap = { _ in nil }

  override func setUp() {}

  func evalToken(_ token: Token,
                 variables: MathParser.VariableMap? = nil,
                 unaryFunctions: MathParser.UnaryFunctionMap? = nil,
                 binaryFunctions: MathParser.BinaryFunctionMap? = nil,
                 usingImpliedMultiplication: Bool = false) -> Double {
    token.eval(state: .init(variables: variables ?? self.variables.producer,
                            unaryFunctions: unaryFunctions ?? self.unaryFuncs,
                            binaryFunctions: binaryFunctions ?? self.binaryFuncs,
                            usingImpliedMultiplication: usingImpliedMultiplication))
  }

  func testConstant() {
    XCTAssertEqual(12.345, evalToken(.constant(value: 12.345)))
  }

  func testReducingToConstant() {
    XCTAssertEqual(5.0, evalToken(.reducer(
      lhs: .constant(value: 2.0),
      rhs: .constant(value: 3.0),
      operation: { $0 + $1 })))
  }

  func testVariable() {
    XCTAssertTrue(evalToken(.variable(name: "blah")).isNaN)
  }

  func testImpliedMultiplicationDoesNotOverrideExistingVariable() {
    let variable = Token.variable(name: "ab")
    XCTAssertEqual(99, evalToken(variable, usingImpliedMultiplication: true))
    XCTAssertEqual(99, evalToken(variable, usingImpliedMultiplication: false))
    XCTAssertTrue(variable.unresolved.variables.contains("ab"))
  }

  func testMissingSymbolGeneratesNaN() {
    let variable = Token.variable(name: "abc")
    XCTAssertTrue(evalToken(variable, usingImpliedMultiplication: true).isNaN)
    XCTAssertTrue(evalToken(variable, usingImpliedMultiplication: false).isNaN)
  }

  func testMissingUnaryFuncGeneratesNaN() {
    XCTAssertTrue(evalToken(.unaryCall(proc: .name("abc"), arg: .constant(value: 123.45))).isNaN)
  }

  func testMissingBinaryFuncGeneratesNaN() {
    let token: Token = .binaryCall(proc: .name("abc"),
                                   arg1: .constant(value: 123.45),
                                   arg2: .variable(name: "a"))
    XCTAssertTrue(evalToken(token).isNaN)
    XCTAssertTrue(token.unresolved.variables.contains("a") && token.unresolved.binaryFunctions.contains("abc"))
  }

  func testUnaryCallsAndImpliedMultiplication() {
    XCTAssertEqual(246.90, evalToken(.unaryCall(proc: .name("FOO"), arg: .constant(value: 123.45))))

    let proc: MathParser.UnaryFunction = { $0 + 321.54 }
    XCTAssertEqual(444.99, evalToken(.unaryCall(proc: .proc(proc), arg: .constant(value: 123.45))))

    XCTAssertEqual(123.45 * 6.0, evalToken(.unaryCall(proc: .name("aFOO"), arg: .constant(value: 123.45)),
                                           usingImpliedMultiplication: true))

    // abFOO(x) -> ab * FOO(x)
    XCTAssertEqual(99.0 * 123.45 * 2.0, evalToken(.unaryCall(proc: .name("abFOO"), arg: .constant(value: 123.45)),
                                                  usingImpliedMultiplication: true))
    // aaFOO(x) -> a * a * FOO(x)
    XCTAssertEqual(3.0 * 3.0 * 123.45 * 2.0, evalToken(.unaryCall(proc: .name("aaFOO"), arg: .constant(value: 123.45)),
                                                       usingImpliedMultiplication: true))
  }

  func testUnaryCallResolution() {
    let variables = ["t": Double.pi / 4.0]
    XCTAssertTrue(evalToken(.unaryCall(proc: .name("sin"), arg: .variable(name: "t"))).isNaN)
    XCTAssertTrue(evalToken(.unaryCall(proc: .proc(sin), arg: .variable(name: "t"))).isNaN)
    XCTAssertEqual(0.7071067811865475,
                   evalToken(.unaryCall(proc: .proc(sin), arg: .variable(name: "t")), variables: variables.producer),
                   accuracy: 1.0E-8)
  }

  func testUnresolvedProcessing() {
    XCTAssertTrue(Token.constant(value: 1.2).unresolved.isEmpty)
    XCTAssertTrue(Token.variable(name: "foo").unresolved.count == 1)
    XCTAssertTrue(Token.unaryCall(proc: .name("foo"), arg: .constant(value: 1.2)).unresolved.count == 1)
    XCTAssertTrue(Token.unaryCall(proc: .proc(sin), arg: .constant(value: 1.2)).unresolved.isEmpty)
    XCTAssertTrue(Token.binaryCall(proc: .name("foo"), arg1: .constant(value: 1.2), arg2: .constant(value: 2.1)).unresolved.count == 1)
    XCTAssertTrue(Token.binaryCall(proc: .proc(hypot), arg1: .constant(value: 1.2), arg2: .constant(value: 2.1)).unresolved.isEmpty)
    XCTAssertTrue(Token.mathOp(lhs: .variable(name: "a"), rhs: .constant(value: 1.2), op: +).unresolved.count == 1)
  }

  func testAttemptImpliedMultiplications() {
    let variables: (String) -> Double? = { name in
      switch name {
      case "a": return 2.0
      case "b": return 3.0
      default: return nil
      }
    }

    let unaryFunctions: (String) -> ((Double) -> Double)? = { name in
      switch name {
      case "foo": return { $0 * 123 }
      default: return nil
      }
    }

    XCTAssertTrue(Token.attemptImpliedMultiplication(name: "foo",
                                                      arg: .constant(value: 1.2),
                                                      variables: variables,
                                                      unaryFunctions: unaryFunctions) == nil)
    XCTAssertTrue(Token.attemptImpliedMultiplication(name: "abfoo",
                                                     arg: .constant(value: 1.2),
                                                     variables: variables,
                                                     unaryFunctions: unaryFunctions) != nil)
    XCTAssertTrue(Token.attemptImpliedMultiplication(name: "xyzfoo",
                                                     arg: .constant(value: 1.2),
                                                     variables: variables,
                                                     unaryFunctions: unaryFunctions) == nil)
    XCTAssertTrue(Token.attemptImpliedMultiplication(name: "xyzbar",
                                                     arg: .constant(value: 1.2),
                                                     variables: variables,
                                                     unaryFunctions: unaryFunctions) == nil)
  }
}
