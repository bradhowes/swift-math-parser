// Copyright © 2021-2026 Brad Howes. All rights reserved.

import Foundation
import MathParser // NOTE: do not use @testable -- only public API should be tested here
import Parsing
import Testing

@Suite
struct MathParserTests {

  let parser = MathParser()

  @Test
  func testIdentifiersCanHoldEmojis() {
    #expect(sin(1.5) == parser.parse("sin(🌍)")?.eval("🌍", value: 1.5))
    #expect(1.5 + sin(1.5) == parser.parse("🌍🌍 + sin(🌍🌍)")?.eval("🌍🌍", value: 1.5))
    #expect(1.3 == parser.parse("💐power🤷‍♂️")?.eval("💐power🤷‍♂️", value: 1.3))
  }

  @Test
  func testSpacesAreSkippedAroundSymbols() {
    #expect(8.0 == parser.parse(" pow( 2 , 3 ) * 1")?.eval())
  }

  @Test
  func testSpacesAreNotRequiredAroundSymbols() {
    #expect(8.0 == parser.parse("pow(2,3)*1")?.eval())
  }

  @Test
  func testNoSpacesBetweenFunctionNamesAndParenthesis() {
    #expect(nil == parser.parse(" pow ( 2 , 3 ) "))
  }

  @Test
  func testIntegersAreProperlyParsedAsDoubles() {
    #expect(3 == parser.parse("3")?.eval())
    #expect(3 == parser.parse(" 3")?.eval())
    #expect(3 == parser.parse(" 3 ")?.eval())
  }

  @Test
  func testNegativeIntegersAreParsedAsDoubles() {
    #expect(-3 == parser.parse(" -3")?.eval())
    #expect(-3 == parser.parse("-3 ")?.eval())
    #expect(-3 == parser.parse(" -3 ")?.eval())
  }

  @Test
  func testNegationOperatorMustBeNextToNumber() {
    #expect(nil == parser.parse("- 3")?.eval())
  }

  @Test
  func testFloatingPointLiteralsAreParsedAsDoubles() {
    #expect(-3.45 == parser.parse("-3.45")?.eval())
    #expect(-3.45E2 == parser.parse("-3.45E2 ")?.eval())
    #expect(-3.45E-2 == parser.parse(" -3.45e-2 ")?.eval())
  }

  @Test
  func testNonArabicNumbersAreNotParsedAsNumbers() {
    // We don't support non-Arabic numbers -- below is Thai 3.
    #expect(nil == parser.parse("๓")?.eval())
  }

  @Test
  func testNegation() {
    #expect(-2 == parser.parse("-2")?.eval())
    #expect(nil == parser.parse("- 2")?.eval())

    #expect(nil == parser.parse("--2")?.eval())
    #expect(nil == parser.parse("- -2")?.eval())
    #expect(nil == parser.parse("--3-2")?.eval())

    #expect(2 == parser.parse("-(-2)")?.eval())
    #expect(5 == parser.parse("-(-3-2)")?.eval())
    #expect(pow(2, -(1 - 8)) == parser.parse("2^-(1-8)")?.eval())
    #expect(5.0 * -.pi == parser.parse("5 * -pi")?.eval())
    #expect(5.0 * -.pi * -3 == parser.parse("5 * -pi * -t")?.eval("t", value: 3))
  }

  @Test
  func testParserUsesCustomVariableMap() {
    let parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return nil
      }
    })
    #expect(6 == parser.parse("3*b")?.eval())
    #expect(1.5 == parser.parse("3÷b")?.eval())
  }

  @Test
  func testParserCustomVariableMapIgnoredByEval() {
    let parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return nil
      }
    })

    let z = parser.parse("b*pi")
    #expect(1 == z?.unresolved.variables.count)
    #expect(2.0 * .pi == z?.eval())
  }

  @Test
  func testParserUsesCustomUnaryFunctionMap() {
    let parser = MathParser(unaryFunctions: {name in
      switch name {
      case "foo": return {(value: Double) -> Double in value * 3}
      default: return nil
      }
    })
    #expect(sin(3.0 * .pi) == parser.parse("sin(foo(pi))")?.eval())
  }

  @Test
  func testParserUsesCustomBinaryFunctionMap() {
    let parser = MathParser(binaryFunctions: {name in
      switch name {
      case "bar": return {(x: Double, y: Double) -> Double in x * y}
      default: return nil
      }
    })
    #expect(.pi * .e == parser.parse("bar(pi, e)")?.eval())
  }

  @Test
  func testImpliedMultiplicationWithConstants() {
    let parser = MathParser(enableImpliedMultiplication: true)
    #expect(.pi == parser.parse("pi")?.eval())
    #expect(.pi == parser.parse("π")?.eval())
    #expect(.pi * .pi == parser.parse("ππ")?.eval())
    #expect(.e * .pi == parser.parse("e(pi)")?.eval())
    #expect(.e * .pi == parser.parse("epi")?.eval())
    #expect(.e * .pi == parser.parse("pie")?.eval())
  }

  @Test
  func testImpliedMultiplicationWithNumbers() {
    let parser = MathParser(enableImpliedMultiplication: true)
    #expect(2.0 * 3.0 == parser.parse("2 3")?.eval())
    #expect(2.0 + 3.0 == parser.parse("2 +3")?.eval())
    #expect(2.0 + 3.0 == parser.parse("2+3")?.eval())
    #expect(2.0 + 3.0 == parser.parse("2+ 3")?.eval())
    #expect(2.0 * -3.0 == parser.parse("2 -3")?.eval())
    #expect(2.0 * -3.0 == parser.parse("2-3")?.eval()) // !!!
    #expect(2.0 - 3.0 == parser.parse("2- 3")?.eval())
  }

  @Test
  func testImpliedMultiplicationWithNumberAndSymbol() {
    let parser = MathParser(enableImpliedMultiplication: true)
    #expect(2.0 * .pi == parser.parse("2pi")?.eval())
    #expect(2.0 * .pi == parser.parse("2(pi)")?.eval())
    #expect(2.0 * .pi == parser.parse("2.000pi")?.eval())
    #expect(2.0 * .pi == parser.parse("2 pi")?.eval())
    #expect(2.0 * .pi == parser.parse("pi 2")?.eval())
  }

  @Test
  func testImpliedMultiplicationOnUnaryFunctionResolution() {
    let parser = MathParser(enableImpliedMultiplication: true)
    var variables = ["a": 2.0, "b": 3.0, "c": 4.0]
    var unary = ["bc": { $0 * 10.0}]
    let token = parser.parse("abc(3)")
    #expect(1 == token?.unresolved.unaryFunctions.count)
    #expect(2.0 * 3.0 * 10 == token!.eval(variables: variables.producer, unaryFunctions: unary.producer))

    unary["abc"] = { $0 + 14 }
    #expect(17 == token!.eval(variables: variables.producer, unaryFunctions: unary.producer))

    variables["abc"] = 24
    #expect(17 == token!.eval(variables: variables.producer, unaryFunctions: unary.producer))

    #expect(72.0 == token!.eval(variables: variables.producer))
  }

  @Test
  func testAddition() {
    #expect(3 == parser.parse("1+2")?.eval())
    #expect(6 == parser.parse("1+2+3")?.eval())
    #expect(6 == parser.parse(" 1+ 2 + 3 ")?.eval())
    #expect(-1 == parser.parse("1+-2")?.eval())
    #expect(-1 == parser.parse("1+ -2")?.eval())
    #expect(-3 == parser.parse("-1+ -2")?.eval())
  }

  @Test
  func testSubtraction() {
    #expect(-1 == parser.parse("1 - 2")?.eval())
    #expect(-4 == parser.parse("1 - 2 - 3")?.eval())
    #expect(-4 == parser.parse(" 1 - 2 - 3 ")?.eval())
  }

  @Test
  func testAdditionAndSubtraction() {
    #expect(0 == parser.parse("1 + 2 - 3")?.eval())
    #expect(0 == parser.parse("1 + (2 - 3)")?.eval())
    #expect(0 == parser.parse("(1 + 2) - 3 ")?.eval())

    #expect(2 == parser.parse("1 - 2 + 3")?.eval())
    #expect(-4 == parser.parse("1 - (2 + 3)")?.eval())
    #expect(2 == parser.parse("(1 - 2) + 3 ")?.eval())
  }

  @Test
  func testExponentiationIsRightAssociative() {
    #expect(pow(5.0, pow(2, pow(3, 4))) == parser.parse("5^2^3^4")?.eval())
  }

  @Test
  func testOrderOfOperations() {
    #expect(1.0 + 2.0 * 3.0 / 4.0 - pow(5.0, pow(2, 3)) == parser.parse("1+2*3/4-5^2^3")?.eval())
  }

  @Test
  func testParenthesesAltersOrderOfOperations() {
    #expect((1.0 + 2.0 ) * 3.0 / 4.0 - pow(5.0, (6.0 + 7.0)) == parser.parse("(1+2)*3/4-5^(6+7)")?.eval())
    #expect(((8 + 9) * 3) == parser.parse("((8+9)*3) ")?.eval())
  }

  @Test
  func testEmptyParenthesesIsFailure() {
    #expect(nil == parser.parse(" () ")?.eval())
  }

  @Test
  func testParenthesesAroundConstantOrSymbolIsOk() {
    #expect(1 == parser.parse(" (1) ")?.eval())
    #expect(.pi == parser.parse(" (pi) ")?.eval())
  }

  @Test
  func testNestedParentheses() {
    #expect(1 == parser.parse("((((((1))))))")?.eval())
    #expect(((1.0 + 2.0) * (3.0 + 4.0)) / pow(5.0, 1.0 + 3.0) == parser.parse("((1+2)*(3+4))/5^(1+3)")?.eval())
  }

  @Test
  func testMissingClosingParenthesisFails() {
    #expect(nil == parser.parse("(1 + 2"))
  }

  @Test
  func testMissingOpeningParenthesisFails() {
    #expect(nil == parser.parse("1 + 2)"))
  }

  @Test
  func testDefaultSymbolsAreFound() {
    #expect(pow(1 + 2 * .pi, 2 * .e) == parser.parse("(1 + 2 * pi) ^ (2 * e)")?.eval())
  }

  @Test
  func testEvalWithUndefinedSymbolFails() {
    #expect(parser.parse("(1 + 2 * pip) ^ 2")!.eval().isNaN)
  }

  @Test
  func testDefaultUnaryFunctionsAreFound() {
    let sgn: (Double) -> Double = { $0 < 0 ? -1 : $0 > 0 ? 1 : 0 }
    #expect(tan(sin(cos(.pi/4.0))) == parser.parse("tan(sin(cos(pi/4)))")?.eval())
    #expect(log10(log(log(log2(exp(.pi))))) ==
                   parser.parse("log10(ln(loge(log2(exp(pi)))))")?.eval())
    #expect(ceil(floor(round(sqrt(sqrt(cbrt(abs(sgn(-3)))))))) ==
            parser.parse("ceil(floor(round(sqrt(√(cbrt(abs(sgn(-3))))))))")?.eval())
  }

  @Test
  func testSgnFunction() {
    #expect(-1 == parser.parse("sgn(-1.33433)")?.eval())
    #expect(1 == parser.parse("sgn(1.33433)")?.eval())
    #expect(0 == parser.parse("sgn(0.00000)")?.eval())
  }

  @Test
  func testFunction1NotFoundFails() {
    #expect(parser.parse(" sinc(2 * pi)")!.eval().isNaN)
  }

  @Test
  func testFunction2NotFoundFails() {
    #expect(parser.parse(" blah(2 * pi, 3.4)")!.eval().isNaN)
  }

  @Test
  func testImpliedMultiplicationIsDisableByDefault() {
    #expect(nil == parser.parse("2 pi"))
    #expect(nil == parser.parse("2pi"))
    #expect(nil == parser.parse("2 sin(pi / 2)"))
    #expect(nil == parser.parse("2 (1 + 2)"))
  }

  @Test
  func testImpliedMultiplicationWithBinaryArgumentFails() {
    #expect(nil == parser.parse("2(3, 4)"))
  }

  @Test
  func testImpliedMultiplicationExamples() {
    let parser = MathParser(enableImpliedMultiplication: true)
    #expect(2.0 * .pi * 3.0 == parser.parse("2 pi * 3")?.eval())
    #expect(.pi * 3.0 == parser.parse("π 3")?.eval())
    #expect(2.0 * .pi * 3.0 == parser.parse("2pi 3")?.eval())
    #expect(2.0 * sin(.pi / 2) == parser.parse("2 sin(pi / 2)")?.eval())
    #expect(2.0 * (1 + 2) == parser.parse("2(1 + 2)")?.eval())
    #expect(2.0 * .pi == parser.parse("2pi")?.eval())
    #expect(2.0 * 3 == parser.parse("(3)2")?.eval())
    #expect(nil == parser.parse("2(3, 4)"))
  }

  @Test
  func testEvalWithDelayedResolutionVariable() {
    let token = parser.parse("4 * sin(t * pi)")!
    #expect(0.0 == token.eval("t", value: 0.0))
    #expect(4.0 == token.eval("t", value: 0.5))
    #expect(isApproximatelyEqual(0.0, token.eval("t", value: 1.0)))
  }

  @Test
  func testEvalWithDelayedResolutionVariableAndUnknownSymbolFails() {
    let token = parser.parse("4 * sin(t * pi) + u")!
    #expect(token.eval("t", value: 0.0).isNaN)
  }

  @Test
  func testCustomEvalSymbolMap() {
    let token = parser.parse("4 * sin(t * pi)")!
    var variables = ["t": 0.0]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer)
    }

    #expect(isApproximatelyEqual(0.0, eval(at: 0.0)))
    #expect(isApproximatelyEqual(4.0, eval(at: 0.5)))
    #expect(isApproximatelyEqual(0.0, eval(at: 1.0)))
  }

  @Test
  func testCustomEvalSymbolMapDoesNotOverrideMathParserSymbolMap() {
    let proc: (Double) -> Double = { 4 * sin($0 * .pi) }
    let token = parser.parse("4 * sin(t * pi)")
    var variables = ["t": 0.0, "pi": 3.0]

    func eval(at t: Double) -> Double? {
      variables["t"] = t
      return token?.eval(variables: variables.producer)
    }

    #expect(proc(0.0) == eval(at: 0.0))
    #expect(proc(0.5) == eval(at: 0.5))
    #expect(proc(1.0) == eval(at: 1.0))
  }

  @Test
  func testCustomEvalUnaryFunctionMapDoesNotOverrideMathParserUnaryFunctionMap() {
    let functions: [String: (Double)->Double] = ["sin": cos]
    let proc: (Double) -> Double = { 4 * sin($0 * .pi) }
    let token = parser.parse("4 * sin(t * pi)")
    var variables = ["t": 0.0]

    func eval(at t: Double) -> Double? {
      variables["t"] = t
      return token?.eval(variables: variables.producer, unaryFunctions: functions.producer)
    }

    #expect(proc(0.0) == eval(at: 0.0))
    #expect(proc(0.5) == eval(at: 0.5))
    #expect(proc(1.0) == eval(at: 1.0))
  }

  @Test
  func testCustomEvalBinaryFunctionMap() {
    let token = parser.parse("4 * sin(foobar(t, 0.25) * pi)")
    let proc: (Double) -> Double = { 4 * sin(($0 + 0.25) * .pi) }
    var variables = ["t": 0.0]
    let functions: [String:(Double, Double)->Double] = ["foobar": {$0 + $1}]

    func eval(at t: Double) -> Double? {
      variables["t"] = t
      return token?.eval(variables: variables.producer, binaryFunctions: functions.producer)
    }

    #expect(proc(0.0) == eval(at: 0.0))
    #expect(proc(0.5) == eval(at: 0.5))
    #expect(proc(1.0) == eval(at: 1.0))
  }

  @Test
  func testUnresolvedVariableWithImpliedMultiplication1() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("tπ t")
    let proc: (Double) -> Double = { $0 * .pi * $0 }
    #expect(token!.eval().isNaN)
    #expect(proc(0.0) == token?.eval("t", value: 0.0))
    #expect(proc(0.5) == token?.eval("t", value: 0.5))
    #expect(proc(1.0) == token?.eval("t", value: 1.0))
  }

  @Test
  func testUnaryFunction() {
    let token = parser.parse("(foo(t * pi))")!
    #expect(token.eval().isNaN)
    // At this point pi has been resolved, leaving t and foo.
    #expect(isApproximatelyEqual(3.0 * .pi, token.eval(variables: {_ in 1.0}, unaryFunctions: {_ in {$0 * 3.0}})))
  }

  @Test
  func testBinaryFunction() {
    let token = parser.parse("( foo(t * pi , 2 * pi  ))")!
    #expect(token.eval().isNaN)
    // At this point pi has been resolved, leaving t and foo.
    #expect(
      isApproximatelyEqual(
        ((1.5 * .pi) + (2.0 * .pi)) * 3,
        token.eval(variables: {_ in 1.5}, binaryFunctions: {_ in {($0 + $1) * 3.0}})
      )
    )
  }

  @Test
  func testBuggyAddition() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("2+5")
    #expect(7 == token?.eval())
    let token2 = parser.parse("t+4")
    #expect(7 == token2?.eval("t", value: 3))
  }

  @Test
  func testEval() {
    let parser = MathParser(enableImpliedMultiplication: false)
    let token = parser.parse("t+4")
    #expect(7 == token?.eval("t", value: 3))
  }

  @Test
  func testBuggyImpliedMultiplication() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("6.0 / 2(1 + 2)")
    #expect(3*3 == token?.eval())
  }

  @Test
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

    let token = parser.parse("atan2(y, x)")!
    #expect(token.eval().isNaN)

    var s = State(x: 0.0, y: 0.0)
    let evaluator: () -> Double = { token.eval(variables: s.lookup) }
    #expect(evaluator() == 0.0)
    s.x = -1.0
    #expect(evaluator() == .pi)
    s.x = 1.0
    #expect(evaluator() == 0.0)
    s.x = 0.0
    s.y = -0.5
    #expect(evaluator() == -.pi / 2)
    s.y = 0.5
    #expect(evaluator() == .pi / 2)
    s.y = .nan
    #expect(evaluator().isNaN)
    s.x = 0.5
    s.y = 0.5
    #expect(isApproximatelyEqual(evaluator(), 0.7853981633974483))
  }

  @Test
  func testReadMeExample1() {
    let parser = MathParser()
    let evaluator = parser.parse("4 × sin(t × π) + 2 × sin(t × π)")
    var t = 0.0
    var v = evaluator!.eval("t", value: t)
    #expect(4 * sin(t * .pi) + 2 * sin(t * .pi) == v)
    t = 0.25
    v = evaluator!.eval("t", value: t)
    #expect(4 * sin(t * .pi) + 2 * sin(t * .pi) == v)
    t = 0.5
    v = evaluator!.eval("t", value: t)
    #expect(4 * sin(t * .pi) + 2 * sin(t * .pi) == v)
    v = evaluator!.eval("u", value: 1.0)
    #expect(v.isNaN)
  }

  @Test
  func testReadMeExample2() {
    let myVariables = ["foo": 123.4]
    let myFuncs: [String:(Double)->Double] = ["twice": {$0 + $0}]
    let parser = MathParser(variables: myVariables.producer, unaryFunctions: myFuncs.producer)
    let myEvalFuncs: [String:(Double)->Double] = ["power": {$0 * $0}]
    let evaluator = parser.parse("power(twice(foo))")
    #expect(evaluator?.eval(unaryFunctions: myEvalFuncs.producer) == pow(123.4 * 2, 2))
  }

  @Test
  func testImpliedNumberFunction() {
    let parser = MathParser(enableImpliedMultiplication: true)
    #expect(4 * cos(1.25 * .pi) == parser.parse("4 cos(1.25 π)")?.eval())
    #expect(4 * cos(1.25 * .pi) == parser.parse("4cos(1.25π)")?.eval())
  }

  @Test
  func testFaultyAdditionRegression() {
    let parser = MathParser(enableImpliedMultiplication: true)
    #expect(4.0 * .pi + 2.0 * .pi == parser.parse("4 * π + 2 * π")?.eval())
    #expect(4.0 * .pi + 2.0 * .pi == parser.parse("4 π + 2 π")?.eval())
    #expect(4.0 * .pi + 2.0 * .pi == parser.parse("4π + 2 π")?.eval())
    #expect(4.0 * .pi + 2.0 * .pi == parser.parse("4π+ 2 π")?.eval())
    #expect(4.0 * .pi + 2.0 * .pi == parser.parse("4π+2 π")?.eval())
    #expect(4.0 * .pi + 2.0 * .pi == parser.parse("4π+2π")?.eval())
  }

  @Test
  func testReadMeExample3() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let evaluator = parser.parse("4 sin(t π) + 2 * sin(t π)")
    let proc: (Double) -> Double = { 4 * sin($0 * .pi) + 2 * sin($0 * .pi) }
    for t in [0.0, 0.25, 0.5] {
      let v = evaluator!.eval("t", value: t)
      #expect(proc(t) == v)
    }
    let v = evaluator!.eval("u", value: 1.0)
    #expect(v.isNaN)
    #expect(try! evaluator!.evalResult("t", value: 0.25).get() == proc(0.25))

    guard case .failure(let error) = evaluator!.evalResult("u", value: 0.25),
          case MathParserError.variableNotFound(let name) = error,
          name == "t"
    else {
      Issue.record("Unexpected result or error")
      return
    }
  }

  @Test
  func testVariableDict() {
    let parser = MathParser(variableDict: ["a": 1.0, "b": 2.0])
    #expect(3.0 == parser.parse("a + b")?.value)
  }

  @Test
  func testVariableDictIgnoredIfVariablesAlsoPresent() {
    let varMap = ["a": 10.0, "b": 20.0]
    let parser = MathParser(variables: varMap.producer, variableDict: ["a": 1.0, "b": 2.0])
    #expect(30.0 == parser.parse("a + b")?.value)
  }

  @Test
  func testUnaryFunctionDict() {
    let parser = MathParser(unaryFunctionDict: ["a": { $0 * 100.0 }])
    #expect(123.0 == parser.parse("a(1.23)")?.value)
  }

  @Test
  func testUnaryFunctionDictIgnoredIfUnaryFunctionsAlsoPresent() {
    let unaryMap = ["a": { $0 * 1000.0}]
    let parser = MathParser(unaryFunctions: unaryMap.producer, unaryFunctionDict: ["a": { $0 * 2.0}])
    #expect(1230.0 == parser.parse("a(1.23)")?.value)
  }

  @Test
  func testBinaryFunctionDict() {
    let parser = MathParser(binaryFunctionDict: ["a": { $0 * $1 }])
    #expect(12.0 == parser.parse("a(3.0, 4.0)")?.value)
  }

  @Test
  func testBinaryFunctionDictIgnoredIfBinaryFunctionsAlsoPresent() {
    let binaryMap: [String: (Double, Double) -> Double] = ["a": { $0 + $1 }]
    let parser = MathParser(binaryFunctions: binaryMap.producer, binaryFunctionDict: ["a": { $0 * $1}])
    #expect(4.6 == parser.parse("a(1.2, 3.4)")?.value)
  }

  func expectFailure(result: Result<Evaluator, MathParserError>, expected: String) {
    switch result {
    case .success: Issue.record("Expected a failure case")
    case .failure(let err): #expect(err.description == expected)
    }
  }

  @Test
  func testParseWithErrorMissingOperand() {
    expectFailure(result: parser.parseResult("4.0 +"),
                  expected: """
error: unexpected input
 --> input:1:5
1 | 4.0 +
  |     ^ expected end of input
""")
  }

  @Test
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

  @Test
  func testParseWithErrorExtraCloseParenthesis() {
    expectFailure(result: parser.parseResult("(4.0 + 3.0))"),
                  expected: """
error: unexpected input
 --> input:1:12
1 | (4.0 + 3.0))
  |            ^ expected end of input
""")
  }

  @Test
  func testParseWithErrorMissingOperator() {
    expectFailure(result: parser.parseResult("4.0 3.0"),
                  expected: """
error: unexpected input
 --> input:1:5
1 | 4.0 3.0
  |     ^ expected end of input
""")
  }

  @Test
  func testEvalWithErrorFailsWithUnknownVariable() {
    let evaluator = parser.parse("undefined(1.2)")!
    #expect(evaluator.value.isNaN)
    let result = evaluator.evalResult()
    switch result {
    case .success: Issue.record("unexpected success")
    case .failure(let error):
      #expect("\(error)" == "Function 'undefined' not found")
    }
  }

  @Test
  func testParseWithErrorReadme() {
    let evaluator = parser.parseResult("4 × sin(t × π")
    print(evaluator)
  }

  @Test
  func testFactorial() {
    #expect(24.0 == parser.parse("4!")?.value)
    #expect(3 + 24.0 == parser.parse("3 + 4!")?.value)
    #expect(3 * 24.0 == parser.parse("3 * 4!")?.value)
    #expect(nil == parser.parse("3 * -4!"))
    #expect(24.0 == parser.parse("ceil(π)!")?.value)
    #expect(parser.parse("ceil(zeta)!")!.value.isNaN)
    #expect(pow(3, 24) == parser.parse("3^4!")?.value)
    #expect(2.43290200817664e+18 == parser.parse("20!")?.value)
    #expect(9.33262154439441e+157 == parser.parse("100!")?.value)
  }

  @Test
  func testExponentiation() {
    #expect(2.0 * pow(3, 4) + 5 == parser.parse("2 * 3 ^ 4 + 5")?.value)
    #expect(2.0 * pow(3, 4) * 5 == parser.parse("2 * 3 ^ 4 * 5")?.value)
    #expect(2.0 * pow(3, pow(4,  5)) == parser.parse("2 * 3 ^ 4 ^ 5")?.value)
  }

  @Test
  func testDegTrig() {
    var unaryFunctions = MathParser.defaultUnaryFunctions
    unaryFunctions["sin"] = { sin($0 * Double.pi / 180.0) }
    unaryFunctions["cos"] = { cos($0 * Double.pi / 180.0) }
    var binaryFunctions = MathParser.defaultBinaryFunctions
    binaryFunctions["atan2"] = { atan2($0, $1) * 180.0 / Double.pi }
    let parser = MathParser(unaryFunctionDict: unaryFunctions, binaryFunctionDict: binaryFunctions)
    #expect(sin(Double.pi / 6) == parser.parse("sin(30)")?.value)
    #expect(cos(Double.pi / 3) == parser.parse("cos(60)")?.value)
    #expect(atan2(1.0, 1.0) * 180.0 / Double.pi == parser.parse("atan2(1.0, 1.0)")?.value)
  }

  @Test
  func testMod() {
    #expect(2 == parser.parse("5 % 3")?.value)
    #expect(3 == parser.parse("8 + 5 % 3 - 7")?.value)
    #expect(.pi - 3.0 == parser.parse("pi % 3")?.value)
    #expect(2 * .pi - 6.0 == parser.parse("2 * pi % 3")?.value)
    #expect(2 == parser.parse("mod(5, 3)")?.value)
    #expect(3 == parser.parse("mod(3, 5)")?.value)
    #expect(1 == parser.parse("mod(55, 3)")?.value)
    #expect(0 == parser.parse("mod(35, 5)")?.value)

    #expect(-2 == parser.parse("mod(-5, 3)")?.value)
    #expect(-3 == parser.parse("mod(-3, 5)")?.value)
    #expect(-1 == parser.parse("mod(-55, 3)")?.value)
    #expect(0 == parser.parse("mod(-35, 5)")?.value)

    #expect(2 == parser.parse("mod(5, -3)")?.value)
    #expect(3 == parser.parse("mod(3, -5)")?.value)
    #expect(1 == parser.parse("mod(55, -3)")?.value)
    #expect(0 == parser.parse("mod(35, -5)")?.value)

    #expect(-2 == parser.parse("mod(-5, -3)")?.value)
    #expect(-3 == parser.parse("mod(-3, -5)")?.value)
    #expect(-1 == parser.parse("mod(-55, -3)")?.value)
    #expect(0 == parser.parse("mod(-35, -5)")?.value)
  }

  @Test
  func testTrigonometric() {
    for index in 0..<11 {
      let theta = Double(index - 5) / 10.0 * .pi
      #expect(isApproximatelyEqual(sin(theta), parser.parse("sin(\(theta))")?.value))
      #expect(isApproximatelyEqual(cos(theta), parser.parse("cos(\(theta))")?.value))
      #expect(isApproximatelyEqual(tan(theta), parser.parse("tan(\(theta))")?.value))

      #expect(isApproximatelyEqual(asin(sin(theta)), parser.parse("asin(sin(\(theta)))")?.value))
      #expect(isApproximatelyEqual(acos(cos(theta)), parser.parse("acos(cos(\(theta)))")?.value))
      #expect(isApproximatelyEqual(atan(tan(theta)), parser.parse("atan(tan(\(theta)))")?.value))

      #expect(1.0 / cos(theta) == parser.parse("sec(\(theta))")?.value)
      #expect(1.0 / sin(theta) == parser.parse("csc(\(theta))")?.value)
      #expect(1.0 / tan(theta) == parser.parse("cot(\(theta))")?.value)
    }
  }

  @Test
  func testHyperbolic() {
    #expect(parser.parse("sinh(0)") != nil)
    for index in 0..<11 {
      let theta = Double(index - 5) / 10.0
      #expect(isApproximatelyEqual(sinh(theta), parser.parse("sinh(\(theta))")?.value))
      #expect(isApproximatelyEqual(cosh(theta), parser.parse("cosh(\(theta))")?.value))
      #expect(isApproximatelyEqual(tanh(theta), parser.parse("tanh(\(theta))")?.value))
    }
  }
}

func isApproximatelyEqual(_ a: Double?, _ b: Double?, epsilon: Double = 1.0e-12) -> Bool {
  abs(a! - b!) < epsilon
}
