// Copyright © 2022 Brad Howes. All rights reserved.

public extension Dictionary where Key == String, Value == Double {
  /// Obtain a symbol mapping function for the dictionary
  var producer: MathParser.SymbolMap { { self[$0] } }
}

public extension Dictionary where Key == String, Value == (Double) -> Double {
  /// Obtain a unary function mapping function for the dictionary
  var producer: MathParser.UnaryFunctionMap { { self[$0] } }
}

public extension Dictionary where Key == String, Value == (Double, Double) -> Double {
  /// Obtain a binary function mapping function for the dictionary
  var producer: MathParser.BinaryFunctionMap { { self[$0] } }
}
