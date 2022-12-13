// Copyright © 2021 Brad Howes. All rights reserved.

import XCTest
@testable import MathParser

final class TokenTests: XCTestCase {

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
  }
}
