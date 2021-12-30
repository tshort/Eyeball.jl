# FoldingTrees

[![Build Status](https://travis-ci.com/JuliaCollections/FoldingTrees.jl.svg?branch=master)](https://travis-ci.com/JuliaCollections/FoldingTrees.jl)
[![Codecov](https://codecov.io/gh/JuliaCollections/FoldingTrees.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaCollections/FoldingTrees.jl)

FoldingTrees implements a dynamic [tree structure](https://en.wikipedia.org/wiki/Tree_%28data_structure%29) in which some nodes may be "folded," i.e., marked to avoid descent among that node's children.
It also supports interactive text menus based on folding trees.

## Creating trees with `Node`

For example, after saying `using FoldingTrees`, a "table of contents" like

    I. Introduction
      A. Some background
        1. Stuff you should have learned in high school
        2. Stuff even Einstein didn't know
      B. Defining the problem
    II. How to solve it

could be created like this:

```julia
root = Node("")
chap1 = Node("Introduction", root)
chap1A = Node("Some background", chap1)
chap1A1 = Node("Stuff you should have learned in high school", chap1A)
chap1A2 = Node("Stuff even Einstein didn't know", chap1A)
chap1B = Node("Defining the problem", chap1)
chap2 = Node("How to solve it", root)
```

You don't have to create them in this exact order, the only constraint is that you create the parents before the children.
In general you create a node as `Node(data, parent)`, where `data` can be any type.
The root node is the only one that you create without a parent, i.e., `root = Node(data)`, and the type of data used to create `root` is enforced for all leaves of the tree.
You can specify the type with `root = Node{T}(data)` if necessary.
There is no explicit limit on the number of children that a node may have.

Using the [AbstractTrees](https://github.com/JuliaCollections/AbstractTrees.jl) package,
the tree above displays as

```julia
julia> print_tree(root)

├─   Introduction
│  ├─   Some background
│  │  ├─   Stuff you should have learned in high school
│  │  └─   Stuff even Einstein didn't know
│  └─   Defining the problem
└─   How to solve it
```

Now let's fold the section named "Some background":

```julia
julia> fold!(chap1A)
true

julia> print_tree(root)

├─   Introduction
│  ├─ + Some background
│  └─   Defining the problem
└─   How to solve it
```

You can use `unfold!` to reverse the folding and `toggle!` to switch folding.

There are a few utilities that you can learn about by reading their docstrings:

- `isroot`: determine whether a node is the root node
- `count_open_leaves`: count the number of nodes in the tree above the first fold on all branches
- `next`, `prev`: efficient ordered visitation of open nodes (depth-first)
- `nodes`: access nodes, rather than their data, during iteration (example: `foreach(unfold!, nodes(root)))`

## TreeMenu

On suitable Julia versions (ones for which `isdefined(REPL.TerminalMenus, :ConfiguredMenu)` is `true`,
a.k.a. `1.6.0-DEV.201` or higher), you can use such trees to create interactive menus via
[TerminalMenus](https://docs.julialang.org/en/v1.6-dev/stdlib/REPL/#TerminalMenus-1).

Suppose `root` is the same `Node` we created above, in the original unfolded state.
Then

```julia
julia> using REPL.TerminalMenus

julia> menu = TreeMenu(root)

julia> choice = request(menu; cursor=2)

 >    Introduction
       Some background
        Stuff you should have learned in high school
        Stuff even Einstein didn't know
       Defining the problem
      How to solve it
```

The initial blank line is due to our `root`, which displays as an empty string; we set the initial "cursor position,"
indicated visually by `>`, to skip over that item.
You can use the up/down arrow keys to navigate over different items in the menu.
Choose an item by hitting `Enter`, toggle folding at the cursor position by hitting the space bar:

```julia
julia> choice = request(menu; cursor=2)

      Introduction
 > +   Some background
       Defining the problem
      How to solve it
```

One can create very large menus with thousands of options, in which case the menu scrolls with the arrow keys
and `PgUp`/`PgDn`.
As described in the `TerminalMenus` documentation, you can customize aspects of the menu's appearance,
such as the number of items visible simultaneously and the characters used to indicate scrolling and the cursor position.

For `Node` objects where `data` is not an `AbstractString`, you will most likely want to specialize `FoldingTrees.writeoption` for your type.
See `?FoldingTrees.writeoption` for details.
