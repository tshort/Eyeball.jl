# Eyeball.jl
*Object and type viewer for Julia*

[![Build Status](https://github.com/tshort/Eyeball.jl/workflows/CI/badge.svg)](https://github.com/tshort/Eyeball.jl/actions)

Eyeball exports one main tool to browse Julia objects and types.


```julia
eye(object)
eye(object, depth)
eye(object = Main, depth = 10; interactive = true, all = false)
```

`depth` controls the depth of folding. `all` expands options.

The user can interactively browse the object tree using the following keys:

* `↑` `↓` `←` `→` -- Up and down moves through the tree. Left collapses a tree. Right expands a folded tree. Vim movement keys (`h` `j` `k` `l`) are also supported.
* `d` -- Docs. Show documentation on the object.
* `e` -- Expand. Show more subobjects. The number of objects is doubled each time.
* `f` -- Toggle fields. By default, parameters are shown for most objects.
  `f` toggles between the normal view and a view showing the fields of an object.
* `m` -- Methodswith. Show methods available for objects of this type. `M` specifies `supertypes = true`.
* `o` -- Open. Open the object in a new tree view. `O` opens all (mainly useful for modules).
* `r` -- Return tree (a `FoldingTrees.Node`). 
* `s` -- Show object.
* `t` -- Typeof. Show the type of the object in a new tree view.
* `z` -- Summarize. Toggle a summary of the object and child objects. 
  For arrays, this shows the mean and 0, 25, 50, 75, and 100% quantiles (skipping missings).
* `0`-`9` -- Fold to depth. Also toggles expansion of items normally left folded.
* `enter` -- Return the selected object.
* `q` -- Quit.

Notes:

* Longer objects only have the first few elements shown when unfolded. Use `e` to expand.
* Some types are left folded by default (numbers, typed arrays, ...).
  The number keys for folding cycle between keeping these folded and unfolding these.
* Some types are not recursed into. This includes modules. You can use `o` to open these in a new tree view.
* `O` and `all = true` adds a wrapper `Eyeball.All` around the object.
  This is mainly for use with modules where options are taken with `name(module, all = true)`.
* Summarize `z` shows a summary of child objects. That's useful for DataFrames, nested arrays, and similar types.
* For dictionaries with simple keys (symbols, strings, or numbers), the key is shown directly.
  For others, a list of key-value pairs is shown.

## Examples

#### Explore an object:

```julia
a = (h=rand(5), e=:(5sin(pi*t)), f=sin, c=33im, set=Set((:a, 9, rand(1:5, 8))), b=(c=1,d=9,e=(i=9,f=0)), x=9 => 99:109, d=Dict(1=>2, 3=>4), ds=Dict(:s=>4,:t=>7), dm=Dict(1=>9, "x"=>8))
eye(a)
```
```jl
julia> eye(a)
[f] fields [d] docs [e] expand [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] summarize [q] quit
 >   : NamedTuple{(:h, :e, :f, :c, :set, :b, :x, :d, :ds, :dm), Tuple{Vector{Float64}, Expr, typeof(sin), Complex{Int64}   +  h: Vector{Float64} (5,) 40 [0.589398, 0.761107, 0.963494, 0.835393, 0.488657]
      e: Expr  :(5 * sin(pi * t))
       head: Symbol  :call
       args: Vector{Any} (3,) 24 Any[:*, 5, :(sin(pi * t))]
        1: Symbol  :*
        2: Int64  5
        3: Expr  :(sin(pi * t))
         head: Symbol  :call
         args: Vector{Any} (2,) 16 Any[:sin, :(pi * t)]
          1: Symbol  :sin
          2: Expr  :(pi * t)
           head: Symbol  :call
           args: Vector{Any} (3,) 24 Any[:*, :pi, :t]
            1: Symbol  :*
            2: Symbol  :pi
            3: Symbol  :t
      f: typeof(sin)  sin
   +  c: Complex{Int64}  0+33im
      set: Set{Any}  Set(Any[:a, 9, [2, 3, 2, 5, 5, 1, 4, 5]])
       : Symbol  :a
       : Int64  9
   +   : Vector{Int64} (8,) 64 [2, 3, 2, 5, 5, 1, 4, 5]
      b: NamedTuple{(:c, :d, :e), Tuple{Int64, Int64, NamedTuple{(:i, :f), Tuple{Int64, Int64}}}}  (c = 1, d = 9, e = (i       c: Int64  1
       d: Int64  9
       e: NamedTuple{(:i, :f), Tuple{Int64, Int64}}  (i = 9, f = 0)
        i: Int64  9
        f: Int64  0
   +  x: Pair{Int64, UnitRange{Int64}}  9=>99:109
      d: Dict{Int64, Int64}  Dict(3=>4, 1=>2)
       3: Int64  4
       1: Int64  2
      ds: Dict{Symbol, Int64}  Dict(:s=>4, :t=>7)
       s: Int64  4
v      t: Int64  7
```

#### Explore a Module:


```julia
eye()      # equivalent to `eye(Main)`
```
<details>
  <summary>Expand results</summary>

```jl
julia> eye()
[f] fields [d] docs [e] expand [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] summarize [q] quit
 >   : Module  Main
      Base: Module  Base
      Core: Module  Core
      InteractiveUtils: Module  InteractiveUtils
      Main: Module  Main
      a: NamedTuple{(:h, :e, :f, :c, :set, :b, :x, :d, :ds, :dm), Tuple{Vector{Float64}, Expr, typeof(sin), Complex{Int6   +   h: Vector{Float64} (5,) 40 [0.589398, 0.761107, 0.963494, 0.835393, 0.488657]
       e: Expr  :(5 * sin(pi * t))
        head: Symbol  :call
        args: Vector{Any} (3,) 24 Any[:*, 5, :(sin(pi * t))]
         1: Symbol  :*
         2: Int64  5
         3: Expr  :(sin(pi * t))
          head: Symbol  :call
          args: Vector{Any} (2,) 16 Any[:sin, :(pi * t)]
           1: Symbol  :sin
           2: Expr  :(pi * t)
            head: Symbol  :call
            args: Vector{Any} (3,) 24 Any[:*, :pi, :t]
             1: Symbol  :*
             2: Symbol  :pi
             3: Symbol  :t
       f: typeof(sin)  sin
   +   c: Complex{Int64}  0+33im
       set: Set{Any}  Set(Any[:a, 9, [2, 3, 2, 5, 5, 1, 4, 5]])
        : Symbol  :a
        : Int64  9
   +    : Vector{Int64} (8,) 64 [2, 3, 2, 5, 5, 1, 4, 5]
       b: NamedTuple{(:c, :d, :e), Tuple{Int64, Int64, NamedTuple{(:i, :f), Tuple{Int64, Int64}}}}  (c = 1, d = 9, e = (        c: Int64  1
        d: Int64  9
        e: NamedTuple{(:i, :f), Tuple{Int64, Int64}}  (i = 9, f = 0)
         i: Int64  9
         f: Int64  0
   +   x: Pair{Int64, UnitRange{Int64}}  9=>99:109
v      d: Dict{Int64, Int64}  Dict(3=>4, 1=>2)
```

</details>

#### Explore a type tree:

```julia
eye(Number)
```
<details>
  <summary>Expand results</summary>
  
```jl
julia> eye(Number)
[f] fields [d] docs [e] expand [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] summarize [q] quit
>   : DataType  Number
   +  : UnionAll  Complex
      : DataType  Real
       : DataType  AbstractFloat
   +    : DataType  BigFloat
        : DataType  Float16
        : DataType  Float32
        : DataType  Float64
       : DataType  AbstractIrrational
   +    : UnionAll  Irrational
       : DataType  Integer
        : DataType  Bool
        : DataType  Signed
   +     : DataType  BigInt
         : DataType  Int128
         : DataType  Int16
         : DataType  Int32
         : DataType  Int64
         : DataType  Int8
        : DataType  Unsigned
         : DataType  UInt128
         : DataType  UInt16
         : DataType  UInt32
         : DataType  UInt64
         : DataType  UInt8
   +   : UnionAll  Rational
```

</details>

#### Use noninteractively
With the keyword argument `interactive` set to `false`, `eye` returns the tree as a `FoldingTrees.Node`.
That is automatically displayed via `show` or by using `FoldingTrees.print_tree`.

```julia
eye(Number, interactive = false)
```
<details>
  <summary>Expand results</summary>
  
```jl
julia> eye(Number, interactive = false)
  DataType
├─ + : UnionAll Complex
└─   : DataType Real
   ├─   : DataType AbstractFloat
   │  ├─ + : DataType BigFloat
   │  ├─   : DataType Float16
   │  ├─   : DataType Float32
   │  └─   : DataType Float64
   ├─   : DataType AbstractIrrational
   │  └─ + : UnionAll Irrational
   ├─   : DataType Integer
   │  ├─   : DataType Bool
   │  ├─   : DataType Signed
   │  │  ├─ + : DataType BigInt
   │  │  ├─   : DataType Int128
   │  │  ├─   : DataType Int16
   │  │  ├─   : DataType Int32
   │  │  ├─   : DataType Int64
   │  │  └─   : DataType Int8
   │  └─   : DataType Unsigned
   │     ├─   : DataType UInt128
   │     ├─   : DataType UInt16
   │     ├─   : DataType UInt32
   │     ├─   : DataType UInt64
   │     └─   : DataType UInt8
   └─ + : UnionAll Rational
```

</details>

#### Summarize
Show a summary of arrays in a named tuple (also useful for DataFrames).

```julia
d = (a = rand(100), b = rand(100:200, 100), c = 4rand(Float32, 100))
eye(d)    # then hit `z` to summarize
```
<details>
  <summary>Expand results</summary>
  
```jl
julia> eye(d)
[f] fields [d] docs [e] expand [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] summarize [q] quit
 >   : NamedTuple{(:a, :b, :c), Tuple{Vector{Float64}, Vector{Int64}, Vector{Float32}}}  (a = [0.721857, 0.174408, 0.897
 >      +  a: Vector{Float64} (100,) 800 x̄=0.535717, q=[0.0372074, 0.305533, 0.556568, 0.770658, 0.979569]
 >      +  b: Vector{Int64} (100,) 800 x̄=145.5, q=[100.0, 117.0, 145.5, 170.0, 200.0]
 >      +  c: Vector{Float32} (100,) 400 x̄=1.90419, q=[0.0898504, 1.09705, 1.9039, 2.68442, 3.93898]
```

</details>



## API

By default, `eye` shows the properties of an object.
That can be customized for different objects.
For example, `Dict`s are shown with the key then the value, and abstract types are shown with subtypes.
To customize what's shown for `SomeType`, define `Eyeball.getobjects(x::SomeType)`.
This method should return an iterator that returns a key and a value describing each of the child objects to be shown.

The display of objects can also be customized with the following boolean methods:

```julia
Eyeball.shouldrecurse(x)   
Eyeball.foldobject(x)   
```

`shouldrecurse` controls whether `eye` recurses into object `x`.
This defaults to `true`.
For overly large or complex objects, it helps to return `false`.
That's done internally for `Module`s, `Method`s, and a few other types.
`foldobject` controls whether `eye` automatically folds the object.
This is useful for types where the components usually don't need to be shown.
This defaults to `false`.

To add additional "summarize" options, define `Base.show(io::IO, x::Eyeball.Summarize{T})` for type `T`.


## Under the Hood

`Eyeball` uses [FoldingTrees](https://github.com/JuliaCollections/FoldingTrees.jl) for display of trees and interactivity.
[This fork](https://github.com/MichaelHatherly/InteractiveErrors.jl/tree/master/src/vendor/FoldingTrees)
was extended to support customized key presses.
[TerminalPager](https://github.com/ronisbr/TerminalPager.jl) is used for paging.

The code was adapted from [InteractiveErrors.jl](https://github.com/MichaelHatherly/InteractiveErrors.jl)
 and [Cthulhu.jl](https://github.com/JuliaDebug/Cthulhu.jl).
