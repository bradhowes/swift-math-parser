import XCTest
@testable import MathParser

final class MathParserTests: XCTestCase {

  let parser = MathParser()

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
    XCTAssertEqual(1 + 2 * 3 / 4 - pow(5, 6), parser.parse(" 1 + 2 * 3 / 4 - 5 ^ 6")?.eval())
  }

  func testParentheses() {
    XCTAssertEqual(( 1 + 2 ) * 3 / 4 - pow(5, (6 + 7)), parser.parse(" ( 1 + 2 ) * 3 / 4 - 5 ^ ( 6+ 7)")?.eval())
    XCTAssertEqual(1, parser.parse(" (1) ")?.eval())
    XCTAssertEqual(1, parser.parse("((1))")?.eval())
    XCTAssertNil(parser.parse(" () ")?.eval())
  }

  func testNestedParentheses() {
    XCTAssertEqual(((1 + 2) * (3 + 4)) / pow(5, 1 + 3), parser.parse("((1 + 2) * (3 + 4)) / 5 ^ (1 + 3)")?.eval())
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
    XCTAssertTrue(parser.parse("(1 + 2 * pip) ^ 2")?.eval().isNaN ?? false)
  }

  func testFunctionFound() {
    XCTAssertEqual(sin(2 * .pi), parser.parse(" sin(2 * pi)")?.eval())
  }

  func testFunctionNotFound() {
    XCTAssertTrue(parser.parse(" sinc(2 * pi)")?.eval().isNaN ?? false)
  }

  func testImpliedMultiply() {
    // Default is disabled
    XCTAssertNil(parser.parse("2 pi"))
    XCTAssertNil(parser.parse("2 sin(pi / 2)"))
    XCTAssertNil(parser.parse("2 (1 + 2)"))

    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(2 * .pi, parser.parse("2 pi")?.eval())
    XCTAssertEqual(2 * sin(.pi / 2), parser.parse("2 sin(pi / 2)")?.eval())
    XCTAssertEqual(2 * (1 + 2), parser.parse("2 (1 + 2)")?.eval())
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
    let functions: MathParser.FunctionMap = {_ in cos}

    func eval(at t: Double) -> Double {
      tv = t
      return token.eval(symbols: symbols, functions: functions)
    }

    XCTAssertEqual(4.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(-4.0, eval(at: 1.0), accuracy: 1e-5)
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
  }
}
