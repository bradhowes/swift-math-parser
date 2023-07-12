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
    (try? token.eval(state: .init(variables: variables ?? self.variables.producer,
                                  unaryFunctions: unaryFunctions ?? self.unaryFuncs,
                                  binaryFunctions: binaryFunctions ?? self.binaryFuncs,
                                  usingImpliedMultiplication: usingImpliedMultiplication))) ?? .nan
  }

  func testConstant() {
    XCTAssertEqual(12.345, evalToken(.constant(value: 12.345)))
  }

  func testReducingToConstant() {
    XCTAssertEqual(5.0, evalToken(.reducer(
      lhs: .constant(value: 2.0),
      rhs: .constant(value: 3.0),
      op: { $0 + $1 }, name: "+")))
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
    XCTAssertTrue(evalToken(.unaryCall(op: nil, name: "abc", arg: .constant(value: 123.45))).isNaN)
  }

  func testMissingBinaryFuncGeneratesNaN() {
    let token: Token = .binaryCall(op: nil, name: "abc",
                                   arg1: .constant(value: 123.45),
                                   arg2: .variable(name: "a"))
    XCTAssertTrue(evalToken(token).isNaN)
    XCTAssertTrue(token.unresolved.variables.contains("a") && token.unresolved.binaryFunctions.contains("abc"))
  }

  func testUnaryCallsAndImpliedMultiplication() {
    XCTAssertEqual(246.90, evalToken(.unaryCall(op: nil, name: "FOO", arg: .constant(value: 123.45))))

    let proc: MathParser.UnaryFunction = { $0 + 321.54 }
    XCTAssertEqual(444.99, evalToken(.unaryCall(op: proc, name: "+", arg: .constant(value: 123.45))))

    XCTAssertEqual(123.45 * 6.0, evalToken(.unaryCall(op: nil, name: "aFOO", arg: .constant(value: 123.45)),
                                           usingImpliedMultiplication: true))

    // abFOO(x) -> ab * FOO(x)
    XCTAssertEqual(99.0 * 123.45 * 2.0, evalToken(.unaryCall(op: nil, name: "abFOO", arg: .constant(value: 123.45)),
                                                  usingImpliedMultiplication: true))
    // aaFOO(x) -> a * a * FOO(x)
    XCTAssertEqual(3.0 * 3.0 * 123.45 * 2.0, evalToken(.unaryCall(op: nil, name: "aaFOO", arg: .constant(value: 123.45)),
                                                       usingImpliedMultiplication: true))
  }

  func testUnaryCallResolution() {
    let variables = ["t": Double.pi / 4.0]
    XCTAssertTrue(evalToken(.unaryCall(op: nil, name: "sin", arg: .variable(name: "t"))).isNaN)
    XCTAssertTrue(evalToken(.unaryCall(op: sin, name: "sin", arg: .variable(name: "t"))).isNaN)
    XCTAssertEqual(0.7071067811865475,
                   evalToken(.unaryCall(op: sin, name: "sin", arg: .variable(name: "t")), variables: variables.producer),
                   accuracy: 1.0E-8)
  }

  func testUnresolvedProcessing() {
    XCTAssertTrue(Token.constant(value: 1.2).unresolved.isEmpty)
    XCTAssertTrue(Token.variable(name: "foo").unresolved.count == 1)
    XCTAssertTrue(Token.unaryCall(op: nil, name: "foo", arg: .constant(value: 1.2)).unresolved.count == 1)
    XCTAssertTrue(Token.unaryCall(op: sin, name: "sin", arg: .constant(value: 1.2)).unresolved.isEmpty)
    XCTAssertTrue(Token.binaryCall(op: nil, name: "foo", arg1: .constant(value: 1.2), arg2: .constant(value: 2.1)).unresolved.count == 1)
    XCTAssertTrue(Token.binaryCall(op: hypot, name: "hypot", arg1: .constant(value: 1.2), arg2: .constant(value: 2.1)).unresolved.isEmpty)
    XCTAssertTrue(Token.binaryCall(op: +, name: "+", arg1: .variable(name: "a"), arg2: .constant(value: 1.2)).unresolved.count == 1)
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

  func testDescription() {
    XCTAssertEqual("1.23", Token.constant(value: 1.23).description)
    XCTAssertEqual("foobar", Token.variable(name: "foobar").description)
    XCTAssertEqual("unary(+(1.0, 2.0))", Token.unaryCall(op: nil, name: "unary",
                                                         arg: .binaryCall(op: (+), name: "+",
                                                                          arg1: .constant(value: 1),
                                                                          arg2: .constant(value: 2))).description)
    XCTAssertEqual("binary(1.0, blah)", Token.binaryCall(op: nil, name: "binary",
                                                         arg1: .constant(value: 1),
                                                         arg2: .variable(name: "blah")).description)
    XCTAssertEqual("+(1.0, 2.0)", Token.binaryCall(op: +, name: "+",
                                                   arg1: .constant(value: 1),
                                                   arg2: .constant(value: 2)).description)
  }

  func testTokenEvalThrowsError() {
    XCTAssertThrowsError(try Token.variable(name: "undefined").eval(state: .init(variables: variables.producer,
                                                                                 unaryFunctions: unaryFuncs,
                                                                                 binaryFunctions: binaryFuncs,
                                                                                 usingImpliedMultiplication: false)))
  }

  func testTokenEvalThrowsErrorForUndefinedVariable() {
    do {
      _ = try Token.variable(name: "undefined").eval(state: .init(variables: variables.producer,
                                                                  unaryFunctions: unaryFuncs,
                                                                  binaryFunctions: binaryFuncs,
                                                                  usingImpliedMultiplication: false))
    } catch {
      print(error)
      XCTAssertEqual("\(error)", "Variable 'undefined' not found")
    }
  }

  func testTokenEvalThrowsErrorForUndefinedUnaryFunction() {
    do {
      _ = try Token.unaryCall(op: nil, name: "undefined", arg: .constant(value: 1.2))
        .eval(state: .init(variables: variables.producer,
                           unaryFunctions: unaryFuncs,
                           binaryFunctions: binaryFuncs,
                           usingImpliedMultiplication: false))
    } catch {
      print(error)
      XCTAssertEqual("\(error)", "Function 'undefined' not found")
    }
  }

  func testTokenEvalThrowsErrorForUndefinedBinaryFunction() {
    do {
      _ = try Token.binaryCall(op: nil, name: "undefined",
                               arg1: .constant(value: 1.2),
                               arg2: .constant(value: 2.4))
        .eval(state: .init(variables: variables.producer,
                           unaryFunctions: unaryFuncs,
                           binaryFunctions: binaryFuncs,
                           usingImpliedMultiplication: false))
    } catch {
      print(error)
      XCTAssertEqual("\(error)", "Function 'undefined' not found")
    }
  }
}
