module FoldingTrees

using REPL.TerminalMenus
using AbstractTrees

export Node, toggle!, fold!, unfold!, isroot, count_open_leaves, next, prev, nodes

include("foldingtree.jl")
include("abstracttrees.jl")

if isdefined(TerminalMenus, :ConfiguredMenu)
    include("treemenu.jl")
end

end # module
