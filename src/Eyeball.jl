module Eyeball

Base.Experimental.@compiler_options compile=min optimize=1

using Base.Docs

using InteractiveUtils
using REPL: REPL, AbstractTerminal

using REPL.TerminalMenus
import REPL.TerminalMenus: request
using AbstractTrees

# TODO: de-vendor once changes are upstreamed.
include("vendor/FoldingTrees/src/FoldingTrees.jl")
using .FoldingTrees

# include("ui.jl")

export eye


default_terminal() = REPL.LineEdit.terminal(Base.active_repl)
"""
Explore objects and types.
```
eye(x = Main, depth = 10; interactive = true, showsize = false)
```
`depth` controls the depth of folding. `showsize` controls whether the size of objects is shown.
`interactive` means browse the object `x` interactively. 
With `interactive` set to `false`, `eye` returns the tree as a `FoldingTrees.Node`.

During interactive browsing of the object tree, the following keys are available:

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
"""
function eye(x = Main, depth = 10; interactive = true, showsize = false)
    cursor = Ref(1)
    returnfun = x -> x.data.obj
    redo = false    
    function resetterm() 
        REPL.Terminals.clear(term)
        REPL.Terminals.raw!(term, true)
        print(term.out_stream, "\x1b[?25l")  # hide cursor
    end
    function keypress(menu::TreeMenu, i::UInt32) 
        if i == Int('j')
            cursor[] = TerminalMenus.move_down!(menu, cursor[])
        elseif i == Int('k')
            cursor[] = TerminalMenus.move_up!(menu, cursor[])
        elseif i == Int('l') || i == Int(TerminalMenus.ARROW_RIGHT)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)               
            if node.foldchildren
                node.foldchildren = false                 
            else
                for child in AbstractTrees.children(node)
                    child.foldchildren = foldobject(child.data.obj)                 
                end
            end
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        elseif i == Int('h') || i == Int(TerminalMenus.ARROW_LEFT)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)               
            node.foldchildren = has_children(node)
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
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            pager(getdoc(node.data.obj))
            resetterm()
        elseif i == Int('m')
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            o = node.data.obj
            newchoice = eye(methodswith(o isa DataType ? o : typeof(o)))
            resetterm()
            if newchoice !== nothing
                returnfun = x -> newchoice
                menu.chosen = true
                node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
                return true
            end
        elseif i == Int('M')
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            o = node.data.obj
            newchoice = eye(methodswith(o isa DataType ? o : typeof(o), supertypes = true))
            resetterm()
            if newchoice !== nothing
                returnfun = x -> newchoice
                menu.chosen = true
                node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
                return true
            end
        elseif i == Int('o')
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            newchoice = eye(node.data.obj)
            resetterm()
            if newchoice !== nothing
                returnfun = x -> newchoice
                menu.chosen = true
                node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
                return true
            end
        elseif i == Int('r')
            returnfun = identity
            menu.chosen = true
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            return true
        elseif i == Int('s')
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            io = IOContext(IOBuffer(), :displaysize => displaysize(term), :limit => true, :color => true)
            show(io, MIME"text/plain"(), node.data.obj)
            sobj = String(take!(io.io))
            pager((node.data.obj))
            resetterm()
        elseif i == Int('t')
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            choice = eye(typeof(node.data.obj))
            resetterm()
        elseif i == Int('z')
            showsize = !showsize
            redo = true
            return true
        elseif i in Int.('0':'9')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            fold!(node, i - 48)
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        end                                                        
        return false
    end

    root = treelist(x, depth = depth - 1, showsize = showsize)
    if interactive
        term = default_terminal()
        while true
            menu = TreeMenu(root, pagesize = REPL.displaysize(term)[1] - 2, dynamic = true, keypress = keypress)
            choice = TerminalMenus.request(term, "[f] fields [d] docs [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] size [q] quit", menu; cursor=cursor)
            choice !== nothing && return returnfun(choice)
            if redo
                redo = false
                root = treelist(x, depth = depth - 1, showsize = showsize)
            else 
                return
            end
        end
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

getdoc(x) = doc(x)
getdoc(x::Method) = doc(x.module.eval(x.name))

has_children(x) = length(x.children) > 0

function fold!(node, depth)
    if depth == 0
        node.foldchildren = has_children(node)
    else
        if foldobject(node.data.obj)
            node.foldchildren = has_children(node)
        else
            node.foldchildren = false
            for child in AbstractTrees.children(node)
                fold!(child, depth - 1)
            end 
        end 
    end 
end 

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


function treelist(x; depth = 0, parent = Node(ObjectWrapper(x, style(typeof(x), color = :yellow))), history = Base.IdSet{Any}((x,)), showsize = false)
    usefields = parent.data.showfields[] && isstructtype(typeof(x)) && !(x isa DataType) 
    opts = usefields ? getfields(x) : getoptions(x)
    for (pn, obj) in opts
        nprop = length(getoptions(obj)) 
        node = Node(ObjectWrapper(obj, tostring(pn, obj, showsize = showsize)), 
                    parent, 
                    foldobject(obj) || (depth < 1 && nprop > 0 && shouldrecurse(obj)))
        if nprop > 0 && depth > -20 && obj ∉ history && shouldrecurse(obj, nprop)
            treelist(obj, depth = depth - 1, parent = node, history = push!(copy(history), obj))
        end
        if !has_children(node)
            node.foldchildren = false
        end
    end
    return parent
end

function FoldingTrees.writeoption(buf::IO, obj::ObjectWrapper, charsused::Int; width::Int=(displaysize(stdout)::Tuple{Int,Int})[2])
    FoldingTrees.writeoption(buf, obj.str, charsused; width=width)
end

# adapted from: https://github.com/JuliaLang/julia/blob/7c8cbf68865c7a8080a43321c99e07224f614e69/stdlib/REPL/src/TerminalMenus/Pager.jl#L33-L42
function pager(terminal, object)
    lines, columns = displaysize(terminal)::Tuple{Int,Int}
    columns -= 3
    buffer = IOBuffer()
    ctx = IOContext(buffer, :color => REPL.Terminals.hascolor(terminal), :displaysize => (lines, columns))
    show(ctx, "text/plain", object)
    pager = Pager(String(take!(buffer)); pagesize = lines)
    return request(terminal, pager)
end
pager(object) = pager(TerminalMenus.terminal, object)

############################
#  API functions
############################

"""
```
tostring(pn, obj; showsize = false)
```
Returns a string with the text representation of `obj` with key `pn`.
`showsize` controls whether the size of the object is included.
"""
function tostring(pn, obj; showsize = false)
    io = IOContext(IOBuffer(), :compact => true, :limit => true, :color => true)
    show(io, obj)
    sobj = String(take!(io.io))
    string(style(pn, color = :cyan), ": ", 
           style(typeof(obj), color = :green), " ", 
           style(extras(obj), color = :magenta), " ", 
           showsize ? string(style(sizeof(obj), color = :yellow), " ") : "",
           sobj)
end


"""
```
extras(x) = ""
```
Returns a string with any extra information about `x`.
For AbstractArrays, this returns size information.
"""
extras(x) = ""
extras(x::AbstractArray) = string(size(x))

"""
```
getfields(x)
```
Return an array of Pairs describing the objects to be shown when fields are selected. 
The first component of the Pair is the key or index of the object, and the second component is the object.
Normally, this should not have a custom definition for a type.
Use `getoptions` for that.
"""
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

"""
```
getoptions(x)
```
Return an array of Pairs describing the child objects to be shown for `x`. 
The first component of the Pair is the key or index of the child object, and the second component is the child object.
"""
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
    length(x) > 500 && return []
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

"""
```
shouldrecurse(x, len = 5)
```
A boolean that controls whether eye recurses into object `x`. 
`len` is the length of the object. 
This defaults to true when `len < 30`.
"""
shouldrecurse(x, len = 5) = len < 30
shouldrecurse(::Module, len) = false
shouldrecurse(::Method, len) = false
shouldrecurse(::TypeVar, len) = false
shouldrecurse(x::DataType, len) = x !== Any && x !== Function && !iscorejunk(x)
shouldrecurse(::Union, len) = false

"""
```
foldobject(x)
```
A boolean that controls whether `eye` automatically folds `x`. 
This is useful for types where the components are usually not needed. 
This defaults to false.
"""
foldobject(x) = false
foldobject(x::AbstractArray) = length(x) <= 500
foldobject(x::AbstractVector{Any}) = length(x) > 5
foldobject(::UnitRange) = true
foldobject(x::Number) = isstructtype(typeof(x))
foldobject(x::DataType) = !isabstracttype(x) && isstructtype(x) && shouldrecurse(x)
foldobject(x::UnionAll) = true

end
