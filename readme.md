# Getting started with Egglog

##### Table of Contents:
- [Why do we want to use Egglog?](#why-do-we-want-to-use-egglog)
- [Example in Egglog](#example-in-egglog)
- [Different styles of defining and declaring functions](#different-styles-of-defining-and-declaring-functions)
  - [Functions](#functions)
- [Rule and Rewrite - intermediate variables, pattern matching and some syntactic sugar](#rule-and-rewrite---intermediate-variables-pattern-matching-and-some-syntactic-sugar)
- [Include other files](#include-other-files)
- [Useful resources](#useful-resources)
- [Install and run Egglog](#run-egglog)

## Why do we want to use Egglog?

Egglog allows us to find optimal equivalences between two expressions. Each expression has a cost - the lower the better. An expression can be represented by an AST and it is optimal if it reaches its lowest possible cost.

For instance, we know that a Multiplexer `Mux(a,b,s)` can be expressed with logical gates as `(a & ~s) | (b & s)`. <br> That means the expression `Mux(a,b,s)` is equivalent to `(a & ~s) | (b & s)`.

In Egglog, we could define Mux(a,b,c) as one expression with cost `1` and `(a & ~s) | (b & s)` as another expression that consists of two `and`-expressions and one `or`-expression. If `and`- and `or`-expressions are defined with a cost of `1` each, then `(a & ~s) | (b & s)` has a total cost of `3`.

Egglog is a language with an underlying e-graph (equivalence-graph) database. This is a database that stores equivalences. There are already frameworks in Rust in Python but Egglog provides a designated programming language for working with e-graphs.

## Example in Egglog

Let us define the Mux example frome above in Egglog!<br>
Obviously, we need to define a Multiplexer. But first, we need some kind of singals, which are represented as `a`, `b` and `s` in the example. Let's call it `Wire`:

```
(sort Expr)
(constructor Wire (String i64) Expr)
```

This defines a new constructor for a `Wire`. The `sort` keyword defines a new datatype (the developers of Egglog say the reason to use the name `sort` has no particular reason). The things we add to a datatype, like `Wire`, are functions. Functions take inputs and give an output of any type and have a "merge behaviour" which defines how to solve conflicts between the output value of two equivalent objects. But as you may have noticed, we used a constructor. A constructor, on the other hand, is a function, that returns a value of its own type and don't need to have a merge behaviour specified. In this example, the constructor is called `Wire` and has two inputs of type `String` and `i64` (both are inbuilt datatypes) and outputs itself - which is an Expr. <br>
Later, it can be called with this syntax: `(Wire "s" 1)`.<br>

Now, we can continue to implement the functions we need for the example.<br>
`And`- and `Or`-expressions are functions that takes two inputs of type `Expr`. `Not` only takes one `Expr`. A Multiplexer-expression `Mux` has an enable signal and two signals to choose from. We introduce a `Concat`-expression to concatenate two singals to write a `Mux` as `(Mux s (Concat a b))`.<br>
Let's add their constructors:

```
(constructor And (Expr Expr) Expr)
(constructor Or (Expr Expr) Expr)
(constructor Not (Expr) Expr)
(constructor Concat (Expr Expr) Expr)
(constructor Mux (Expr Expr) Expr)
```

Finally, we can now create the expressions we want to implement!<br>
We use the `let` statement to define an expression. If you come across a `set` statement, this is related to functions and is used to define inital values for functions. <br>
```
(let s (Wire "s" 1))
(let a (Wire "a" 1))
(let b (Wire "b" 1))

(let mux_circuit 
    (Or 
     (And a (Not s)) 
     (And b s)))
(let mux_expression (Mux s (Concat a b)))
(check (= mux_circuit mux_expression))
```
These lines define three `Wire`s `s`, `a` and `b` each of bit width `1` and the logic of a mulitplexer with `Or`- and `And`-expressions. It also creates a `Mux`-expression which we know to be equivalent to the gate logic definition. The check keyword checks if something is true. In this case it tests, if `= mux_circuit mux_expression` is true. Notice, that Egglog uses prefix notation. Therefore, `= mux_circuit mux_expression` should be read as `mux_circuit = mux_expression`. <br>

If we run this code we have so far, the check would still fail even though both expressions are equivalent. This is because we need to define a rule that tells Egglog that those two expressions are equivalent.<br>
This can simply be done by the `rule` keyword. A `rule` consists of two sides: the left side must hold in order for the right side to be executed. Equivalence can be specified with the `union` keyword. `union a b` creates a equivalence relation between an expression `a` and `b`. A rule can be added to a ruleset with `:ruleset <ruleset_name>` and a ruleset is created by `(ruleset <ruleset_name>)`.
```
(rule
    ; The "left" side: here it is the gate logic of the multiplexer
    ((Or (And a (Not s)) (And b s)))  

    ; The "right" side; here we "union" it (declare equivalence) with the expression of the left side
    ((union 
        (Or (And a (Not s)) (And b s))  ; this is equivalent to...
        (Mux s (Concat a b))            ; ... this
    ))
    :ruleset typing
)
```

To apply the rewrite rules to the expressions we created, we need to run this code:
```
(run-schedule (repeat 5) (saturate typing))
```
This runs the `typing` rules five times. Without the `repeat` it runs as long there are no changes. Several rulesets can be applied by appending them in the same manner as the typing ruleset.<br>

After the rules are applied, `(Mux s (Concat a b))` should indeed be recognized as a cheaper equivalence of `(Or (And a (Not s)) (And b s))` and the check `(check (= mux_circuit mux_expression))` should pass!<br>

`(query-extract mux_circuit)` should print the optimal found solution `(Mux s (Concat a b))`. <br>
A program can also be executed step-wise by `(run <stepsize>)`.
<br><br><br>


## Different styles of defining and declaring functions

Sorts with many constructors can get a bit messy but can also be written as:

```
(datatype Expr
   (Wire String i64)
   (And Expr Expr)
   (Or Expr Expr)
   (Not Expr)
   (Concat Expr Expr)
   (Mux Expr Expr)
)
```
Sort still has its advantages if you want to reference a datatype that is defined later, eg:
```
(sort Memory)
(datatype
    (Expr
        (MemoryAccess Expr Memory)  ; note that we reference Memory
        ...))
...
(constructor Mem (String) Memory)   ; Memory defined after it is referenced in Expr
```

You can also define several datatypes at once with an asterisk:
```
(datatype* 
    (Expr 
        (MemoryAccess Expr Memory)
    )
    (Memory
        (Mem String)
    )
)
```

### Functions

As mentioned earlier, functions take inputs and some output. They can also get assigned `cost` and merge behavior `merge`. Merge behavior is necessary, if two expressions `a`, `b` are equivalent but function value of `a` differs from function value of `b`. A simple merge behavior is `(max old new)` in which `old` is the old value to be merged with the new value `new`. `max` can be substituted by any other function. Merge behaviors are set at the end of a function declaration with `:merge (<merge-behavior>)`. You can also use `:no-merge` instead, if you are sure that merge conflicts wont happen. <br>
Output values of functions can be set with the `set` keyword. I think the [fibonacci example from the egglog github page](https://egraphs-good.github.io/egglog/?example=fibonacci) make this clear:

```egglog
(function fib (i64) i64 :no-merge)      ; define function fib
(set (fib 0) 0)                         ; set values of the function for input 0 to 0
(set (fib 1) 1)                         ; and for input 1 to 1

(rule ((= f0 (fib x))                   ; if there is a fib function call with input x
       (= f1 (fib (+ x 1))))            ; and also one for input (x+1)
      ((set (fib (+ x 2)) (+ f0 f1))))  ; then the function value for (x+2) is set to fib(x) + fib(x+1)

(run 7)                                 ; run the fibonacci rule seven times

(check (= (fib 7) 13))                  ; check the output of fib(7) to be 13
```

## Rule and Rewrite - intermediate variables, pattern matching and some syntactic sugar

Let's recall the rule example mentioned in the example above:
```
(rule
    ; The "left" side: here it is the gate logic of the multiplexer
    ((Or (And a (Not s)) (And b s)))  

    ; The "right" side; here we "union" it (declare equivalence) with the expression of the left side
    ((union 
        (Or (And a (Not s)) (And b s))  ; this is equivalent to...
        (Mux s (Concat a b))            ; ... this
    ))
    :ruleset typing
)
```
As you may notice, we extensively write the rather complex `Or`-expression twice, once on the left side, once on the right side. But we can simply declare an intermediate variable e.g. called `or` that can be reused:

```
(rule
    ((= or (Or (And a (Not s)) (And b s))))  
    ((union or (Mux s (Concat a b))))
    :ruleset typing
)
```

The use of variables has the advantage of being able to pattern match the variables:
```
(rule
    ((= or (Or o1 o2))
     (= o1 (And a (Not s)))
     (= o2 (And b s)))
    ((union or (Mux s (Concat a b))))
    :ruleset typing
)
```
This is useful in many cases. But the simple first two notations can also be expressed with the `rewrite` keyword which is syntactic sugar for `(rule (a) (union a b))`:
```
(rewrite
    (Or (And a (Not s)) (And b s))
    (Mux s (Concat a b))
    :ruleset typing
)
```

## Include other files

Other Egglog files can easily be included with `include <filename>.egg`.

## Useful resources

Even though there is no official documentation, there are some useful links:

- https://egraphs-good.github.io/egglog/ <br>
  This has many examples and it is very likely so find the syntax or semantic you are looking for.
- [Egglog-Python documentation](https://github.com/egraphs-good/egglog-python/tree/main/docs): Even though it is for the Python library of Egglog, it can still be useful in some cases.
- [Another person explaining Egglog](http://www.chriswarbo.net/blog/2024-02-25-sk_logic_in_egglog_1.html)
- [ArchLab's Elephant Egglog repository with examples](https://github.com/pllab/elephant/blob/main/egglog/test.egg)
- [This official Egglog paper](https://arxiv.org/pdf/2304.04332)
- ["Egglog in practice"](https://effect.systems/doc/egraphs-2023-egglog/paper.pdf)  by one of the Egglog contributor

## Run Egglog

The first step is it to install Egglog as it is described in [their GitHub repository](https://github.com/egraphs-good/egglog). If the exectuable is created, add it to your path. <br>

Once Egglog is added to your path, you can easily run an egglog file with `egglog file.egg --to-svg` or run the script `./run.sh file.egg` to run a file and automatically convert and move the generated graph to the folder /output-egraphs. <br>
Maybe, you need to run `chmod +x ./run.sh`, `chmod +x ./run_all_tests.sh` and `chmod +x ./svg_conversion.sh` and install some dependencies first. <br>

To run all files in the /tests folder and to list, which of the files fail or succeed, you can run `./run_all_tests.sh`. Files, whose name starts with an underscore will be skipped. <br>

It is also useful to install the Egglog extension for VS Code or Vim.
