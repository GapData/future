Copyright Henrik Bengtsson, 2015

## Introduction
In programming, a _future_ is an abstraction for a _value_ that may be available at some point in the future.  The state of a future can either be _unresolved_ or _resolved_.  As soon as it is resolved, the value is available instantaneously.  If the value is queried while the future is still unresolved, the current process is _blocked_ until the future is resolved.  Exactly how and when futures are resolved, depends on what strategy is used to evaluate them.  For instance, a future can resolved using a "lazy" strategy, which means it is resolved only when the value is requested, if at all.  Another approach is an "eager" strategy, which means that it is starts to resolve the future as soon as it is created.  Alternative strategies is to resolve futures asynchroneously, for instance, by evaluating expressions concurrently on a compute cluster.

### Futures in R

The purpose of the 'future' package is to define and provide a minimalistic Future API for R.  The package itself only provides mechanisms for evaluating expressions _synchroneously_ via "lazy" and "eager" futures.  More advanced strategies can be implemented by other packages extending the 'future' package.  For instance, the '[async]' package resolves futures _asynchroneously_ via any of the backends that the '[BatchJobs]' framework provides, e.g. processing using multiple cores on a single machine, on a compute cluster via a job queue and so on.  The lazy and the eager futures provided by this package exist mainly for the purpose of illustrating how futures work and for troubleshooting code that uses other types of futures but for some reason fails when being resolved.

Here is an example illustrating how to create a future:

```r
> library(future)
> f <- future({
+   message("Resolving...")
+   3.14
+ })
Resolving...
> v <- value(f)
> v
[1] 3.14
```
Note how the future is resolved as soon as we create it using `future()`.  This is because the default strategy for resolving futures in the 'future' package is to evaluate them in an "eager" and synchroneous manner, which emulates R itself in _when_ it evaluates expressions.

We can switch to using a "lazy" evaluation strategy using the `plan()` function, e.g.

```r
> plan(lazy)
> f <- future({
+   message("Resolving...")
+   3.14
+ })
> v <- value(f)
> v
Resolving...
[1] 3.14
```

In this case the future is unresolved until the point where we ask for its value (which also means that a lazy future may never be resolved).


### Futures and promises
An important part of a future is the fact that although we do not necessarily control _when_ a future is resolved, it makes a "promise" that its value will be resolved if requested.  In other words, if we ask for the value of a future, we are guaranteed that its expression will be evaluated and a value will be returned (or an error will be generated if the evaluation caused an error).  An alternative to a `future-value` pair of function calls is to use the `%<=%` infix operator (also provided by the 'future' package).  For example,

```r
> plan(lazy)
> v %<=% {
+   message("Resolving...")
+   3.14
+ }
> v
Resolving...
[1] 3.14
```

This works by (i) creating a future and (ii) assigning its value to variable `v` as a _promise_.   Promises are constructs that are built-in in R (see `help(delayedAssign)`).  Specifically, the expression/value assigned to variable `v` is promised to be evaluated/resolved (no later than) when it is requested.



### The built-in "eager" and "lazy" futures
The 'future' package provides two evaluation strategies for futures, namely "lazy" and "eager", implemented by functions `lazy()` and `eager()`.  Other strategies such as asynchroneous evaluation on a computer cluster are implemented by other R packages, e.g. '[async]'. Since an asynchroneous strategy are more likely to be used in practice, the built-in eager and lazy mechanisms try to emulate those as far as possible while still evaluating them in a _synchroneous_ way.

For instance, the default is that the future expression is evaluated in _a local environment_ (cf. `help("local")`), which means that any assignments are done to local variable such that the environment of the main/calling process is unaffected.  Here is an example:

```r
> a <- 2.71
> x %<=% { a <- 3.14 }
> x
[1] 3.14
> a
[1] 2.71
```
This shows that `a` in the global environment is unaffected by the expression evaluated by the future.  For anyone interested, it is possible to evaluate both lazy and eager futures in the calling environment.  For instance,
```r
> plan(lazy, local=FALSE)
> a <- 2.71
> x %<=% { a <- 3.14 }
> a
[1] 2.71
> x
[1] 3.14
> a
[1] 3.14
```

### Different evaluation strategies for different futures
Sometimes one wish to use a different evaluation strategy for a specific future.  Although one can use `old <- plan(new)` and and then `plan(old)` to temporarily switch strategy, a simpler approach is to use the `%plan%` operator, e.g.
```r
> plan(eager) # The default
> a <- 0
> x %<=% { 3.14 }
> y %<=% { a <- 2.71 } %plan% lazy(local=FALSE)
> x
[1] 3.14
> a
[1] 0
> y
[1] 2.71
> a
[1] 2.71
```
Above `x` is evaluated eagerly (in a local environment), whereas `y` is evaluated lazily in the calling environment.


### Nested futures
It is possible to nest futures in multiple levels and each of the nested future may be resolved using a different strategy, e.g.
```r
> plan(lazy)
> c %<=% {
+   message("Resolving 'c'")
+   a %<=% { 
+     message("Resolving 'a'")
+   } %plan% eager
+   b %<=% {
+     message("Resolving 'b'")
+     -9 * a 
+   }
+   message("Local variable 'x'")
+   x <- b / 3
+   abs(x)
+ }
> d <- 42
> d
[1] 42
>
> c
Resolving 'c'
Local variable 'x'
Resolving 'b'
Resolving 'a'
[1] 6
```

## Assigning futures to environments and list environments
The `%<=%` assignment operator _cannot_ be used in all cases where regular `<-` assignment operator can be used.  For instance, it is not possible to assign future values to a _list_, e.g.

```r
> x <- list()
> x$a %<=% { 2.71 }
Error: Subsetting can not be done on a 'list'; only to an environment: 'x$a'
```

This is because _promises_ themselves cannot be assigned to lists.  More precisely, the limitation of future assignments are the same as those for assignments via the `assign()` function, which means you can only assign _future values_ to environment (defaulting to the current environment) but nothing else, i.e. not to elements of a vector, matrix, list or a data.frame and so on.  To assign a future value to an environment, do:

```r
> env <- new.env()
> env$a %<=% { 1 }
> env[["b"]] %<=% { 2 }
> name <- "c"
> env[[name]] %<=% { 3 }
> as.list(env)
$a
[1] 1

$b
[1] 2

$c
[1] 3
```

If _indexed subsetting_ is needed for assignments, the '[listenv]' package provides _"list environments"_, which technically are environments, but at the same time emulates how lists can be indexed.  For example,
```r
> library(listenv)
> x <- listenv()
> for (ii in 1:3) {
+   x[[ii]] %<=% { rnorm(ii) }
+ }
> names(x) <- c("a", "b", "c")
```
The future values of a list environment can be retrieved individually as `x[["b"]]` and `x$b` just as with regular environments, but also as `x[[2]]`, e.g.
```r
> x[[2]]
[1] -0.6735019  0.9873067
> x$b
[1] -0.6735019  0.9873067
```
Just as for any type of environment, all the value of a list environment can be retrieved as a list using `as.list(x)`.  Remember though that future assignments are used, which means that until they are all resolved, the calling process will be blocked until all values are available.


## Exception handling
If an error occurs while evaluating a future, the error is propagated and thrown as an error in the calling environment _when the future value is requested_.  For example, 
```r
> plan(lazy)
> f <- future({ 
+   stop("Whoops!")
+   42
+ })
> value(f)
Error in eval(expr, envir, enclos) : Whoops!
```
The error is thrown each time the value is requested, that is, trying to get the value again will generate the same error:
```r
> value(f)
Error in eval(expr, envir, enclos) : Whoops!
```

To retrieve the error object without signalling an error, use:
```r
> v <- value(f, onError="return")
> v
<simpleError in eval(expr, envir, enclos): Whoops!>
```

Exception handling of future assignments via `%<=%` works analogously, e.g.
```r
> plan(lazy)
> x %<=% ({ 
+   stop("Whoops!")
+   42
+ })
> y <- 3.14
> y
[1] 3.14
> x
Error in eval(expr, envir, enclos) : Whoops!
> x
Error in eval(expr, envir, enclos) : Whoops!
In addition: Warning message:
restarting interrupted promise evaluation
```
That latter warning is from R itself, notifying us that it already tried to evaluate the promise and tried another time.

The provided "eager future" is very special in the sense that
it is resolved immediately.  More specifically, the expression is
evaluated _before the future itself is created_.  Because of this,
the value of an "eager future" can never throw an error; if an error
would occur, it would have prevented the future from being created in
the first place, and without the future the corresponding future
value/promise will also not exists.  For example:
```r
> plan(eager, local=FALSE)
> a <- 0
> x %<=% ({
+   a <- 3.14
+   stop("Whoops!")
+   42
+ })
Error in eval(expr, envir, enclos) : Whoops!
> x
Error: object 'x' not found
> a
[1] 3.14
```

## Globals variables
The 'future' package does not provide mechanisms for controlling how global variables and functions are resolved.  Instead, this important task is passed on to the mechanism that evaluates the future expressions(*).  In other words, how global objects are identified and resolved will depend on what evaluation strategy is used.  Since both the eager and the lazy strategies implemented in this package evaluate futures synchronously in the current R session, there is no immediate need to identify globals and export them to the environment in which the future is evaluated.  In contrast, concurrent evaluation on a compute cluster would require that globals are exported to each compute node.  For instance, the future strategies implemented in the 'async' package, identify global objects (using the '[globals]' package) and makes sure they are available when the future expression is evaluated.

_Footnote_: \(*\) The task of identifying globals is a challenging problem and with concurrent/parallel evaluation there will always be corner cases that will not work as intended and troubleshooting can sometimes be tricky.  The purpose of the '[globals]' package is to try to standardize how globals are identified into one or a few different strategies.  Until such a standard has been identified and implemented, the 'future' package will not attempt to identify and export globals.  This may change in the future (another pun intended).


[BatchJobs]: http://cran.r-project.org/package=BatchJobs
[listenv]: http://cran.r-project.org/package=listenv
[globals]: http://cran.r-project.org/package=globals
[async]: https://github.com/UCSF-CBC/async/