# Getting started with Egglog

##### Table of Contents:
- [Why do we want to use Egglog?](#why-do-we-want-to-use-egglog)
- [Example in Egglog](#example-in-egglog)
- [Different styles of defining and declaring functions](#different-styles-of-defining-and-declaring-functions)
  - [Functions](#functions)
- [Rule and Rewrite - intermediate variables, pattern matching and some syntactic sugar](#rule-and-rewrite---intermediate-variables-pattern-matching-and-some-syntactic-sugar)
- [Subsume - replacing expressions / making them unextractable](#subsume---replacing-expressions--making-them-unextractable)
- [Useful inbuilt functions (Vectors, Sets, etc.)](#useful-inbuilt-functions-vectors-sets-etc)
- [Include other files](#include-other-files)
- [Useful resources](#useful-resources)
- [Install and run Egglog](#run-egglog)

## Why do we want to use Egglog?

Egglog allows us to find optimal equivalences between two expressions. Each expression has a cost - the lower the better. An expression can be represented by an AST and it is optimal if it reaches its lowest possible cost.

For instance, we know that a Multiplexer `Mux(a,b,s)` can be expressed with logical gates as `(a & ~s) | (b & s)`. <br> That means the expression `Mux(a,b,s)` is equivalent to `(a & ~s) | (b & s)`.

In Egglog, we could define Mux(a,b,c) as one expression with cost `1` and `(a & ~s) | (b & s)` as another expression that consists of two `and`-expressions and one `or`-expression. If `and`- and `or`-expressions are defined with a cost of `1` each, then `(a & ~s) | (b & s)` has a total cost of `3`.

Egglog is a language with an underlying e-graph (equivalence-graph) database. This is a database that stores equivalences. There are already frameworks in Rust in Python but Egglog provides a designated programming language for working with e-graphs.

## Example in Egglog

Let us define the Mux example from above in Egglog!<br>
Obviously, we need to define a Multiplexer. But first, we need some kind of signals, which are represented as `a`, `b` and `s` in the example. Let's call it `Wire`:

```
(sort Expr)
(constructor Wire (String i64) Expr)
```

This defines a new constructor for a `Wire`. The `sort` keyword defines a new datatype (the developers of Egglog say the reason to use the name `sort` has no particular reason). The things we add to a datatype, like `Wire`, are functions. Functions take inputs and give an output of any type and have a "merge behaviour" which defines how to solve conflicts between the output value of two equivalent objects (more on that [later](#functions)). But as you may have noticed, we used a constructor. A constructor, on the other hand, is a function, that returns a value of its own type and doesn't need to have a merge behaviour specified. In this example, the constructor is called `Wire` and has two inputs of type `String` and `i64` (both are inbuilt datatypes) and outputs itself - which is an Expr. <br>
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

## Subsume - replacing expressions / making them unextractable

Sometimes, there are expressions that are equivalent, but that you don't want to have as a valid solution. This could be the case if an expression is so expensive that using it is not feasible. Or if you face the same situation as me, that you use an expression as an intermediate expression that is processed to other expressions. I obviously don't want the intermediate expression to be a valid solution. <br>

This is where `subsume` becomes useful. `subsume` can be used as a function to prevent exactly that. <br>
Here an example inspired from [here](https://egraphs-good.github.io/egglog/?example=subsume) (assuming we defined an expression `Add`, `Mul` and `Num`):

```egglog
(rule 
    ((= mul (Mul (Num 3) x)))
    ((union mul (Add x (Add x x)))
    (subsume (Mul (Num 3) x)))  ; you can't use a variable as an argument for some reason 🤷
)
```

which is equivalent to:

```egglog
(rewrite (Mul (Num 3) x) (Add x (Add x x)) :subsume)
```

This example rewrites a multiplication with `3` (e.g. `3 * 2` `=>` `(Mul 3 2)`) to an equivalent expression with addition (`2 + 2 + 2` `=>` `(Add 2 (Add 2 2))`).
That could be useful in a scenario in which we have a compiler that is unreasonable bad in mulitplication with `3`. These two expressions are still equivalent but `(query-extract (Mul (Num 3) (Num 2)))` would now output `(Add (Num 2) (Add (Num 2) (Num 2)))` even though it has a higher cost. <br> 

I noticed in the rule form (first code snipped) that you cannot use variables as an argument for the subsume function. I don't know why but that's the reason why I don't use `mul` in the example above.

## Useful inbuilt functions (Vectors, Sets, etc.)

There are some inbuilt datatypes with inbuilt functions:

#### Vector
- `(vec-of 1 2 3)` => creates a vector of the three numbers `1`, `2` and `3`
- `(vec-pop 1 2 3)` => removes the last element (`3`) temporarily
- `(vec-push (vec-push (vec-empty) 1) 2)))` => `vec-empty` is an empty vector, `vec-push` adds an element. Therefore, the result is `(vec-of 1 2)`
- `(vec-append (vec-of 1 2) (vec-of 3 4))` => `(vec-of 1 2 3 4)`
- `(vec-not-contains (vec-of 1 2 3) 4)` => true. Checks if element is not in vector
- `(vec-contains (vec-of 1 2 3) 2)` => true. Checks if element is in vector
- `(vec-length (vec-of 1 2 3))` => ouputs length
- `(vec-get (vec-of 1 2 3) 1)` => read memory at given index (starts at index 0)
- `(vec-set (vec-of 1 2 3) 1 4)` => sets element at index `1` to number `4`

There are also [sets](https://egraphs-good.github.io/egglog/?example=set) and other functions which can maybe or maybe not be found in one of the example files on [this GitHub page](https://egraphs-good.github.io/egglog/).

## Include other files

Other Egglog files can easily be included with `include <filename>.egg`.

## Useful resources

Even though there is no official documentation, there are some useful links:

- [https://egraphs-good.github.io/egglog/](https://egraphs-good.github.io/egglog/) <br>
  This has many examples and it is very likely so find the syntax or semantic you are looking for.
- [YouTube Tutorial](https://www.youtube.com/watch?v=N2RDQGRBrSY&pp=ygUGZWdnbG9n) by one of the Egglog contributors
- [Egglog-Python documentation](https://github.com/egraphs-good/egglog-python/tree/main/docs): Even though it is for the Python library of Egglog, it can still be useful in some cases.
- [Another person explaining Egglog](http://www.chriswarbo.net/blog/2024-02-25-sk_logic_in_egglog_1.html)
- [ArchLab's Elephant Egglog repository with examples](https://github.com/pllab/elephant/blob/main/egglog/test.egg)
- [This official Egglog paper](https://arxiv.org/pdf/2304.04332)
- ["Egglog in practice"](https://effect.systems/doc/egraphs-2023-egglog/paper.pdf)  by one of the Egglog contributors

## Run Egglog

The first step is it to install Egglog as it is described in [their GitHub repository](https://github.com/egraphs-good/egglog). If the exectuable is created, add it to your path. <br>

Once Egglog is added to your path, you can easily run an egglog file with `egglog file.egg --to-svg` or run the script `./run.sh file.egg` to run a file and automatically convert and move the generated graph to the folder /output-egraphs. <br>
Maybe, you need to run `chmod +x ./run.sh`, `chmod +x ./run_all_tests.sh` and `chmod +x ./svg_conversion.sh` and install some dependencies first. <br>

To run all files in the /tests folder and to list, which of the files fail or succeed, you can run `./run_all_tests.sh`. Files, whose name starts with an underscore will be skipped. <br>

It is also useful to install the Egglog extension for VS Code or Vim.
