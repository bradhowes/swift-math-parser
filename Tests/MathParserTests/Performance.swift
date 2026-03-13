// Copyright © 2026 Brad Howes. All rights reserved.

import MathParser
import XCTest

final class PerformanceTests: XCTestCase {

  func testPerformance() {
    let mp = MathParser(enableImpliedMultiplication: true)
    let expression = TestWolfram().x
    self.measure {
      XCTAssertNotNil(mp.parse(expression))
    }
  }
}
