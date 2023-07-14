// Copyright © 2023 Brad Howes. All rights reserved.

import XCTest
@testable import MathParser

final class UtilsTests: XCTestCase {

  let variables = ["a": 3.0, "b": 5.0, "ab": 7.0, "aba": 11.0]
  let unaries = ["OO": { $0 * 2.0 }, "FOO": { $0 * 3.0 }]

  override func setUp() {}

  func eval(_ token: Token) -> Double {
    (try? token.eval(state: .init(variables: self.variables.producer,
                                  unaryFunctions: self.unaries.producer,
                                  binaryFunctions: { _ in nil },
                                  usingImpliedMultiplication: true))) ?? .nan
  }

  func test_splitIdentifier_fails() {
    XCTAssertNil(splitIdentifier("foo"[...], variables: variables.producer))
  }

  func test_splitIdentifier_findsLargestMatch() {
    let result = splitIdentifier("abc"[...], variables: variables.producer)
    XCTAssertEqual(7.0, eval(result!.token))
    XCTAssertEqual("c", String(result!.remaining))
  }

  func test_splitIdentifier_chains() {
    let result = splitIdentifier("abaabc"[...], variables: variables.producer)
    XCTAssertEqual(11.0 * 7, eval(result!.token))
    XCTAssertEqual("c", String(result!.remaining))
  }

  func test_splitIdentifier_chainsAndFindsAll() {
    let result = splitIdentifier("abaab"[...], variables: variables.producer)
    XCTAssertEqual(11.0 * 7, eval(result!.token))
    XCTAssertEqual("", String(result!.remaining))
  }

  func test_splitIdentifier_chainsLargestMatch() {
    let result = splitIdentifier("abaabac"[...], variables: variables.producer)
    XCTAssertEqual(11 * 11, eval(result!.token))
    XCTAssertEqual("c", String(result!.remaining))
  }

  func test_splitIdentifier_chainsRepeatedly() {
    let result = splitIdentifier("abaababaaaac"[...], variables: variables.producer)
    XCTAssertEqual(11 * 11 * 5 * 3 * 3 * 3 * 3, eval(result!.token))
    XCTAssertEqual("c", String(result!.remaining))
  }

  func test_searchForUnaryIdentifier_failsWithNil() {
    let result = searchForUnaryIdentifier("blah", unaries: self.unaries.producer)
    XCTAssertNil(result)
  }

  func test_searchForUnaryIdentifier_findsMatch() {
    let result = searchForUnaryIdentifier("abcOO", unaries: self.unaries.producer)
    XCTAssertEqual("OO", result?.name)
    XCTAssertEqual(22, result?.op(11.0))
  }

  func test_searchForUnaryIdentifier_findsLongestMatch() {
    let result = searchForUnaryIdentifier("abcFOO", unaries: self.unaries.producer)
    XCTAssertEqual("FOO", result?.name)
    XCTAssertEqual(33, result?.op(11.0))
  }

  func test_splitUnaryIdentifier_fails() {
    XCTAssertNil(splitUnaryIdentifier("D", arg: .constant(value: 13.0),
                                      unaries: self.unaries.producer,
                                      variables: self.variables.producer))
    XCTAssertNil(splitUnaryIdentifier("FOOD", arg: .constant(value: 13.0),
                                      unaries: self.unaries.producer,
                                      variables: self.variables.producer))
    XCTAssertNil(splitUnaryIdentifier("OOD", arg: .constant(value: 13.0),
                                      unaries: self.unaries.producer,
                                      variables: self.variables.producer))
    XCTAssertNil(splitUnaryIdentifier("abcOO", arg: .constant(value: 13.0),
                                      unaries: self.unaries.producer,
                                      variables: self.variables.producer))
  }

  func test_splitUnaryIdentifier_matches() {
    XCTAssertEqual(7 * 13, eval(splitUnaryIdentifier("ab", arg: .constant(value: 13.0),
                                                     unaries: self.unaries.producer,
                                                     variables: self.variables.producer)!))
    XCTAssertEqual(3 * 13 * 2, eval(splitUnaryIdentifier("aOO", arg: .constant(value: 13.0),
                                                     unaries: self.unaries.producer,
                                                     variables: self.variables.producer)!))
    XCTAssertEqual(3 * 13 * 3, eval(splitUnaryIdentifier("aFOO", arg: .constant(value: 13.0),
                                                         unaries: self.unaries.producer,
                                                         variables: self.variables.producer)!))
    XCTAssertEqual(7 * 13 * 3, eval(splitUnaryIdentifier("abFOO", arg: .constant(value: 13.0),
                                                         unaries: self.unaries.producer,
                                                         variables: self.variables.producer)!))
  }
}
