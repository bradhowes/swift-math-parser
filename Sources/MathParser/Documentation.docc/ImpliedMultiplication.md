# Implied Multiplication

Math expression are often written without explicitly indicating when multiplication takes place, and instead rely on
convention.

Often instead of writing `2 * (3 + 4)` one usually writes `2(3 + 4)` with the understanding that `2` is being
multiplied to the value of `3 + 4`. Likewise, it is not uncommon to see numeric values before a function or a constant 
such as `π`, so instead of `3 * sin(0.5 * π)` we might see `3sin(0.5π)` or perhaps `3 sin(0.5 π)` to make it a little 
easier to read.

``MathParser`` supports parsing of math expressions where a multiplication symbol might not be present between two
terms. It is disabled by default, but the 
``MathParser/init(variables:variableDict:unaryFunctions:unaryFunctionDict:binaryFunctions:binaryFunctionDict:enableImpliedMultiplication:)``
initializer allows it to be enabled via the `enableImpliedMultiplication` parameter.

## Space Oddities

Be aware that with implied multiplication enabled, you could encounter strange parsing if you do not use spaces between
the "-" operator:

* `2-3` => -6
* `2 -3` -> -6
* `2 - 3` => -1

However, for "+" all is well:

* `2+3` => 5
* `2 +3` -> 5
* `2 + 3` => 5

Unfortunately, there is no way to handle this ambiguity between implied multiplication, subtraction and negation when 
spaces are not used to signify intent. 

## Symbol Splitting

When implied multiplication mode is active and the name of a variable or a 1-parameter (unary) function is not found in
their corresponding map, the token evaluation routine will attempt to resolve them by splitting the names into two or
more pieces that all resolve to known variables and/or functions. For example, using the default variable map and 
unary function map from `MathParser`:

* `pie` => `pi * e`
* `esin(2π)` => `e * sin(2 * pi)`
* `eeesgn(-1)` => `e * e * e * -1`

As you can imagine, this could lead to erroneous resolution of variable names and functions, but this behavior is only 
used when the initial lookup of the name fails, and it is never performed when the symbol names are separated by a 
space. However, if you make a mistake and forget to provide the definition of a custom variable or function, this
special processing could provide a value instead of an error. For instance, consider evaluating `tabs(-3)` where `t` is 
a custom variable set to `1.2` and `tabs` is a custom function but it is not provided for in the custom unary function 
map:

* `tabs(-3)` => `1.2 * abs(-3)` => `3.6`

If implied multiplication had not been active, the evaluator would have correctly reported an issue -- either returning
NaN or a `Result.failure` describing the missing function.
