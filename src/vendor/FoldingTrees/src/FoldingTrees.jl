module FoldingTrees

#Base.Experimental.@compiler_options compile=min optimize=1 infer=false

using REPL.TerminalMenus
using AbstractTrees

export Node, toggle!, fold!, unfold!, isroot, count_open_leaves, next, prev, nodes

include("foldingtree.jl")
include("abstracttrees.jl")

if isdefined(TerminalMenus, :ConfiguredMenu)
    include("treemenu.jl")
end

end # module
