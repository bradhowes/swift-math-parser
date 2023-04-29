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

  func testConstruction() {
    parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return 0.0
      }
    })
    XCTAssertEqual(6, parser.parse("3*b")?.eval())
    XCTAssertEqual(1.5, parser.parse("3÷b")?.eval())

    parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return 0.0
      }
    }, unaryFunctions: {name in
      switch name {
      case "foo": return {(value: Double) -> Double in value * 3}
      default: return nil
      }
    })
    XCTAssertEqual(7, parser.parse("a+3*b")?.eval())

    parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return 0.0
      }
    }, unaryFunctions: {name in
      switch name {
      case "foo": return {(value: Double) -> Double in value * 3}
      default: return nil
      }
    }, binaryFunctions: {name in
      switch name {
      case "bar": return {(x: Double, y: Double) -> Double in x * y}
      default: return nil
      }
    })
    XCTAssertEqual(42, parser.parse("bar(a+3*b,6)")?.eval())

    parser = MathParser(binaryFunctions: {name in
      switch name {
      case "bar": return {(x: Double, y: Double) -> Double in x * y}
      default: return nil
      }
    }, enableImpliedMultiplication: true)
    XCTAssertEqual(12, parser.parse("bar(3, 4)")?.eval())

    XCTAssertEqual(12, parser.parse("abc")?.eval(variables: {name in
      switch name {
      case "abc": return 12
      default: return nil
      }
    }))
  }

  func testImpliedMultiplicationOrUnaryFunction() {
    parser = MathParser(enableImpliedMultiplication: true)
    let variables = ["a": 2.0, "b": 3.0, "c": 4.0]
    XCTAssertTrue(parser.parse("abc(3)")!.eval(variables: variables.producer).isNaN)
    let unary = ["bc": { $0 * 10.0}]
    XCTAssertEqual(2.0 * 30.0, parser.parse("abc(3)")?.eval(variables: variables.producer, unaryFunctions: unary.producer))
  }

  func testImpliedMultiplicationWithUnaryFunction() {
    parser = MathParser(enableImpliedMultiplication: true)
    let variables = ["a": 2.0, "b": 3.0, "c": 4.0]
    let unary = ["bc": { $0 * 10.0}]
    XCTAssertEqual(2.0 * 30.0, parser.parse("abc(3)")!.eval(variables: variables.producer, unaryFunctions: unary.producer))
  }

  func testConstants() {
    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(.pi, parser.parse("pi")?.eval())
    XCTAssertEqual(.pi, parser.parse("π")?.eval())
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
    XCTAssertEqual(expected, actual?.value)
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

  func testFunction1Found() {
    XCTAssertEqual(sin(2 * .pi), parser.parse(" sin(2 * pi)")?.eval())
  }

  func testFunction1NotFound() {
    XCTAssertTrue(parser.parse(" sinc(2 * pi)")!.eval().isNaN)
  }

  func testFunction2Found() {
    XCTAssertEqual(pow(2 * .pi, 3.4), parser.parse(" pow(2 * pi, 3.4)")?.eval())
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
    XCTAssertEqual(.pi * 3.0, parser.parse("π 3")?.eval())
    XCTAssertEqual(2.0 * .pi * 3.0, parser.parse("2pi 3")?.eval())
    XCTAssertEqual(2.0 * sin(.pi / 2), parser.parse("2 sin(pi / 2)")?.eval())
    XCTAssertEqual(2.0 * (1 + 2), parser.parse("2(1 + 2)")?.eval())
    XCTAssertEqual(2.0 * .pi, parser.parse("2pi")?.eval())
    XCTAssertEqual(2.0 * 3, parser.parse("(3)2")?.eval())
    XCTAssertNil(parser.parse("2(3, 4)"))
  }

  func testEvalUnknownVariable() {
    let token = parser.parse("4 * sin(t * pi)")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
  }

  func testEvalWithVariable() {
    let token = parser.parse("4 * sin(t * pi)")!
    XCTAssertEqual(0.0, token.eval("t", value: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, token.eval("t", value: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, token.eval("t", value: 1.0), accuracy: 1e-5)
  }

  func testCustomEvalSymbolMap() {
    let token = parser.parse("4 * sin(t * pi)")!
    var variables = ["t": 0.0]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer)
    }

    XCTAssertEqual(0.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 1.0), accuracy: 1e-5)
  }

  func testCustomEvalSymbolMapDoesNotOverrideMathParserSymbolMap() {
    let token = parser.parse("4 * sin(t * pi)")!
    var variables = ["t": 0.0, "pi": 3.0]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer)
    }

    XCTAssertEqual(0.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 1.0), accuracy: 1e-5)
  }

  func testCustomEvalUnaryFunctionMapDoesNotOverrideMathParserUnaryFunctionMap() {
    let functions: [String: (Double)->Double] = ["sin": cos]
    let token = parser.parse("4 * sin(t * pi)")!
    var variables = ["t": 0.0]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer, unaryFunctions: functions.producer)
    }

    XCTAssertEqual(0.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 1.0), accuracy: 1e-5)
  }

  func testCustomEvalBinaryFunctionMap() {
    let token = parser.parse("4 * sin(foobar(t, 0.25) * pi)")!
    var variables = ["t": 0.0]
    let functions: [String:(Double, Double)->Double] = ["foobar": {$0 + $1}]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer, binaryFunctions: functions.producer)
    }

    XCTAssertEqual(4 * sin(0.25 * .pi), eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4 * sin(0.75 * .pi), eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(4 * sin(1.25 * .pi), eval(at: 1.0), accuracy: 1e-5)
  }

  func testVariablesWithImpliedMultiplication1() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("4sin(tπ)")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    XCTAssertEqual(0.0, token.eval("t", value: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, token.eval("t", value: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, token.eval("t", value: 1.0), accuracy: 1e-5)
  }

  func testUnaryFunction() {
    let token = parser.parse("(foo(t * pi))")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    // At this point pi has been resolved, leaving t and foo.
    XCTAssertEqual(3.0 * .pi, token.eval(variables: {_ in 1.0}, unaryFunctions: {_ in {$0 * 3.0}}), accuracy: 1e-5)
  }

  func testBinaryFunction() {
    let token = parser.parse("( foo(t * pi , 2 * pi  ))")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    // At this point pi has been resolved, leaving t and foo.
    XCTAssertEqual(((1.5 * .pi) + (2.0 * .pi)) * 3,
                   token.eval(variables: {_ in 1.5}, binaryFunctions: {_ in {($0 + $1) * 3.0}}),
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
    let evaluator: () -> Double = { token.eval(variables: s.lookup) }
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

  func testReadMeExample1() {
    let parser = MathParser()
    let evaluator = parser.parse("4 × sin(t × π) + 2 × sin(t × π)")
    var t = 0.0
    var v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    t = 0.25
    v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    t = 0.5
    v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    v = evaluator!.eval("u", value: 1.0)
    XCTAssertTrue(v.isNaN)
  }

  func testReadMeExample2() {
    let myVariables = ["foo": 123.4]
    let myFuncs: [String:(Double)->Double] = ["twice": {$0 + $0}]
    let parser = MathParser(variables: myVariables.producer, unaryFunctions: myFuncs.producer)
    let myEvalFuncs: [String:(Double)->Double] = ["power": {$0 * $0}]
    let evaluator = parser.parse("power(twice(foo))")
    XCTAssertEqual(evaluator?.eval(unaryFunctions: myEvalFuncs.producer), pow(123.4 * 2, 2))
  }

  func testReadMeExample3() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let evaluator = parser.parse("4sin(t π) + 2sin(t π)")
    var t = 0.0
    var v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    t = 0.25
    v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    t = 0.5
    v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    v = evaluator!.eval("u", value: 1.0)
    XCTAssertTrue(v.isNaN)
  }

  func testVariableDict() {
    let parser = MathParser(variableDict: ["a": 1.0, "b": 2.0])
    XCTAssertEqual(3.0, parser.parse("a + b")?.value)
  }

  func testVariableDictIgnoredIfVariablesAlsoPresent() {
    let varMap = ["a": 10.0, "b": 20.0]
    let parser = MathParser(variables: varMap.producer, variableDict: ["a": 1.0, "b": 2.0])
    XCTAssertEqual(30.0, parser.parse("a + b")?.value)
  }

  func testUnaryFunctionDict() {
    let parser = MathParser(unaryFunctionDict: ["a": { $0 * 100.0 }])
    XCTAssertEqual(123.0, parser.parse("a(1.23)")?.value)
  }

  func testUnaryFunctionDictIgnoredIfUnaryFunctionsAlsoPresent() {
    let unaryMap = ["a": { $0 * 1000.0}]
    let parser = MathParser(unaryFunctions: unaryMap.producer, unaryFunctionDict: ["a": { $0 * 2.0}])
    XCTAssertEqual(1230.0, parser.parse("a(1.23)")?.value)
  }

  func testBinaryFunctionDict() {
    let parser = MathParser(binaryFunctionDict: ["a": { $0 * $1 }])
    XCTAssertEqual(12.0, parser.parse("a(3.0, 4.0)")?.value)
  }

  func testBinaryFunctionDictIgnoredIfBinaryFunctionsAlsoPresent() {
    let binaryMap: [String: (Double, Double) -> Double] = ["a": { $0 + $1 }]
    let parser = MathParser(binaryFunctions: binaryMap.producer, binaryFunctionDict: ["a": { $0 * $1}])
    XCTAssertEqual(4.6, parser.parse("a(1.2, 3.4)")?.value)
  }

  func testDeprecations() {
    XCTAssertTrue(!MathParser.defaultSymbols.isEmpty)
    XCTAssertNotNil(MathParser.init(symbols: nil).symbols)
    XCTAssertNotNil(MathParser.init(symbols: nil, binaryFunctions: nil).symbols)
    XCTAssertNotNil(MathParser.init(symbols: { _ in nil },
                                    functions: { _ in nil },
                                    enableImpliedMultiplication: true).symbols)
    XCTAssertNotNil(MathParser.init(symbols: nil,
                                    functions:  nil,
                                    enableImpliedMultiplication: true).symbols)

    let evaluator = parser.parse("5 * 3")
    XCTAssertEqual(15, evaluator?.eval(symbols: nil))

    // Invoke the default binaryFunctionFunctions.producer
    XCTAssertTrue(MathParser.init(symbols: nil, functions: nil).parse("hypot(4.0, 5.0)") != nil)
  }

  func expectFailure(result: Result<Evaluator, MathParserError>, expected: String) {
    switch result {
    case .success: XCTFail("Expected a failure case")
    case .failure(let err): XCTAssertEqual(err.description, expected)
    }
  }

  func testParseWithErrorMissingOperand() {
    expectFailure(result: parser.parseWithError("4.0 +"),
                  expected: """
error: unexpected input
 --> input:1:5
1 | 4.0 +
  |     ^ expected end of input
""")
  }

  func testParseWithErrorOpenParenthesis() {
    expectFailure(result: parser.parseWithError("(4.0 + 3.0"),
                  expected: """
error: multiple failures occurred

error: unexpected input
 --> input:1:11
1 | (4.0 + 3.0
  |           ^ expected ")"

error: unexpected input
 --> input:1:1
1 | (4.0 + 3.0
  | ^ expected 1 element satisfying predicate
  | ^ expected 1 element satisfying predicate
  | ^ expected 1 element satisfying predicate
  | ^ expected double
""")
  }

  func testParseWithErrorExtraCloseParenthesis() {
    expectFailure(result: parser.parseWithError("(4.0 + 3.0))"),
                  expected: """
error: unexpected input
 --> input:1:12
1 | (4.0 + 3.0))
  |            ^ expected end of input
""")
  }

  func testParseWithErrorMissingOperator() {
    expectFailure(result: parser.parseWithError("4.0 3.0"),
                  expected: """
error: unexpected input
 --> input:1:5
1 | 4.0 3.0
  |     ^ expected end of input
""")
  }

  func testEvalWithErrorFailsWithUnknownVariable() {
    let evaluator = parser.parse("undefined(1.2)")!
    XCTAssertTrue(evaluator.value.isNaN)
    let result = evaluator.evalWithError()
    switch result {
    case .success: XCTFail()
    case .failure(let error):
      XCTAssertEqual("\(error)", "Function 'undefined' not found")
    }
  }
}
