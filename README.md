# Eyeball.jl
*Object and type viewer for Julia*

[![Build Status](https://github.com/tshort/Eyeball.jl/workflows/CI/badge.svg)](https://github.com/tshort/Eyeball.jl/actions)

Eyeball exports one main tool to browse Julia objects and types.


```julia
eye(object)
eye(object, depth)
eye(object = Main, depth = 10; interactive = true, showsize = false)
```

`depth` controls the depth of folding. `showsize` controls whether the size of objects is shown.

The user can interactively browse the object tree using the following keys:

* `↑` `↓` `←` `→` -- Up and down moves through the tree. Left collapses a tree. Right expands a folded tree. Vim movement keys (`h` `j` `k` `l`) are also supported.
* `d` -- Docs. Show documentation on the object.
* `f` -- Toggle fields. By default, parameters are shown for most objects.
  `f` toggles between the normal view and a view showing the fields of an object.
* `m` -- Methodswith. Show methods available for objects of this type. `M` specifies `supertypes = true`.
* `o` -- Open. Open the object in a new tree view.
* `r` -- Return tree. Return the tree (a `FoldingTrees.Node`).
* `s` -- Show object.
* `t` -- Typeof. Show the type of the object in a new tree view.
* `z` -- Size. Toggle showing size of objects.
* `0`-`9` -- Fold to depth.
* `enter` -- Return the object.
* `q` -- Quit.

## Examples

Explore an object:

```julia
a = (h=rand(5), e=:(5sin(pi*t)), f=sin, c=33im, set=Set((:a, 9, rand(1:5, 8))), b=(c=1,d=9,e=(i=9,f=0)), x=9 => 99:109, d=Dict(1=>2, 3=>4), ds=Dict(:s=>4,:t=>7), dm=Dict(1=>9, "x"=>8))
eye(a)
```
```jl
julia> eye(a)
[f] fields [d] docs [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] size [q] quit
 >   NamedTuple{(:h, :e, :f, :c, :set, :b, :x, :d, :ds, :dm), Tuple{Vector{Float64}, Expr, typeof(sin), Complex{Int64}, Set{A
   +  h: Vector{Float64} (5,) [0.893213, 0.120307, 0.322837, 0.0256164, 0.416702]
      e: Expr  :(5 * sin(pi * t))
       head: Symbol  :call
       args: Vector{Any} (3,) Any[:*, 5, :(sin(pi * t))]
        1: Symbol  :*
        2: Int64  5
        3: Expr  :(sin(pi * t))
         head: Symbol  :call
         args: Vector{Any} (2,) Any[:sin, :(pi * t)]
          1: Symbol  :sin
          2: Expr  :(pi * t)
           head: Symbol  :call
           args: Vector{Any} (3,) Any[:*, :pi, :t]
            1: Symbol  :*
            2: Symbol  :pi
            3: Symbol  :t
      f: typeof(sin)  sin
   +  c: Complex{Int64}  0+33im
      set: Set{Any}  Set(Any[:a, [5, 2, 1, 5, 3, 3, 1, 1], 9])
       : Symbol  :a
   +   : Vector{Int64} (8,) [5, 2, 1, 5, 3, 3, 1, 1]
       : Int64  9
      b: NamedTuple{(:c, :d, :e), Tuple{Int64, Int64, NamedTuple{(:i, :f), Tuple{Int64, Int64}}}}  (c = 1, d = 9, e = (i = 9,
       c: Int64  1
       d: Int64  9
       e: NamedTuple{(:i, :f), Tuple{Int64, Int64}}  (i = 9, f = 0)
        i: Int64  9
        f: Int64  0
      x: Pair{Int64, UnitRange{Int64}}  9=>99:109
       first: Int64  9
   +   second: UnitRange{Int64} (11,) 99:109
      d: Dict{Int64, Int64}  Dict(3=>4, 1=>2)
       3: Int64  4
       1: Int64  2
v     ds: Dict{Symbol, Int64}  Dict(:s=>4, :t=>7)
```

Explore a Module:


```julia
eye()      # equivalent to `eye(Main)`
```
<details>
  <summary>Expand results</summary>
  
```jl
julia> eye()
[f] fields [d] docs [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] size [q] quit
 >   Module
      Base: Module  Base
      Core: Module  Core
      InteractiveUtils: Module  InteractiveUtils
      Main: Module  Main
      a: NamedTuple{(:h, :e, :f, :c, :set, :b, :x, :d, :ds, :dm), Tuple{Vector{Float64}, Expr, typeof(sin), Complex{Int64}, S
   +   h: Vector{Float64} (5,) [0.893213, 0.120307, 0.322837, 0.0256164, 0.416702]
       e: Expr  :(5 * sin(pi * t))
        head: Symbol  :call
        args: Vector{Any} (3,) Any[:*, 5, :(sin(pi * t))]
         1: Symbol  :*
         2: Int64  5
         3: Expr  :(sin(pi * t))
          head: Symbol  :call
          args: Vector{Any} (2,) Any[:sin, :(pi * t)]
           1: Symbol  :sin
           2: Expr  :(pi * t)
            head: Symbol  :call
            args: Vector{Any} (3,) Any[:*, :pi, :t]
             1: Symbol  :*
             2: Symbol  :pi
             3: Symbol  :t
       f: typeof(sin)  sin
   +   c: Complex{Int64}  0+33im
       set: Set{Any}  Set(Any[:a, [5, 2, 1, 5, 3, 3, 1, 1], 9])
        : Symbol  :a
   +    : Vector{Int64} (8,) [5, 2, 1, 5, 3, 3, 1, 1]
        : Int64  9
       b: NamedTuple{(:c, :d, :e), Tuple{Int64, Int64, NamedTuple{(:i, :f), Tuple{Int64, Int64}}}}  (c = 1, d = 9, e = (i = 9
        c: Int64  1
        d: Int64  9
        e: NamedTuple{(:i, :f), Tuple{Int64, Int64}}  (i = 9, f = 0)
         i: Int64  9
         f: Int64  0
       x: Pair{Int64, UnitRange{Int64}}  9=>99:109
v       first: Int64  9
```

</details>

Explore a type tree:

```julia
eye(Number)
```
<details>
  <summary>Expand results</summary>
  
```jl
julia> eye(Number)
[f] fields [d] docs [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] size [q] quit
 >   DataType
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

`eye` can also be used noninteractively.
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


## API

By default, `eye` shows the properties of an object.
That can be customized for different objects.
For example, `Dict`s are shown with the key then the value, and abstract types are shown with subtypes.
To customize what's shown for `SomeType`, define `Eyeball.getobjects(x::SomeType)`.
This method should return an array of `Pair`s describing the objects to be shown.
The first component of the `Pair` is the key or index of the object, and the second component is the object.

The display of objects can also be customized with the following boolean methods:

```julia
Eyeball.shouldrecurse(x, len)   
Eyeball.foldobject(x)   
```

`shouldrecurse` controls whether `eye` recurses into the object.
`x` is the object. `len` is the length of the object. 
This defaults to `true` when `len < 30`.
For overly large or complex objects, it helps to return `false`.
That's done internally for `Module`s, `Method`s, and a few other types.
`foldobject` controls whether `eye` automatically folds the object.
This is useful for types where the components are usually not needed.
This defaults to `false`.

## Under the Hood

`Eyeball` uses [FoldingTrees](https://github.com/JuliaCollections/FoldingTrees.jl) for display of trees and interactivity.
[This fork](https://github.com/MichaelHatherly/InteractiveErrors.jl/tree/master/src/vendor/FoldingTrees)
was extended to support customized key presses.

The code was adapted from [InteractiveErrors.jl](https://github.com/MichaelHatherly/InteractiveErrors.jl)
 and [Cthulhu.jl](https://github.com/JuliaDebug/Cthulhu.jl).
