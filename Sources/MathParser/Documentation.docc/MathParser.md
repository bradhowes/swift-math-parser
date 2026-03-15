# ``MathParser``

Powerful math expression parser and evaluator built with Point•Free's swift-parsing package (v0.12.0).

## Overview

A ``MathParser`` instance parses text containing math expressions such as `1 + 2` and returns an ``Evaluator`` instance
that reports the immediate value (`3` in this case) just like in a calculator. However, it also allows for more
complicated expressions with variables and functions that allows you to perform evaluations of a parsed expression some
time in the future when you have values to give for the variables and functions that were not known at the time of
parsing.

For instance, ``MathParser`` supports expressions such as `x * 3` with an unknown variable `x`. This will parse just
fine, and the returned ``Evaluator`` can perform the multiplication when you hand it a value for the `x` placeholder.
You can also provide different assignments for `x` and the evaluator will quickly return new multiplications with those
assignments.

```swift
let parser = MathParser()
let evaluator = parser.parse("x * 3")
evaluator.eval("x", value: 0.0) // => 0.0
evaluator.eval("x", value: 42)  // => 126
```

This delayed evaluation also works for functions: you can parse an expression with 1 or 2 argument functions that are
not known to ``MathParser``. It will however perform any math operations that it can while holding off on evaluating
those that involve unknown symbols. Like the case with the unknown variables, you then provide an ``Evaluator`` with the
mapping of function names to function closures when you wish to finish a calculation and obtain a numeric result.

```swift
let parser = MathParser()
let evaluator = parser.parse("double(x)")
evaluator.eval(variables: {"x": 4}.producer, unaryFunctions: {"double": {$0 + $0}}.producer) // => 8.0
evaluator.eval(variables: {"x": 8}.producer, unaryFunctions: {"double": {$0 + $0}}.producer) // => 16.0
```

As one would expect, ``MathParser`` supports the standard math operators, subexpressions in parentheses, and even
advanced math operations such as sine, cosine, cube roots and more. The full list is given in the <doc:CustomSymbols>
section.
