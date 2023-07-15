# Custom Symbols

The ``MathParser`` package tries to offer a great out-of-the-box experience without any configuration. It also offers
a way to integrate your own functionality by way of providing custom variables and functions which the parser and 
evaluator can then use to successfully resolve and evaluate your math expressions.

By default, ``MathParser`` provides two constants (`π` and `e`) and a large number of common functions by default for
all math expression parsing and evaluation.

The functions provided are those that are often used in math and programming:

- 1-argument functions: `sin`, `asin`, `cos`, `acos`, `tan`, `atan`, `log10`, `ln` (`loge`), `log2`, `exp`, `ceil`, 
`floor`, `round`, `sqrt` (`√`), `cbrt` (cube root), `abs`, `sgn`
- 2-argument functions: `atan`, `hypot`, `pow`

You can also provide additional definitions or redefine the defaults by providing your own mapping function for any or
all of the three collections (variables, 1-arg (unary) functions, and 2-arg (binary) functions).

## Customized Parsing

Below shows how to provide to the parser a custom unary function called `twice` that returns twice the value it 
receives, and a custom variable called `foo` which holds the constant `123.4`.

```swift
let myVariables = ["foo": 123.4]
let myFunctions: [String:(Double)->Double] = ["twice": {$0 + $0}]
let parser = MathParser(variables: myVariables.producer, unaryFunctions: myFunctions.producer)
let evaluator = parser.parse("power(twice(foo))")
```

In the above parsed expression `power(twice(foo))` everything is resolved except for `power`. Since the expression is a
valid one according to ``MathParser``, the returned `evaluator` is not `nil`, but asking the evaluator for a value now
will return a `NaN` because of the undefined `power` function.

```swift
evaluator?.value // => nan
```

In this example, we know that `power` must be a function because the parser was not created with implied multiplication 
enabled. If that had not been the case, then the unknown `power` symbol could also be a variable which once resolved 
would be multiplied with the result from `twice(foo)`.

## Customized Evaluation

We can also ask the `evaluator` for any unresolved symbols via its ``Evaluator/unresolved`` attribute:

```swift
evaluator?.unresolved.unaryFunctions // => ['power']'
```

Supply addition variable and methods to the evaluator's 
``Evaluator/eval(variables:unaryFunctions:binaryFunctions:)`` method. Below, we supply it with a definition for `power`.

```
let myEvalFuncs: [String:(Double)->Double] = ["power": {$0 * $0}]
evaluator?.eval(unaryFunctions: myEvalFuncs.producer) // => 60910.240000000005
```

Just like for the ``MathParser`` initialization method, instead of passing a closure to access the dictionary of 
symbols, you can pass the dictionary itself:

```
evaluator?.eval(unaryFunctionDict: myEvalFuncs) // => 60910.240000000005
```
