// Copyright © 2021 Brad Howes. All rights reserved.

import XCTest
import Parsing
@testable import MathParser

final class MathParserTests: XCTestCase {

  var parser: MathParser!

  override func setUp() {
    parser = MathParser()
  }

  func testIdentifiersCanHoldEmojis() {
    XCTAssertEqual(sin(1.5), parser.parse("sin(🌍)")?.eval("🌍", value: 1.5))
    XCTAssertEqual(1.5 + sin(1.5), parser.parse("🌍🌍 + sin(🌍🌍)")?.eval("🌍🌍", value: 1.5))
    XCTAssertEqual(1.3, parser.parse("💐power🤷‍♂️")?.eval("💐power🤷‍♂️", value: 1.3))
  }

  func testSpacesAreSkippedAroundSymbols() {
    XCTAssertEqual(8.0, parser.parse(" pow( 2 , 3 ) * 1")?.eval())
  }

  func testSpacesAreNotRequiredAroundSymbols() {
    XCTAssertEqual(8.0, parser.parse("pow(2,3)*1")?.eval())
  }

  func testNoSpacesBetweenFunctionNamesAndParenthesis() {
    XCTAssertNil(parser.parse(" pow ( 2 , 3 ) "))
  }

  func testIntegersAreProperlyParsedAsDoubles() {
    XCTAssertEqual(3, parser.parse("3")?.eval())
    XCTAssertEqual(3, parser.parse(" 3")?.eval())
    XCTAssertEqual(3, parser.parse(" 3 ")?.eval())
  }

  func testNegativeIntegersAreParsedAsDoubles() {
    XCTAssertEqual(-3, parser.parse(" -3")?.eval())
    XCTAssertEqual(-3, parser.parse("-3 ")?.eval())
    XCTAssertEqual(-3, parser.parse(" -3 ")?.eval())
  }

  func testNegationOperatorMustBeNextToNumber() {
    XCTAssertNil(parser.parse("- 3")?.eval())
  }

  func testFloatingPointLiteralsAreParsedAsDoubles() {
    XCTAssertEqual(-3.45, parser.parse("-3.45")?.eval())
    XCTAssertEqual(-3.45E2, parser.parse("-3.45E2 ")?.eval())
    XCTAssertEqual(-3.45E-2, parser.parse(" -3.45e-2 ")?.eval())
  }

  func testNonArabicNumbersAreNotParsedAsNumbers() {
    // We don't support non-Arabic numbers -- below is Thai 3.
    XCTAssertNil(parser.parse("๓")?.eval())
  }

  func testNegation() {
    XCTAssertEqual(-2, parser.parse("-2")?.eval())
    XCTAssertNil(parser.parse("- 2")?.eval())

    XCTAssertNil(parser.parse("--2")?.eval())
    XCTAssertNil(parser.parse("- -2")?.eval())
    XCTAssertNil(parser.parse("--3-2")?.eval())

    XCTAssertEqual(2, parser.parse("-(-2)")?.eval())
    XCTAssertEqual(5, parser.parse("-(-3-2)")?.eval())
    XCTAssertEqual(pow(2, -(1 - 8)), parser.parse("2^-(1-8)")?.eval())
    XCTAssertEqual(5.0 * -.pi, parser.parse("5 * -pi")?.eval())
    XCTAssertEqual(5.0 * -.pi * -3, parser.parse("5 * -pi * -t")?.eval("t", value: 3))
  }

  func testParserUsesCustomVariableMap() {
    parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return nil
      }
    })
    XCTAssertEqual(6, parser.parse("3*b")?.eval())
    XCTAssertEqual(1.5, parser.parse("3÷b")?.eval())
  }

  func testParserCustomVariableMapIgnoredByEval() {
    parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return nil
      }
    })

    let z = parser.parse("b*pi")
    XCTAssertEqual(1, z?.unresolved.variables.count)
    XCTAssertEqual(2.0 * .pi, z?.eval())
  }

  func testParserUsesCustomUnaryFunctionMap() {
    parser = MathParser(unaryFunctions: {name in
      switch name {
      case "foo": return {(value: Double) -> Double in value * 3}
      default: return nil
      }
    })
    XCTAssertEqual(sin(3.0 * .pi), parser.parse("sin(foo(pi))")?.eval())
  }

  func testParserUsesCustomBinaryFunctionMap() {
    parser = MathParser(binaryFunctions: {name in
      switch name {
      case "bar": return {(x: Double, y: Double) -> Double in x * y}
      default: return nil
      }
    })
    XCTAssertEqual(.pi * .e, parser.parse("bar(pi, e)")?.eval())
  }

  func testImpliedMultiplicationWithConstants() {
    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(.pi, parser.parse("pi")?.eval())
    XCTAssertEqual(.pi, parser.parse("π")?.eval())
    XCTAssertEqual(.pi * .pi, parser.parse("ππ")?.eval())
    XCTAssertEqual(.e * .pi, parser.parse("e(pi)")?.eval())
    XCTAssertEqual(.e * .pi, parser.parse("epi")?.eval())
    XCTAssertEqual(.e * .pi, parser.parse("pie")?.eval())
  }

  func testImpliedMultiplicationWithNumbers() {
    parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(2.0 * 3.0, parser.parse("2 3")?.eval())
    XCTAssertEqual(2.0 + 3.0, parser.parse("2 +3")?.eval())
    XCTAssertEqual(2.0 + 3.0, parser.parse("2+3")?.eval())
    XCTAssertEqual(2.0 + 3.0, parser.parse("2+ 3")?.eval())
    XCTAssertEqual(2.0 * -3.0, parser.parse("2 -3")?.eval())
    XCTAssertEqual(2.0 * -3.0, parser.parse("2-3")?.eval()) // !!!
    XCTAssertEqual(2.0 - 3.0, parser.parse("2- 3")?.eval())
  }

  func testImpliedMultiplicationWithNumberAndSymbol() {
    parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(2.0 * .pi, parser.parse("2pi")?.eval())
    XCTAssertEqual(2.0 * .pi, parser.parse("2(pi)")?.eval())
    XCTAssertEqual(2.0 * .pi, parser.parse("2.000pi")?.eval())
    XCTAssertEqual(2.0 * .pi, parser.parse("2 pi")?.eval())
    XCTAssertEqual(2.0 * .pi, parser.parse("pi 2")?.eval())
  }

  func testImpliedMultiplicationOnUnaryFunctionResolution() {
    parser = MathParser(enableImpliedMultiplication: true)
    var variables = ["a": 2.0, "b": 3.0, "c": 4.0]
    var unary = ["bc": { $0 * 10.0}]
    let token = parser.parse("abc(3)")
    XCTAssertEqual(1, token?.unresolved.unaryFunctions.count)
    XCTAssertEqual(2.0 * 3.0 * 10, token!.eval(variables: variables.producer, unaryFunctions: unary.producer))

    unary["abc"] = { $0 + 14 }
    XCTAssertEqual(17, token!.eval(variables: variables.producer, unaryFunctions: unary.producer))

    variables["abc"] = 24
    XCTAssertEqual(17, token!.eval(variables: variables.producer, unaryFunctions: unary.producer))

    XCTAssertEqual(72.0, token!.eval(variables: variables.producer))
  }

  func testAddition() {
    XCTAssertEqual(3, parser.parse("1+2")?.eval())
    XCTAssertEqual(6, parser.parse("1+2+3")?.eval())
    XCTAssertEqual(6, parser.parse(" 1+ 2 + 3 ")?.eval())
    XCTAssertEqual(-1, parser.parse("1+-2")?.eval())
    XCTAssertEqual(-1, parser.parse("1+ -2")?.eval())
    XCTAssertEqual(-3, parser.parse("-1+ -2")?.eval())
  }

  func testSubtraction() {
    XCTAssertEqual(-1, parser.parse("1 - 2")?.eval())
    XCTAssertEqual(-4, parser.parse("1 - 2 - 3")?.eval())
    XCTAssertEqual(-4, parser.parse(" 1 - 2 - 3 ")?.eval())
  }

  func testAdditionAndSubtraction() {
    XCTAssertEqual(0, parser.parse("1 + 2 - 3")?.eval())
    XCTAssertEqual(0, parser.parse("1 + (2 - 3)")?.eval())
    XCTAssertEqual(0, parser.parse("(1 + 2) - 3 ")?.eval())

    XCTAssertEqual(2, parser.parse("1 - 2 + 3")?.eval())
    XCTAssertEqual(-4, parser.parse("1 - (2 + 3)")?.eval())
    XCTAssertEqual(2, parser.parse("(1 - 2) + 3 ")?.eval())
  }

  func testExponentiationIsRightAssociative() {
    XCTAssertEqual(pow(5.0, pow(2, pow(3, 4))), parser.parse("5^2^3^4")?.eval())
  }

  func testOrderOfOperations() {
    XCTAssertEqual(1.0 + 2.0 * 3.0 / 4.0 - pow(5.0, pow(2, 3)), parser.parse("1+2*3/4-5^2^3")?.eval())
  }

  func testParenthesesAltersOrderOfOperations() {
    XCTAssertEqual((1.0 + 2.0 ) * 3.0 / 4.0 - pow(5.0, (6.0 + 7.0)), parser.parse("(1+2)*3/4-5^(6+7)")?.eval())
    XCTAssertEqual(((8 + 9) * 3), parser.parse("((8+9)*3) ")?.eval())
  }

  func testEmptyParenthesesIsFailure() {
    XCTAssertNil(parser.parse(" () ")?.eval())
  }

  func testParenthesesAroundConstantOrSymbolIsOk() {
    XCTAssertEqual(1, parser.parse(" (1) ")?.eval())
    XCTAssertEqual(.pi, parser.parse(" (pi) ")?.eval())
  }

  func testNestedParentheses() {
    XCTAssertEqual(1, parser.parse("((((((1))))))")?.eval())
    XCTAssertEqual(((1.0 + 2.0) * (3.0 + 4.0)) / pow(5.0, 1.0 + 3.0), parser.parse("((1+2)*(3+4))/5^(1+3)")?.eval())
  }

  func testMissingClosingParenthesisFails() {
    XCTAssertNil(parser.parse("(1 + 2"))
  }

  func testMissingOpeningParenthesisFails() {
    XCTAssertNil(parser.parse("1 + 2)"))
  }

  func testDefaultSymbolsAreFound() {
    XCTAssertEqual(pow(1 + 2 * .pi, 2 * .e), parser.parse("(1 + 2 * pi) ^ (2 * e)")?.eval())
  }

  func testEvalWithUndefinedSymbolFails() {
    XCTAssertTrue(parser.parse("(1 + 2 * pip) ^ 2")!.eval().isNaN)
  }

  func testDefaultUnaryFunctionsAreFound() {
    let sgn: (Double) -> Double = { $0 < 0 ? -1 : $0 > 0 ? 1 : 0 }
    XCTAssertEqual(tan(sin(cos(.pi/4.0))), parser.parse("tan(sin(cos(pi/4)))")?.eval())
    XCTAssertEqual(log10(log(log(log2(exp(.pi))))),
                   parser.parse("log10(ln(loge(log2(exp(pi)))))")?.eval())
    XCTAssertEqual(ceil(floor(round(sqrt(sqrt(cbrt(abs(sgn(-3)))))))),
                   parser.parse("ceil(floor(round(sqrt(√(cbrt(abs(sgn(-3))))))))")?.eval())
  }

  func testSgnFunction() {
    XCTAssertEqual(-1, parser.parse("sgn(-1.33433)")?.eval())
    XCTAssertEqual(1, parser.parse("sgn(1.33433)")?.eval())
    XCTAssertEqual(0, parser.parse("sgn(0.00000)")?.eval())
  }

  func testFunction1NotFoundFails() {
    XCTAssertTrue(parser.parse(" sinc(2 * pi)")!.eval().isNaN)
  }

  func testFunction2NotFoundFails() {
    XCTAssertTrue(parser.parse(" blah(2 * pi, 3.4)")!.eval().isNaN)
  }

  func testImpliedMultiplicationIsDisableByDefault() {
    XCTAssertNil(parser.parse("2 pi"))
    XCTAssertNil(parser.parse("2pi"))
    XCTAssertNil(parser.parse("2 sin(pi / 2)"))
    XCTAssertNil(parser.parse("2 (1 + 2)"))
  }

  func testImpliedMultiplicationWithBinaryArgumentFails() {
    XCTAssertNil(parser.parse("2(3, 4)"))
  }

  func testImpliedMultiplicationExamples() {
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

  func testEvalWithDelayedResolutionVariable() {
    let token = parser.parse("4 * sin(t * pi)")!
    XCTAssertEqual(0.0, token.eval("t", value: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, token.eval("t", value: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, token.eval("t", value: 1.0), accuracy: 1e-5)
  }

  func testEvalWithDelayedResolutionVariableAndUnknownSymbolFails() {
    let token = parser.parse("4 * sin(t * pi) + u")!
    XCTAssertTrue(token.eval("t", value: 0.0).isNaN)
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
    let proc: (Double) -> Double = { 4 * sin($0 * .pi) }
    let token = parser.parse("4 * sin(t * pi)")
    var variables = ["t": 0.0, "pi": 3.0]

    func eval(at t: Double) -> Double? {
      variables["t"] = t
      return token?.eval(variables: variables.producer)
    }

    XCTAssertEqual(proc(0.0), eval(at: 0.0))
    XCTAssertEqual(proc(0.5), eval(at: 0.5))
    XCTAssertEqual(proc(1.0), eval(at: 1.0))
  }

  func testCustomEvalUnaryFunctionMapDoesNotOverrideMathParserUnaryFunctionMap() {
    let functions: [String: (Double)->Double] = ["sin": cos]
    let proc: (Double) -> Double = { 4 * sin($0 * .pi) }
    let token = parser.parse("4 * sin(t * pi)")
    var variables = ["t": 0.0]

    func eval(at t: Double) -> Double? {
      variables["t"] = t
      return token?.eval(variables: variables.producer, unaryFunctions: functions.producer)
    }

    XCTAssertEqual(proc(0.0), eval(at: 0.0))
    XCTAssertEqual(proc(0.5), eval(at: 0.5))
    XCTAssertEqual(proc(1.0), eval(at: 1.0))
  }

  func testCustomEvalBinaryFunctionMap() {
    let token = parser.parse("4 * sin(foobar(t, 0.25) * pi)")
    let proc: (Double) -> Double = { 4 * sin(($0 + 0.25) * .pi) }
    var variables = ["t": 0.0]
    let functions: [String:(Double, Double)->Double] = ["foobar": {$0 + $1}]

    func eval(at t: Double) -> Double? {
      variables["t"] = t
      return token?.eval(variables: variables.producer, binaryFunctions: functions.producer)
    }

    XCTAssertEqual(proc(0.0), eval(at: 0.0))
    XCTAssertEqual(proc(0.5), eval(at: 0.5))
    XCTAssertEqual(proc(1.0), eval(at: 1.0))
  }

  func testUnresolvedVariableWithImpliedMultiplication1() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("tπ t")
    let proc: (Double) -> Double = { $0 * .pi * $0 }
    XCTAssertTrue(token!.eval().isNaN)
    XCTAssertEqual(proc(0.0), token?.eval("t", value: 0.0))
    XCTAssertEqual(proc(0.5), token?.eval("t", value: 0.5))
    XCTAssertEqual(proc(1.0), token?.eval("t", value: 1.0))
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

  func testBuggyAddition() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("2+5")
    XCTAssertEqual(7, token?.eval())
  }

  func testBuggyImpliedMultiplication() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("6.0 / 2(1 + 2)")
    XCTAssertEqual(3*3, token?.eval())
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

  func testImpliedNumberFunction() {
    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(4 * cos(1.25 * .pi), parser.parse("4 cos(1.25 π)")?.eval())
    XCTAssertEqual(4 * cos(1.25 * .pi), parser.parse("4cos(1.25π)")?.eval())
  }

  func testFaultyAdditionRegression() {
    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(4.0 * .pi + 2.0 * .pi, parser.parse("4 * π + 2 * π")?.eval())
    XCTAssertEqual(4.0 * .pi + 2.0 * .pi, parser.parse("4 π + 2 π")?.eval())
    XCTAssertEqual(4.0 * .pi + 2.0 * .pi, parser.parse("4π + 2 π")?.eval())
    XCTAssertEqual(4.0 * .pi + 2.0 * .pi, parser.parse("4π+ 2 π")?.eval())
    XCTAssertEqual(4.0 * .pi + 2.0 * .pi, parser.parse("4π+2 π")?.eval())
    XCTAssertEqual(4.0 * .pi + 2.0 * .pi, parser.parse("4π+2π")?.eval())
  }

  func testReadMeExample3() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let evaluator = parser.parse("4 sin(t π) + 2 * sin(t π)")
    let proc: (Double) -> Double = { 4 * sin($0 * .pi) + 2 * sin($0 * .pi) }
    for t in [0.0, 0.25, 0.5] {
      let v = evaluator!.eval("t", value: t)
      XCTAssertEqual(proc(t), v)
    }
    let v = evaluator!.eval("u", value: 1.0)
    XCTAssertTrue(v.isNaN)
    XCTAssertEqual(try! evaluator!.evalResult("t", value: 0.25).get(), proc(0.25))

    guard case .failure(let error) = evaluator!.evalResult("u", value: 0.25),
          case MathParserError.variableNotFound(let name) = error,
          name == "t"
    else {
      XCTFail("Unexpected result or error")
      return
    }
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

  func expectFailure(result: Result<Evaluator, MathParserError>, expected: String) {
    switch result {
    case .success: XCTFail("Expected a failure case")
    case .failure(let err): XCTAssertEqual(err.description, expected)
    }
  }

  func testParseWithErrorMissingOperand() {
    expectFailure(result: parser.parseResult("4.0 +"),
                  expected: """
error: unexpected input
 --> input:1:5
1 | 4.0 +
  |     ^ expected end of input
""")
  }

  func testParseWithErrorOpenParenthesis() {
    expectFailure(result: parser.parseResult("(4.0 + 3.0"),
                  expected: """
error: multiple failures occurred

error: unexpected input
 --> input:1:11
1 | (4.0 + 3.0
  |           ^ expected ")"

error: unexpected input
 --> input:1:1
1 | (4.0 + 3.0
  | ^ expected "-"
  | ^ expected 1 element satisfying predicate
  | ^ expected double
""")
  }

  func testParseWithErrorExtraCloseParenthesis() {
    expectFailure(result: parser.parseResult("(4.0 + 3.0))"),
                  expected: """
error: unexpected input
 --> input:1:12
1 | (4.0 + 3.0))
  |            ^ expected end of input
""")
  }

  func testParseWithErrorMissingOperator() {
    expectFailure(result: parser.parseResult("4.0 3.0"),
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
    let result = evaluator.evalResult()
    switch result {
    case .success: XCTFail()
    case .failure(let error):
      XCTAssertEqual("\(error)", "Function 'undefined' not found")
    }
  }

  func testParseWithErrorReadme() {
    let evaluator = parser.parseResult("4 × sin(t × π")
    print(evaluator)
  }

  func testInfixOperationLoggingWorks() {
    let opParser: some TokenReducerParser = Parse {
      "$".map { { Token.reducer(lhs: $0, rhs: $1, op: (*), name: "$") } }
    }

    let tokenParser: some TokenParser = Parse {
      Double.parser().map { Token.constant(value: $0) }
    }

    var parser = InfixOperation(name: "testing", associativity: .left,
                                operator: opParser,
                                operand: tokenParser,
                                implied: nil,
                                logging: true)

    let input = "123$456"
    var value = try? parser.parse(input[...])
    XCTAssertNotNil(value)

    var logged = false
    InfixOperation.logSink = { msg in
      logged = true
      print(msg)
    }

    parser.logging = false
    value = try? parser.parse(input[...])
    XCTAssertFalse(logged)

    parser.logging = true
    value = try? parser.parse(input[...])
    XCTAssertTrue(logged)
  }
}
