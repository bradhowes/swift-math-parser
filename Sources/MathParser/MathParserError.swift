// Copyright © 2021 Brad Howes. All rights reserved.

import Foundation

/**
 Error type that describes a failure in either text parsing or token evaluation.
 */
public struct MathParserError: Error, CustomStringConvertible {

  public let description: String

  public init(description: String) {
    self.description = description
  }
}
