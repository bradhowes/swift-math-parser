# swift-math-parser

Basic math expression parser built with [Point•Free's](https://www.pointfree.co/) 
[swift-parsing](https://github.com/pointfreeco/swift-parsing) package.

NOTE: currently, this uses a fork of that fixes a parsing bug involving floating-point literals that have a trailing
'e' or 'E' specifier.

```
let parser = MathParser()
let evaluator = parser.parse('4 * sin(t * π) + 2 * sin(t * π)')
let v1 = evaluator.eval("t", value: 0.0) // 0.0
let v2 = evaluator.eval("t", value: 0.5) // 6.0
let v3 = evaluator.eval("t", value: 1.0) // 0.0
```

The parser will return `nil` if it is unable to completely parse the expression.

By default, the expression parser and evaluator handle the following symbols and functions:

* Symbols: `pi`, `π`, and `e`
* Functions: `sin`, `cos`, `tan`, `log10`, `ln`/`loge`, `log2`, `exp`, `ceil`, `floor`, `round`, `sqrt`

You can reference additional symbols or variables and functions by providing your own mapping functions. There are two
places where this can be done:

* `MathParser.init`
* `MathParser.Evaluator.eval`

If a symbol or function does not exist during an `eval` call, the final result will be `NaN`. If a symbol is defined in
during parsing, it will be replaced with the symbol value. Otherwise, it will be resolved during a future `eval` call.
Same for function calls -- if the function is known during parsing _and_ the argument is a known value, then it will be
replaced with the function result. Otherwise, the function call will take place during an `eval` call.
