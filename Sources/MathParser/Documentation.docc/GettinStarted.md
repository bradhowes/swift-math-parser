# Overview

Basic math expression parser built with Point•Free's swift-parsing package (v0.12.0). 

## Usage Example

```swift
let parser = MathParser()
let evaluator = parser.parse("4 × sin(t × π) + 2 × sin(t × π)")
evaluator.eval("t", value: 0.0) // => 0.0
evaluator.eval("t", value: 0.25) // => 4.2426406871192848
evaluator.eval("t", value: 0.5) // => 6
evaluator.eval("t", value: 1.0) // => 0
```

The parser will return `nil` if it is unable to completely parse the expression. Alternatively, you can call 
``MathParser/parseResult(_:)`` to obtain a Swift `Result` enum that will have a ``MathParserError`` value when
parsing fails. This will contain a description of the parsing failure that comes from the swift-parsing library.

```swift
let evaluator = parser.parseResult("4 × sin(t × π")
print(evaluator)
failure(error: unexpected input
--> input:1:8
1 | 4 × sin(t × π
|        ^ expected end of input)

```

By default, the expression parser and evaluator handle the following symbols and functions:

* Constants: `pi` (`π`) and `e`
* 1-argument functions: `sin`, `asin`, `cos`, `acos`, `tan`, `atan`, `log10`, `ln` (`loge`), `log2`, `exp`, `ceil`, 
`floor`, `round`, `sqrt` (`√`), `cbrt` (cube root), `abs`, `sgn`
* 2-argument functions: `atan`, `hypot`, `pow` [^1]
* alternative math operator symbols: `×` for multiplication and `÷` for division (see example above for use of `×`)

You can reference additional symbols or variables and functions by providing your own mapping functions. There are two
places where this can be done:

* ``MathParser/init(variables:variableDict:unaryFunctions:unaryFunctionDict:binaryFunctions:binaryFunctionDict:enableImpliedMultiplication:)``
* ``Evaluator/eval(variables:unaryFunctions:binaryFunctions:)``

If a symbol or function does not exist during an `eval` call, the final result will be `NaN`. If a symbol is resolved
during parsing, it will be replaced with the symbol's value, and likewise for any math expressions and function calls
that can be resolved to constant values during the parse. Otherwise, the symbols will be resolved during a future 
`eval` call. 

You can get the unresolved symbol names from the ``Evaluator/unresolved`` attribute. It returns three collections for
unresolved variables, unary functions, and binary function names.

## Custom Symbols

Below is an example that provides a custom unary function that returns the twice the value it receives. There is also a
custom variable called `foo` which holds the constant `123.4`.

```swift
let myVariables = ["foo": 123.4]
let myFuncs: [String:(Double)->Double] = ["twice": {$0 + $0}]
let parser = MathParser(variables: myVariables.producer, unaryFunctions: myFuncs.producer)
let evaluator = parser.parse("power(twice(foo))")

# Expression parsed and `twice(foo)` resolved to `246.8` but `power` is still unknown
evaluator?.value // => nan
evaluator?.unresolved.unaryFunctions // => ['power']'
# Give evaluator way to resolve `power(246.8)`
let myEvalFuncs: [String:(Double)->Double] = ["power": {$0 * $0}]
evaluator?.eval(unaryFunctions: myEvalFuncs.producer) // => 60910.240000000005
```

Instead of passing a closure to access the dictionary of symbols, you can pass the dictionary itself:

```
let parser = MathParser(variableDict: myVariables, unaryFunctionDict: myFuncs)
evaluator?.eval(unaryFunctionDict: myEvalFuncs) // => 60910.240000000005
```

[^1]: Redundant since there is already the `^` operator.

