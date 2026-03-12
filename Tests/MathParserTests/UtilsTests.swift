// Copyright © 2021-2026 Brad Howes. All rights reserved.

import Testing
@testable import MathParser

@Suite
struct UtilsTests {

  let variables = ["a": 3.0, "b": 5.0, "ab": 7.0, "aba": 11.0]
  let unaries = ["OO": { $0 * 2.0 }, "FOO": { $0 * 3.0 }]
  var state: EvalState {
    EvalState(
      variables: self.variables.producer,
      unaryFunctions: self.unaries.producer,
      binaryFunctions: nil,
      usingImpliedMultiplication: true
    )
  }

  func eval(_ token: Token?) -> Double {
    (try? token?.eval(state: state)) ?? .nan
  }

  @Test
  func splitIdentifier_fails() {
    #expect(splitIdentifier("foo", state: state) == nil)
  }

  @Test
  func splitIdentifier_findsLargestMatch() {
    let result = splitIdentifier("abc", state: state)
    #expect(7.0 == eval(result!.token))
    #expect("c" == String(result!.remaining))
  }

  @Test
  func splitIdentifier_chains() {
    let result = splitIdentifier("abaabc", state: state)
    #expect(11.0 * 7 == eval(result!.token))
    #expect("c" == String(result!.remaining))
  }

  @Test
  func splitIdentifier_chainsAndFindsAll() {
    let result = splitIdentifier("abaab", state: state)
    #expect(11.0 * 7 == eval(result!.token))
    #expect("" == String(result!.remaining))
  }

  @Test
  func splitIdentifier_chainsLargestMatch() {
    let result = splitIdentifier("abaabac", state: state)
    #expect(11.0 * 11.0 == eval(result!.token))
    #expect("c" == String(result!.remaining))
  }

  @Test
  func splitIdentifier_chainsRepeatedly() {
    let result = splitIdentifier("abaababaaaac", state: state)
    let expected: Double = 11.0 * 11.0 * 5.0 * 3.0 * 3.0 * 3.0 * 3.0
    #expect(expected == eval(result!.token))
    #expect("c" == String(result!.remaining))
  }

  @Test
  func searchForUnaryIdentifier_failsWithNil() {
    let result = searchForUnaryIdentifier("blah", state: state)
    #expect(nil == result)
  }

  @Test
  func searchForUnaryIdentifier_findsMatch() {
    let result = searchForUnaryIdentifier("abcOO", state: state)
    #expect("OO" == result?.name)
    #expect(22 == result?.op(11.0))
  }

  @Test
  func searchForUnaryIdentifier_findsLongestMatch() {
    let result = searchForUnaryIdentifier("abcFOO", state: state)
    #expect("FOO" == result?.name)
    #expect(33 == result?.op(11.0))
  }

  @Test
  func splitUnaryIdentifier_fails() {
    let state = self.state
    #expect(nil == splitUnaryIdentifier("D", arg: .constant(value: 13.0), state: state))
    #expect(nil == splitUnaryIdentifier("FOOD", arg: .constant(value: 13.0), state: state))
    #expect(nil == splitUnaryIdentifier("OOD", arg: .constant(value: 13.0), state: state))
    #expect(nil == splitUnaryIdentifier("abcOO", arg: .constant(value: 13.0), state: state))
  }

  @Test
  func splitUnaryIdentifier_matches() {
    let state = self.state
    #expect(7 * 13 == eval(splitUnaryIdentifier("ab", arg: .constant(value: 13.0), state: state)))
    #expect(3 * 13 * 2 == eval(splitUnaryIdentifier("aOO", arg: .constant(value: 13.0), state: state)))
    #expect(3 * 13 * 3 == eval(splitUnaryIdentifier("aFOO", arg: .constant(value: 13.0), state: state)))
    #expect(7 * 13 * 3 == eval(splitUnaryIdentifier("abFOO", arg: .constant(value: 13.0), state: state)))
  }
}
