// Copyright © 2021 Brad Howes. All rights reserved.

import XCTest
@testable import MathParser

final class TokenTests: XCTestCase {

  let symbols = ["a": 3.0, "b": 4.0, "ab": 99.0]
  let unaryFuncs: MathParser.UnaryFunctionMap = { name in
    if name == "FOO" { return { $0 * 2.0 } }
    return nil
  }
  let binaryFuncs: MathParser.BinaryFunctionMap = { _ in nil }

  override func setUp() {}

  func evalToken(_ token: Token,
                 symbols: MathParser.SymbolMap? = nil,
                 unaryFunctions: MathParser.UnaryFunctionMap? = nil,
                 binaryFunctions: MathParser.BinaryFunctionMap? = nil,
                 enableImpliedMultiplication: Bool = false) -> Double {
    token.eval(symbols: symbols ?? self.symbols.producer,
               unaryFunctions: unaryFunctions ?? self.unaryFuncs,
               binaryFunctions: binaryFunctions ?? self.binaryFuncs,
               enableImpliedMultiplication: enableImpliedMultiplication)
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
    XCTAssertTrue(evalToken(.symbol(name: "blah")).isNaN)
  }

  func testImpliedMultiplicationDoesNotOverrideExistingVariable() {
    let variable = Token.symbol(name: "ab")
    XCTAssertEqual(99, evalToken(variable, enableImpliedMultiplication: true))
    XCTAssertEqual(99, evalToken(variable, enableImpliedMultiplication: false))
  }

  func testMissingSymbolGeneratesNaN() {
    let variable = Token.symbol(name: "abc")
    XCTAssertTrue(evalToken(variable, enableImpliedMultiplication: true).isNaN)
    XCTAssertTrue(evalToken(variable, enableImpliedMultiplication: false).isNaN)
  }

  func testMissingUnaryFuncGeneratesNaN() {
    XCTAssertTrue(evalToken(.unaryCall(proc: .name("abc"), arg: .constant(value: 123.45))).isNaN)
  }

  func testMissingBinaryFuncGeneratesNaN() {
    XCTAssertTrue(evalToken(.binaryCall(proc: .name("abc"),
                                        arg1: .constant(value: 123.45),
                                        arg2: .symbol(name: "a"))).isNaN)
  }

  func testUnaryCallsAndImpliedMultiplication() {
    XCTAssertEqual(246.90, evalToken(.unaryCall(proc: .name("FOO"), arg: .constant(value: 123.45))))

    let proc: MathParser.UnaryFunction = { $0 + 321.54 }
    XCTAssertEqual(444.99, evalToken(.unaryCall(proc: .proc(proc), arg: .constant(value: 123.45))))

    XCTAssertEqual(123.45 * 6.0, evalToken(.unaryCall(proc: .name("aFOO"), arg: .constant(value: 123.45)),
                                           enableImpliedMultiplication: true))

    // abFOO(x) -> ab * FOO(x)
    XCTAssertEqual(99.0 * 123.45 * 2.0, evalToken(.unaryCall(proc: .name("abFOO"), arg: .constant(value: 123.45)),
                                           enableImpliedMultiplication: true))
    // aaFOO(x) -> a * a * FOO(x)
    XCTAssertEqual(3.0 * 3.0 * 123.45 * 2.0, evalToken(.unaryCall(proc: .name("aaFOO"), arg: .constant(value: 123.45)),
                                                  enableImpliedMultiplication: true))
  }

  func testUnaryCallResolution() {
    let symbols = ["t": Double.pi / 4.0]
    XCTAssertTrue(evalToken(.unaryCall(proc: .name("sin"), arg: .symbol(name: "t"))).isNaN)
    XCTAssertTrue(evalToken(.unaryCall(proc: .proc(sin), arg: .symbol(name: "t"))).isNaN)
    XCTAssertEqual(0.7071067811865475,
                   evalToken(.unaryCall(proc: .proc(sin), arg: .symbol(name: "t")), symbols: symbols.producer),
                   accuracy: 1.0E-8)
  }
}
