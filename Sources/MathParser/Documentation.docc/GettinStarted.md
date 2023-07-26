# Getting Started

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

* Standard math operations: addition (`+`), subtraction (`-`), multiplication (`*`), division (`/`), 
and exponentiation (`^`)
* The factorial of a number (`!`)
* Constants: `pi` (`π`) and `e`
* 1-argument functions: `sin`, `asin`, `cos`, `acos`, `tan`, `atan`, `log10`, `ln` (`loge`), `log2`, `exp`, `ceil`, 
`floor`, `round`, `sqrt` (`√`), `cbrt` (cube root), `abs`, `sgn`, `!` (factorial)
* 2-argument functions: `atan`, `hypot`, `pow`
* alternative math operator symbols: `×` for multiplication and `÷` for division (see example above for use of `×`)

Note that the factorial operator and function (`!`) only give exact values up to `20!`. They treat all values as 
if truncated to an integer before performing the multiplications. Thus, `12.3!` is only `12!`.

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
