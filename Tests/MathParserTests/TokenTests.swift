// Copyright © 2021 Brad Howes. All rights reserved.

import XCTest
@testable import MathParser

final class TokenTests: XCTestCase {

  let symbols = ["a": 3.0, "b": 4.0, "ab": 13.0]

  let unaryFuncs: MathParser.UnaryFunctionMap = { name in
    if name == "FOO" { return { $0 * 2.0 } }
    return nil
  }

  let binaryFuncs: MathParser.BinaryFunctionMap = { _ in nil }

  override func setUp() {
  }

  func testDeprecatedEval() {
    let constant = Token.constant(123)
    XCTAssertEqual(123, constant.eval({(name: String) -> Double? in nil},
                                      {(name: String) -> ((Double) -> Double)? in
      {(x: Double) -> Double in x * x}},
                                      true))

    let variable = Token.variable("a")
    XCTAssertEqual(123, variable.eval({(name: String) -> Double? in 123},
                                      {(name: String) -> ((Double) -> Double)? in nil},
                                      true))

    let func1 = Token.function1("a", .constant(3))
    XCTAssertEqual(9, func1.eval({(name: String) -> Double? in 123},
                                      {(name: String) -> ((Double) -> Double)? in {x in x * x}},
                                      true))
    let func2 = Token.function2("a", .constant(3), .constant(4))
    XCTAssertTrue(func2.eval({(name: String) -> Double? in 123}, {(name: String) -> ((Double) -> Double)? in {x in x * x}},
                             true).isNaN)
  }

  func testConstant() {
    XCTAssertEqual(12.345, Token.constant(12.345).eval(symbols.producer, unaryFuncs, binaryFuncs))
  }

  func testReducingToConstant() {
    XCTAssertEqual(5.0, Token.reducer(
      lhs: .constant(2.0),
      rhs: .constant(3.0),
      operation: { $0 + $1 })
      .eval(symbols.producer, unaryFuncs, binaryFuncs))
  }

  func testImpliedMultiplication() {
    let variable = Token.variable("ab")
    XCTAssertEqual(12, variable.eval(symbols.producer, unaryFuncs, binaryFuncs, true))
    XCTAssertEqual(13, variable.eval(symbols.producer, unaryFuncs, binaryFuncs, false))
  }

  func testMissingSymbolGeneratesNaN() {
    let variable = Token.variable("abc")
    XCTAssertTrue(variable.eval(symbols.producer, unaryFuncs, binaryFuncs, true).isNaN)
    XCTAssertTrue(variable.eval(symbols.producer, unaryFuncs, binaryFuncs, false).isNaN)
  }

  func testMissingUnaryFuncGeneratesNaN() {
    XCTAssertTrue(Token.function1("abc", .constant(123.45)).eval(symbols.producer, unaryFuncs, binaryFuncs).isNaN)
  }

  func testMissingBinaryFuncGeneratesNaN() {
    XCTAssertTrue(Token.function2("abc", .constant(123.45), .variable("a"))
      .eval(symbols.producer, unaryFuncs, binaryFuncs).isNaN)
  }
}
