// Copyright © 2022-2026 Brad Howes. All rights reserved.

/**
 Evaluator of parsed tokens.

 An evaluator attempts to resolve any remaining symbols in order to return a value from a parsed expression. The
 ``eval(variables:variablesDict:unaryFunctions:unaryFunctionsDict:binaryFunctions:binaryFunctionsDict:)`` and
 ``evalResult(_:value:)`` methods accept additional definitions for variables and functions. If all are then
 resolved, then the evaluator can return a specific value from the parsed expression.
 */
public struct Evaluator {

  public typealias Result = Swift.Result<Double, MathParserError>

  /// The parsed token chain that can be evaluated
  @usableFromInline let token: Token

  /// True if using implied multiplication to resolve symbols
  @usableFromInline let usingImpliedMultiplication: Bool

  /// Obtain the names of any unresolved variable and/or function symbols. In order to receive a numeric value from the
  /// Evaulator, you must satisfy all unresolved symbols.
  public var unresolved: Unresolved { token.unresolved }

  /**
   Construct new evaluator. This is constructed and returned by `MathParser.parse`.

   - Parameter token: the token to evaluate
   - Parameter usingImpliedMultiplication: if true then try to decompose symbols into pairs that are multiplied together
   */
  init(token: Token, usingImpliedMultiplication: Bool = false) {
    self.token = token
    self.usingImpliedMultiplication = usingImpliedMultiplication
  }
}

extension Evaluator {

  /// Resolve a parsed expression to a value. If the expression has unresolved symbols this will return NaN.
  public var value: Double { return self.eval(variables: nil) }

  /**
   Evaluate the token to obtain a value.

   - Parameter variables: optional mapping of names to variables. If not give, `defaultVariables` will be use.
   - Parameter variablesDict: optional dictionary that maps a name to a constant. Note that this will be ignored if
   `variables` is also given.
   - Parameter unaryFunctions: optional mapping of names to 1-ary functions. If not given, `defaultUnaryFunctions` will
   be used.
   - Parameter unaryFunctionsDict: optional dictionary that maps a name 1-ary function. Note that this will be ignored if
   `unaryFunctions` is also given.
   - Parameter binaryFunctions: optional mapping of names to 2-ary functions. If not given, `defaultBinaryFunctions`
   will be used/
   - Parameter binaryFunctionsDict: optional dictionary that maps a name to a 2-ary function. Note that this will be ignored if
   `binaryFunctions` is also given.
   - Returns: Double value that is NaN when evaluation cannot finish due to unresolved symbol
   */
  @inlinable
  public func eval(
    variables: MathParser.VariableMap? = nil,
    variablesDict: MathParser.VariableDict? = nil,
    unaryFunctions: MathParser.UnaryFunctionMap? = nil,
    unaryFunctionsDict: MathParser.UnaryFunctionDict? = nil,
    binaryFunctions: MathParser.BinaryFunctionMap? = nil,
    binaryFunctionsDict: MathParser.BinaryFunctionDict? = nil
  ) -> Double {
    (try? token.eval(
      state: .init(
        variables: variables ?? variablesDict?.producer ?? MathParser.defaultVariables.producer,
        unaryFunctions: unaryFunctions ?? unaryFunctionsDict?.producer ?? MathParser.defaultUnaryFunctions.producer,
        binaryFunctions: binaryFunctions ?? binaryFunctionsDict?.producer ?? MathParser.defaultBinaryFunctions.producer,
        usingImpliedMultiplication: usingImpliedMultiplication
      )
    )) ?? .nan
  }

  /**
   Evaluate the token to obtain a ``Result`` value that indicates a success or failure. The `.success` case holds a
   valid `Double` value, while the `.failure` case holds a string describing the failure.

   - Parameter variables: optional mapping of names to variables. If not give, `defaultVariables` will be use.
   - Parameter variablesDict: optional dictionary that maps a name to a constant. Note that this will be ignored if
   `variables` is also given.
   - Parameter unaryFunctions: optional mapping of names to 1-ary functions. If not given, `defaultUnaryFunctions` will
   be used.
   - Parameter unaryFunctionsDict: optional dictionary that maps a name 1-ary function. Note that this will be ignored if
   `unaryFunctions` is also given.
   - Parameter binaryFunctions: optional mapping of names to 2-ary functions. If not given, `defaultBinaryFunctions`
   will be used/
   - Parameter binaryFunctionsDict: optional dictionary that maps a name to a 2-ary function. Note that this will be ignored if
   `binaryFunctions` is also given.
   - Returns: ``Result`` enum which hold value on success or error description on failure.
   */
  @inlinable
  public func evalResult(
    variables: MathParser.VariableMap? = nil,
    variablesDict: MathParser.VariableDict? = nil,
    unaryFunctions: MathParser.UnaryFunctionMap? = nil,
    unaryFunctionsDict: MathParser.UnaryFunctionDict? = nil,
    binaryFunctions: MathParser.BinaryFunctionMap? = nil,
    binaryFunctionsDict: MathParser.BinaryFunctionDict? = nil
  ) -> Result {
    do {
      let result = try token.eval(
        state: .init(
          variables: variables ?? variablesDict?.producer ?? MathParser.defaultVariables.producer,
          unaryFunctions: unaryFunctions ?? unaryFunctionsDict?.producer ?? MathParser.defaultUnaryFunctions.producer,
          binaryFunctions: binaryFunctions ?? binaryFunctionsDict?.producer ?? MathParser.defaultBinaryFunctions.producer,
          usingImpliedMultiplication: usingImpliedMultiplication
        )
      )
      return .success(result)
    } catch {
      // swiftlint:disable force_cast
      return .failure(error as! MathParserError)
      // swiftlint:enable force_cast
    }
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   - Parameter name: the name of a symbol to resolve.
   - Parameter value: the value to use for the symbol.
   - Returns: value of expression or `NaN` if there was an error.
   */
  @inlinable
  public func eval(_ name: String, value: Double) -> Double {
    eval(variables: {$0 == name ? value : nil})
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   - Parameter name: the name of a symbol to resolve.
   - Parameter value: the value to use for the symbol.
   - Returns: `Result` enum which hold value on success or error description on failure.
   */
  @inlinable
  public func evalResult(_ name: String, value: Double) -> Result {
    evalResult(variables: {$0 == name ? value : nil})
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   NOTE: this is not wise to do if `usingImpliedMultiplication` is `true` as it might not be possible to identify the name of the
   symbol to supply. For instance, in an expression like 'pi \* t' that is written 'tpi' or 'pit', is hard to resolve to 't' for
   the symbol name to use. Better to explicitly define the symbol using `eval("t", value: value)`.

   - Parameter value: the value to use for the symbol.
   - Returns: value of expression or `NaN` if there was an error.
   */
  @inlinable
  public func eval(_ value: Double) -> Double {
    guard !usingImpliedMultiplication else { return .nan }
    let names = token.unresolved.variables.map { $0 }.sorted()
    return eval(variables: {$0 == names.first ? value: nil})
  }

  /**
   Convenience method to evaluate an expression with one unknown symbol.

   NOTE: this is not wise to do if `usingImpliedMultiplication` is `true` as it might not be possible to identify the name of the
   symbol to supply. For instance, in an expression 'tt' is that one symbol 'tt' or a multiplication of 't' with itself?
   Better to explicitly define the symbol using `eval("t", value: value)` which would treat 'tt' as 't \* t', or
   `eval("tt", value: value)` to get back `value`.

   - Parameter value: the value to use for the symbol.
   - Returns: `Result` enum which hold value on success or error description on failure.
   */
  @inlinable
  public func evalResult(_ value: Double) -> Result {
    guard !usingImpliedMultiplication else { return .failure(.unsupportedEvalUnderImpliedMultiplication) }
    let names = token.unresolved.variables.map { $0 }.sorted()
    return evalResult(variables: {$0 == names.first ? value : nil})
  }
}
