module Eyeball

Base.Experimental.@compiler_options compile=min optimize=1

using Base.Docs

using InteractiveUtils
using REPL: REPL, AbstractTerminal

using REPL.TerminalMenus
import REPL.TerminalMenus: request

# TODO: de-vendor once changes are upstreamed.
include("vendor/FoldingTrees/src/FoldingTrees.jl")
using .FoldingTrees

# include("ui.jl")

export eye


default_terminal() = REPL.LineEdit.terminal(Base.active_repl)

function eye(x = Main, depth = 10; interactive = true)
    root = treelist(x, depth = depth - 1)
    if interactive
        term = default_terminal()
        menu = TreeMenu(root, pagesize = REPL.displaysize(term)[1] - 2, dynamic = true, maxsize = 30, keypress = keypress)
        choice = TerminalMenus.request(term, "[f] toggle fields [d] docs [o] open [t] typeof [q] quit", menu; cursor=menu.currentidx)
        choice !== nothing && return choice.data.obj
        return
    else
        menu = TreeMenu(root, pagesize = 20, dynamic = true, maxsize = 30, keypress = keypress)
        return root
    end
end

struct ObjectWrapper
    obj
    str
    showfields
end
ObjectWrapper(obj, str) = ObjectWrapper(obj, str, Ref(false))

Base.show(io::IO, x::ObjectWrapper) = print(io, x.str)


# from https://github.com/MichaelHatherly/InteractiveErrors.jl/blob/5e2e90f9636d748aa3aae0887e18df388829b8e7/src/InteractiveErrors.jl#L52-L61
function style(str; kws...)
    sprint(; context = :color => true) do io
        printstyled(
            io, str;
            bold = get(kws, :bold, false),
            color = get(kws, :color, :normal),
        )
    end
end


function treelist(x; depth = 0, parent = Node(ObjectWrapper(x, style(typeof(x), color = :yellow))), history = Base.IdSet{Any}((x,)))
    usefields = parent.data.showfields[] && isstructtype(typeof(x)) && !(x isa DataType) 
    opts = usefields ? getfields(x) : getoptions(x)
    for (pn, obj) in opts
        nprop = length(getoptions(obj)) 
        node = Node(ObjectWrapper(obj, tostring(pn, obj)), 
                    parent, 
                    foldobject(obj) || (depth < 1 && nprop > 0 && shouldrecurse(obj)))
        if nprop > 0 && depth > -20 && obj ∉ history && shouldrecurse(obj, nprop)
            treelist(obj, depth = depth - 1, parent = node, history = push!(copy(history), obj))
        end
    end
    return parent
end

function FoldingTrees.writeoption(buf::IO, obj::ObjectWrapper, charsused::Int; width::Int=(displaysize(stdout)::Tuple{Int,Int})[2])
    FoldingTrees.writeoption(buf, obj.str, charsused; width=width)
end

function tostring(pn, obj)
    string(style(pn, color = :cyan), ": ", style(typeof(obj), color = :green), " ", obj)
end

function getfields(x::T) where T
    res = Any[]
    !isstructtype(T) && return res
    for pn in fieldnames(typeof(x))
        try
            push!(res, (pn, getfield(x, pn)))
        catch e
            # println("error")
        end
    end
    return res
end
function getoptions(x::T) where T
    res = Any[]
    !isstructtype(T) && return res
    for pn in propertynames(x)
        try
            push!(res, (pn, getproperty(x, pn)))
        catch e
            # println("error")
        end
    end
    return res
end
function getoptions(x::DataType)
    if isabstracttype(x)
        return ["" => st for st in subtypes(x) if st !== Any]
    end
    res = Any[]
    x <: Tuple && return res
    if x.name === Base.NamedTuple_typename && !(x.parameters[1] isa Tuple)
        # named tuple type with unknown field names
        return res
    end
    fields = fieldnames(x)
    fieldtypes = Base.datatype_fieldtypes(x)
    for i in eachindex(fields)
        try
            push!(res, (fields[i], fieldtypes[i]))
        catch e
            println("error")
        end
    end
    return res
end
function getoptions(x::AbstractArray)
    res = Any[]
    for i in eachindex(x)
        try
            push!(res, (i, x[i]))
        catch e
            # println("error")
        end
    end
    return res
    [(i, x[i]) for i in eachindex(x)]
end
function getoptions(x::AbstractDict{<:S, T}) where {S<:Union{AbstractString, Symbol, Number},T}
    [(k,v) for (k,v) in x]
end
function getoptions(x::AbstractDict)
    res = Any[]
    for (k,v) in x
        push!(res, :k => k)
        push!(res, " v" => v)
    end
    return res
end
function getoptions(x::AbstractSet)
    res = Any[]
    for v in x
        push!(res, "" => v)
    end
    return res
end

iscorejunk(x) = parentmodule(parentmodule(parentmodule(x))) === Core && !isabstracttype(x) && isstructtype(x)

shouldrecurse(x, len) = len < 30
shouldrecurse(x) = shouldrecurse(x, 5)
shouldrecurse(::Module, len) = false
shouldrecurse(::Method, len) = false
shouldrecurse(::TypeVar, len) = false
shouldrecurse(x::DataType, len) = x !== Any && x !== Function && !iscorejunk(x)
shouldrecurse(::Union, len) = false

foldobject(x) = false
foldobject(::AbstractArray) = true
foldobject(x::AbstractVector{Any}) = length(x) > 5
foldobject(::UnitRange) = true
foldobject(x::Number) = isstructtype(typeof(x))
foldobject(x::DataType) = !isabstracttype(x) && isstructtype(x) && shouldrecurse(x)
foldobject(x::UnionAll) = true

function keypress(menu::TreeMenu, i::UInt32) 
    if i == Int('r')            
        node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
        menu.chosen = true          
        return true
    elseif i == Int('l') || i == Int(TerminalMenus.ARROW_RIGHT)
        node = FoldingTrees.setcurrent!(menu, menu.cursoridx)               
        node.foldchildren = false                 
        menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
    elseif i == Int('h') || i == Int(TerminalMenus.ARROW_LEFT)
        node = FoldingTrees.setcurrent!(menu, menu.cursoridx)               
        node.foldchildren = true && isstructtype(typeof(node.data.obj)) && shouldrecurse(node.data.obj)
        menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
    elseif i == Int('f')
        node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
        o = node.data.obj
        if isstructtype(typeof(o))
            node.children = Node[]
            node.data.showfields[] = !node.data.showfields[]
            treelist(o, parent = node) 
            node.foldchildren = false
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        end
    elseif i == Int('d')
        term = default_terminal()
        REPL.Terminals.clear(term)
        node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
        show(doc(node.data.obj))
        return true
    elseif i == Int('o')
        term = default_terminal()
        REPL.Terminals.clear(term)
        node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
        choice = eye(node.data.obj, 2)
        menu.chosen = choice !== nothing          
        return true
    elseif i == Int('t')
        term = default_terminal()
        REPL.Terminals.clear(term)
        node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
        choice = eye(typeof(node.data.obj), 2)
        menu.chosen = choice !== nothing          
        return true
    end                                                        
    return false
end


end
