// Copyright © 2023 Brad Howes. All rights reserved.

import XCTest
@testable import MathParser

final class UtilsTests: XCTestCase {

  let variables = ["a": 3.0, "b": 5.0, "ab": 7.0, "aba": 11.0]
  let unaries = ["OO": { $0 * 2.0 }, "FOO": { $0 * 3.0 }]
  lazy var state = EvalState(variables: self.variables.producer, unaryFunctions: self.unaries.producer,
                             binaryFunctions: nil, usingImpliedMultiplication: true)

  override func setUp() {}

  func eval(_ token: Token?) -> Double {
    (try? token?.eval(state: state)) ?? .nan
  }

  func test_splitIdentifier_fails() {
    XCTAssertNil(splitIdentifier("foo", state: state))
  }

  func test_splitIdentifier_findsLargestMatch() {
    let result = splitIdentifier("abc", state: state)
    XCTAssertEqual(7.0, eval(result!.token))
    XCTAssertEqual("c", String(result!.remaining))
  }

  func test_splitIdentifier_chains() {
    let result = splitIdentifier("abaabc", state: state)
    XCTAssertEqual(11.0 * 7, eval(result!.token))
    XCTAssertEqual("c", String(result!.remaining))
  }

  func test_splitIdentifier_chainsAndFindsAll() {
    let result = splitIdentifier("abaab", state: state)
    XCTAssertEqual(11.0 * 7, eval(result!.token))
    XCTAssertEqual("", String(result!.remaining))
  }

  func test_splitIdentifier_chainsLargestMatch() {
    let result = splitIdentifier("abaabac", state: state)
    XCTAssertEqual(11 * 11, eval(result!.token))
    XCTAssertEqual("c", String(result!.remaining))
  }

  func test_splitIdentifier_chainsRepeatedly() {
    let result = splitIdentifier("abaababaaaac", state: state)
    XCTAssertEqual(11 * 11 * 5 * 3 * 3 * 3 * 3, eval(result!.token))
    XCTAssertEqual("c", String(result!.remaining))
  }

  func test_searchForUnaryIdentifier_failsWithNil() {
    let result = searchForUnaryIdentifier("blah", state: state)
    XCTAssertNil(result)
  }

  func test_searchForUnaryIdentifier_findsMatch() {
    let result = searchForUnaryIdentifier("abcOO", state: state)
    XCTAssertEqual("OO", result?.name)
    XCTAssertEqual(22, result?.op(11.0))
  }

  func test_searchForUnaryIdentifier_findsLongestMatch() {
    let result = searchForUnaryIdentifier("abcFOO", state: state)
    XCTAssertEqual("FOO", result?.name)
    XCTAssertEqual(33, result?.op(11.0))
  }

  func test_splitUnaryIdentifier_fails() {
    XCTAssertNil(splitUnaryIdentifier("D", arg: .constant(value: 13.0), state: state))
    XCTAssertNil(splitUnaryIdentifier("FOOD", arg: .constant(value: 13.0), state: state))
    XCTAssertNil(splitUnaryIdentifier("OOD", arg: .constant(value: 13.0), state: state))
    XCTAssertNil(splitUnaryIdentifier("abcOO", arg: .constant(value: 13.0), state: state))
  }

  func test_splitUnaryIdentifier_matches() {
    XCTAssertEqual(7 * 13, eval(splitUnaryIdentifier("ab", arg: .constant(value: 13.0), state: state)))
    XCTAssertEqual(3 * 13 * 2, eval(splitUnaryIdentifier("aOO", arg: .constant(value: 13.0), state: state)))
    XCTAssertEqual(3 * 13 * 3, eval(splitUnaryIdentifier("aFOO", arg: .constant(value: 13.0), state: state)))
    XCTAssertEqual(7 * 13 * 3, eval(splitUnaryIdentifier("abFOO", arg: .constant(value: 13.0), state: state)))
  }
}
