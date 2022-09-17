// Copyright © 2021 Brad Howes. All rights reserved.

import XCTest
@testable import MathParser

final class MathParserTests: XCTestCase {

  var parser: MathParser!

  override func setUp() {
    parser = MathParser()
  }

  func testDouble() {
    XCTAssertEqual(3, parser.parse("3")?.eval())
    XCTAssertEqual(3, parser.parse(" 3")?.eval())
    XCTAssertEqual(3, parser.parse(" 3 ")?.eval())
    XCTAssertEqual(-3, parser.parse(" -3")?.eval())
    XCTAssertEqual(-3, parser.parse("-3 ")?.eval())
    XCTAssertEqual(-3.45, parser.parse("-3.45")?.eval())
    XCTAssertEqual(-3.45E2, parser.parse("-3.45E2 ")?.eval())
    XCTAssertNil(parser.parse("- 3")?.eval())
  }

  func testConstants() {
    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(.pi, parser.parse("pi")?.eval())
    XCTAssertEqual(.pi, parser.parse("(pi)")?.eval())
    XCTAssertEqual(2 * .pi, parser.parse("2(pi)")?.eval())
    XCTAssertEqual(2 * .pi, parser.parse("2pi")?.eval())
  }

  func testAddition() {
    XCTAssertEqual(3, parser.parse("1+2")?.eval())
    XCTAssertEqual(6, parser.parse("1+2+3")?.eval())
    XCTAssertEqual(6, parser.parse(" 1+ 2 + 3 ")?.eval())
  }

  func testSubtraction() {
    XCTAssertEqual(-1, parser.parse("1 - 2")?.eval())
    XCTAssertEqual(-4, parser.parse("1 - 2 - 3")?.eval())
    XCTAssertEqual(-4, parser.parse(" 1 - 2 - 3 ")?.eval())
  }

  func testOrderOfOperations() {
    let expected: Double = 1.0 + 2.0 * 3.0 / 4.0 - pow(5.0, 6.0)
    let actual = parser.parse(" 1 + 2 * 3 / 4 - 5 ^ 6")
    XCTAssertEqual(expected, actual?.eval())
  }

  func testParentheses() {
    XCTAssertEqual(( 1.0 + 2.0 ) * 3.0 / 4.0 - pow(5.0, (6.0 + 7.0)),
                   parser.parse(" ( 1 + 2 ) * 3 / 4 - 5 ^ ( 6+ 7)")?.eval())
    XCTAssertEqual(1, parser.parse(" (1) ")?.eval())
    XCTAssertEqual(1, parser.parse("((1))")?.eval())
    XCTAssertNil(parser.parse(" () ")?.eval())
    XCTAssertEqual(parser.parse(" ( ( 8 + 9) *3) ")?.eval(), (8+9)*3)
  }

  func testNestedParentheses() {
    let expected: Double = ((1.0 + 2.0) * (3.0 + 4.0)) / pow(5.0, 1.0 + 3.0)
    let actual = parser.parse("((1 + 2) * (3 + 4)) / 5 ^ (1 + 3)")
    XCTAssertEqual(expected, actual?.eval())
  }

  func testMissingClosingParenthesis() {
    XCTAssertNil(parser.parse("(1 + 2"))
  }

  func testMissingOpeningParenthesis() {
    XCTAssertNil(parser.parse("1 + 2)"))
  }

  func testSymbolFound() {
    XCTAssertEqual(pow(1 + 2 * .pi, 2), parser.parse("(1 + 2 * pi) ^ 2")?.eval())
  }

  func testSymbolNotFound() {
    XCTAssertTrue(parser.parse("(1 + 2 * pip) ^ 2")!.eval().isNaN)
  }

  func testFunctionFound() {
    XCTAssertEqual(sin(2 * .pi), parser.parse(" sin(2 * pi)")?.eval())
  }

  func testFunction2Found() {
    XCTAssertEqual(pow(2 * .pi, 3.4), parser.parse(" pow(2 * pi, 3.4)")?.eval())
  }

  func testFunction1NotFound() {
    XCTAssertTrue(parser.parse(" sinc(2 * pi)")!.eval().isNaN)
  }

  func testFunction2NotFound() {
    XCTAssertTrue(parser.parse(" blah(2 * pi, 3.4)")!.eval().isNaN)
  }

  func testImpliedMultiply() {
    // Default is disabled
    XCTAssertNil(parser.parse("2 pi"))
    XCTAssertNil(parser.parse("2pi"))
    XCTAssertNil(parser.parse("2 sin(pi / 2)"))
    XCTAssertNil(parser.parse("2 (1 + 2)"))

    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(2.0 * .pi * 3.0, parser.parse("2 pi * 3")?.eval())
    XCTAssertEqual(2.0 * sin(.pi / 2), parser.parse("2 sin(pi / 2)")?.eval())
    XCTAssertEqual(2.0 * (1 + 2), parser.parse("2(1 + 2)")?.eval())
    XCTAssertEqual(2.0 * .pi, parser.parse("2pi")?.eval())
    XCTAssertEqual(2.0 * 3, parser.parse("(3)2")?.eval())
    XCTAssertNil(parser.parse("2(3, 4)"))
  }

  func testVariables() {
    let token = parser.parse("4 * sin(t * pi)")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    XCTAssertEqual(0.0, token.eval("t", value: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, token.eval("t", value: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, token.eval("t", value: 1.0), accuracy: 1e-5)

    var tv: Double = 0.0
    let symbols: MathParser.SymbolMap = {_ in tv}
    let unaryFunctions: MathParser.UnaryFunctionMap = {_ in cos}

    func eval(at t: Double) -> Double {
      tv = t
      return token.eval(symbols: symbols, unaryFunctions: unaryFunctions)
    }

    XCTAssertEqual(4.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(-4.0, eval(at: 1.0), accuracy: 1e-5)
  }

  func testVariablesWithImpliedMultiplication() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("4sin(t(pi))")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    XCTAssertEqual(0.0, token.eval("t", value: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, token.eval("t", value: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, token.eval("t", value: 1.0), accuracy: 1e-5)

    var tv: Double = 0.0
    let symbols: MathParser.SymbolMap = {_ in tv}
    let unaryFunctions: MathParser.UnaryFunctionMap = {_ in cos}

    func eval(at t: Double) -> Double {
      tv = t
      return token.eval(symbols: symbols, unaryFunctions: unaryFunctions)
    }

    XCTAssertEqual(4.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(-4.0, eval(at: 1.0), accuracy: 1e-5)
  }

  func testFunctions() {
    let token = parser.parse("(foo(t * pi))")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    // At this point pi has been resolved, leaving t and foo.
    XCTAssertEqual(3.0 * .pi, token.eval(symbols: {_ in 1.0}, unaryFunctions: {_ in {$0 * 3.0}}), accuracy: 1e-5)
  }

  func testFunctions2() {
    let token = parser.parse("( foo(t * pi , 2 * pi  ))")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    // At this point pi has been resolved, leaving t and foo.
    XCTAssertEqual(((1.5 * .pi) + (2.0 * .pi)) * 3,
                   token.eval(symbols: {_ in 1.5}, binaryFunctions: {_ in {($0 + $1) * 3.0}}),
                   accuracy: 1e-5)
  }

  func testArcTan() {
    struct State {
      var x: Double;
      var y: Double;

      func lookup(name: String) -> Double {
        switch name {
        case "x": return x
        case "y": return y
        default: return .nan
        }
      }
    }

    let epsilon = 1e-5
    let token = parser.parse("atan2(y, x)")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)

    var s = State(x: 0.0, y: 0.0)
    let evaluator: () -> Double = { token.eval(symbols: s.lookup) }
    XCTAssertEqual(evaluator(), 0.0, accuracy: epsilon)
    s.x = -1.0
    XCTAssertEqual(evaluator(), .pi, accuracy: epsilon)
    s.x = 1.0
    XCTAssertEqual(evaluator(), 0.0, accuracy: epsilon)
    s.x = 0.0
    s.y = -0.5
    XCTAssertEqual(evaluator(), -.pi / 2, accuracy: epsilon)
    s.y = 0.5
    XCTAssertEqual(evaluator(), .pi / 2, accuracy: epsilon)
    s.y = .nan
    XCTAssertTrue(evaluator().isNaN)
    s.x = 0.5
    s.y = 0.5
    XCTAssertEqual(evaluator(), 0.7853981633974483, accuracy: epsilon)
  }

  func testReadMe() {
    let parser = MathParser()
    let evaluator = parser.parse("4 * sin(t * π) + 2 * sin(t * π)")
    let v1 = evaluator!.eval("t", value: 0.0) // 0.0
    XCTAssertEqual(0.0, v1)
    let v2 = evaluator!.eval("t", value: 0.5) // 6.0
    XCTAssertEqual(6.0, v2, accuracy: 1e-5)
    let v3 = evaluator!.eval("t", value: 1.0) // 0.0
    XCTAssertEqual(0.0, v3, accuracy: 1e-5) // 0.0
    let v4 = evaluator!.eval("u", value: 1.0) // 0.0
    XCTAssertTrue(v4.isNaN)
  }
}
