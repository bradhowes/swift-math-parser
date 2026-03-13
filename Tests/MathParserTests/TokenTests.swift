// Copyright © 2021-2026 Brad Howes. All rights reserved.

import Foundation
import Parsing
import Testing
@testable import MathParser

@Suite
struct TokenTests {

  let variables = ["a": 3.0, "b": 4.0, "ab": 99.0]
  let unaryFuncs: MathParser.UnaryFunctionMap = { name in
    if name == "DOUBLE" { return { $0 * 2.0 } }
    return nil
  }
  let binaryFuncs: MathParser.BinaryFunctionMap = { _ in nil }

  func evalToken(
    _ token: Token,
    variables: MathParser.VariableMap? = nil,
    unaryFunctions: MathParser.UnaryFunctionMap? = nil,
    binaryFunctions: MathParser.BinaryFunctionMap? = nil,
    usingImpliedMultiplication: Bool = false
  ) -> Double {
    (
      try? token.eval(
        state: .init(
          variables: variables ?? self.variables.producer,
          unaryFunctions: unaryFunctions ?? self.unaryFuncs,
          binaryFunctions: binaryFunctions ?? self.binaryFuncs,
          usingImpliedMultiplication: usingImpliedMultiplication
        )
      )
    ) ?? .nan
  }

  @Test
  func testInfixOperationLoggingWorks() {
    let opParser: some TokenReducerParser = Parse {
      "$".map { { Token.reducer(lhs: $0, rhs: $1, op: (*), name: "$") } }
    }

    let tokenParser: some TokenParser = Parse {
      Double.parser().map { Token.constant(value: $0) }
    }

    var logged = false
    var parser = InfixOperation(
      name: "testing", associativity: .left,
      operator: opParser,
      operand: tokenParser,
      implied: nil,
      logging: true
    )

    let input = "123$456"
    var value = try? parser.parse(input[...])
    #expect(nil != value)
    #expect(!logged)

    parser = InfixOperation(
      name: "testing", associativity: .left,
      operator: opParser,
      operand: tokenParser,
      implied: nil,
      logSink: { _ in logged = true }
    )

    value = try? parser.parse("1$2$3$4")
    #expect(nil != value)
    #expect(logged)
  }

  @Test
  func testConstant() {
    #expect(12.345 == evalToken(.constant(value: 12.345)))
  }

  @Test
  func testReducingToConstant() {
    #expect(5.0 == evalToken(.reducer(
      lhs: .constant(value: 2.0),
      rhs: .constant(value: 3.0),
      op: { $0 + $1 }, name: "+")))
  }

  @Test
  func testVariable() {
    #expect(evalToken(.variable(name: "blah")).isNaN)
  }

  @Test
  func testImpliedMultiplicationDoesNotOverrideExistingVariable() {
    #expect(12 == evalToken(Token.variable(name: "ba"), usingImpliedMultiplication: true))
    #expect(99 == evalToken(Token.variable(name: "ab"), usingImpliedMultiplication: true))
    let token = Token.variable(name: "ab")
    #expect(99 == evalToken(token, usingImpliedMultiplication: true))
    #expect(token.unresolved.variables.contains("ab"))
  }

  @Test
  func testMissingSymbolGeneratesNaN() {
    let variable = Token.variable(name: "abc")
    #expect(evalToken(variable, usingImpliedMultiplication: true).isNaN)
    #expect(evalToken(variable, usingImpliedMultiplication: false).isNaN)
  }

  @Test
  func testMissingUnaryFuncGeneratesNaN() {
    #expect(3.0 * 2.0 * 123.45 == evalToken(.unaryCall(op: nil, name: "aDOUBLE", arg: .constant(value: 123.45)), usingImpliedMultiplication: true))
    #expect(evalToken(.unaryCall(op: nil, name: "abc", arg: .constant(value: 123.45))).isNaN)
  }

  @Test
  func testMissingBinaryFuncGeneratesNaN() {
    let token: Token = .binaryCall(op: nil, name: "abc",
                                   arg1: .constant(value: 123.45),
                                   arg2: .variable(name: "a"))
    #expect(evalToken(token).isNaN)
    #expect(token.unresolved.variables.contains("a") && token.unresolved.binaryFunctions.contains("abc"))
  }

  @Test
  func testUnaryCallResolution() {
    let variables = ["t": Double.pi / 4.0]
    #expect(evalToken(.unaryCall(op: nil, name: "sin", arg: .variable(name: "t"))).isNaN)
    #expect(evalToken(.unaryCall(op: sin, name: "sin", arg: .variable(name: "t"))).isNaN)
    #expect(0.7071067811865475 ==
            evalToken(.unaryCall(op: sin, name: "sin", arg: .variable(name: "t")), variables: variables.producer))
  }

  @Test
  func testUnresolvedProcessing() {
    #expect(Token.constant(value: 1.2).unresolved.isEmpty)
    #expect(Token.variable(name: "foo").unresolved.count == 1)
    #expect(Token.unaryCall(op: nil, name: "foo", arg: .constant(value: 1.2)).unresolved.count == 1)
    #expect(Token.unaryCall(op: sin, name: "sin", arg: .constant(value: 1.2)).unresolved.isEmpty)
    #expect(Token.binaryCall(op: nil, name: "foo", arg1: .constant(value: 1.2), arg2: .constant(value: 2.1)).unresolved.count == 1)
    #expect(Token.binaryCall(op: hypot, name: "hypot", arg1: .constant(value: 1.2), arg2: .constant(value: 2.1)).unresolved.isEmpty)
    #expect(Token.binaryCall(op: +, name: "+", arg1: .variable(name: "a"), arg2: .constant(value: 1.2)).unresolved.count == 1)
  }

  @Test
  func testDescription() {
    #expect("1.23" == Token.constant(value: 1.23).description)
    #expect("foobar" == Token.variable(name: "foobar").description)
    #expect("unary(+(1.0, 2.0))" == Token.unaryCall(op: nil, name: "unary",
                                                    arg: .binaryCall(op: (+), name: "+",
                                                                     arg1: .constant(value: 1),
                                                                     arg2: .constant(value: 2))).description)
    #expect("binary(1.0, blah)" == Token.binaryCall(op: nil, name: "binary",
                                                    arg1: .constant(value: 1),
                                                    arg2: .variable(name: "blah")).description)
    #expect("+(1.0, 2.0)" == Token.binaryCall(op: +, name: "+",
                                              arg1: .constant(value: 1),
                                              arg2: .constant(value: 2)).description)
  }

  @Test
  func testTokenEvalThrowsError() {
    #expect(throws: MathParserError.self) {
      try Token.variable(name: "undefined").eval(state: .init(variables: variables.producer,
                                                              unaryFunctions: unaryFuncs,
                                                              binaryFunctions: binaryFuncs,
                                                              usingImpliedMultiplication: false))
    }
  }

  @Test
  func testTokenEvalThrowsErrorForUndefinedVariable() {
    do {
      _ = try Token.variable(name: "undefined").eval(
        state: .init(
          variables: variables.producer,
          unaryFunctions: unaryFuncs,
          binaryFunctions: binaryFuncs,
          usingImpliedMultiplication: false
        )
      )
    } catch {
      print(error)
      #expect("\(error)" == "Variable 'undefined' not found")
    }
  }

  @Test
  func testTokenEvalThrowsErrorForUndefinedUnaryFunction() {
    do {
      _ = try Token.unaryCall(op: nil, name: "undefined", arg: .constant(value: 1.2))
        .eval(state: .init(variables: variables.producer,
                           unaryFunctions: unaryFuncs,
                           binaryFunctions: binaryFuncs,
                           usingImpliedMultiplication: false))
    } catch {
      print(error)
      #expect("\(error)" == "Function 'undefined' not found")
    }
  }

  @Test
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
      #expect("\(error)" == "Function 'undefined' not found")
    }
  }
}
