module Eyeball

Base.Experimental.@compiler_options compile=min optimize=1

using Base.Docs

using InteractiveUtils
using REPL: REPL, AbstractTerminal

using REPL.TerminalMenus
import REPL.TerminalMenus: request
using AbstractTrees

import TerminalPager

# TODO: de-vendor once changes are upstreamed.
include("vendor/FoldingTrees/src/FoldingTrees.jl")
using .FoldingTrees

# include("ui.jl")

export eye


default_terminal() = REPL.LineEdit.terminal(Base.active_repl)
"""
Explore objects and types.
```
eye(x = Main, depth = 10; interactive = true)
```
`depth` controls the depth of folding.
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
* `0`-`9` -- Fold to depth.
* `enter` -- Return the object.
* `q` -- Quit.
"""
function eye(x = Main, depth = 10; interactive = true)
    cursor = Ref(1)
    returnfun = x -> x.data.value
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
                    child.foldchildren = foldobject(child.data.value)                 
                end
            end
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        elseif i == Int('h') || i == Int(TerminalMenus.ARROW_LEFT)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)               
            node.foldchildren = has_children(node)
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        elseif i == Int('f')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            o = node.data.value
            if isstructtype(typeof(o))
                node.children = Node[]
                node.data.showfields[] = !node.data.showfields[]
                treelist(o, 8, node) 
                node.foldchildren = false
                menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
            end
        elseif i == Int('d')
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            _pager(getdoc(node.data.value))
            resetterm()
        elseif i == Int('m')
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            o = node.data.value
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
            o = node.data.value
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
            newchoice = eye(node.data.value)
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
            show(io, MIME"text/plain"(), node.data.value)
            sobj = String(take!(io.io))
            _pager(node.data.value)
            resetterm()
        elseif i == Int('t')
            REPL.Terminals.clear(term)
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            choice = eye(typeof(node.data.value))
            resetterm()
        elseif i in Int.('0':'9')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            fold!(node, i - 48)
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        end                                                        
        return false
    end

    root = treelist(x, depth - 1)
    if interactive
        term = default_terminal()
        while true
            menu = TreeMenu(root, pagesize = REPL.displaysize(term)[1] - 2, dynamic = true, keypress = keypress)
            choice = TerminalMenus.request(term, "[f] fields [d] docs [m/M] methodswith [o] open [r] tree [s] show [t] typeof [q] quit", menu; cursor=cursor)
            choice !== nothing && return returnfun(choice)
            if redo
                redo = false
                root = treelist(x, depth - 1)
            else 
                return
            end
        end
    else
        menu = TreeMenu(root, pagesize = 20, dynamic = true, maxsize = 30, keypress = keypress)
        return root
    end
end

struct ObjectWrapper{K,V}
    key::K
    value::V
    showfields::Base.RefValue{Bool}
    ObjectWrapper{K,V}(key, value) where {K,V} = new(key, value, Ref(false))
end

Base.show(io::IO, x::ObjectWrapper) = print(io, tostring(x.key, x.value))


getdoc(x) = doc(x)
getdoc(x::Method) = doc(x.module.eval(x.name))

has_children(x) = length(x.children) > 0

function fold!(node, depth)
    if depth == 0
        node.foldchildren = has_children(node)
    else
        if foldobject(node.data.value)
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


function treelist(x, depth = 0, parent = Node{ObjectWrapper}(ObjectWrapper{String,typeof(x)}("", x)), history = Base.IdSet{Any}((x,)))
    usefields = parent.data.showfields[] && isstructtype(typeof(x)) && !(x isa DataType) 
    keys, values = usefields ? getfields(x) : getoptions(x)
    for idx in eachindex(keys)
        if isassigned(values, idx)
            k = keys[idx]
            v = values[idx]
            node = Node{ObjectWrapper}(ObjectWrapper{typeof(k),typeof(v)}(k, v), 
                        parent, 
                        foldobject(v) || (depth < 1 && shouldrecurse(v)))
            if depth > -20 && v ∉ history && shouldrecurse(v)
                treelist(v, depth - 1, node, push!(copy(history), v))
            end
            if !has_children(node)
                node.foldchildren = false
            end
        end
    end
    return parent
end

function FoldingTrees.writeoption(buf::IO, obj::ObjectWrapper, charsused::Int; width::Int=(displaysize(stdout)::Tuple{Int,Int})[2])
    FoldingTrees.writeoption(buf, tostring(obj.key, obj.value), charsused; width=width)
end

function _pager(object)
     buffer = IOBuffer()
     ctx = IOContext(buffer, :color => true)
     show(ctx, "text/plain", object)
     TerminalPager.pager(String(take!(buffer)))
end

############################
#  API functions
############################

"""
```
tostring(pn, obj)
```
Returns a string with the text representation of `obj` with key `pn`.
"""
function tostring(key, obj)
    io = IOContext(IOBuffer(), :compact => true, :limit => true, :color => true)
    show(io, obj)
    sobj = String(take!(io.io))
    string(style(string(key), color = :cyan), ": ", 
           style(string(typeof(obj)), color = :green), " ", 
           extras(obj), " ", 
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
extras(x::AbstractArray) = style(string(size(x)), color = :magenta) * " " * style(string(sizeof(x)), color = :yellow)

"""
```
getfields(x)
```
Return a tuple of two arrays describing the child objects to be shown for `x`. 
The first array has the field names of `x`, and the second array has the fields.
Normally, this should not have a custom definition for a type.
Use `getoptions` for that.
"""
function getfields(x::T) where T
    !isstructtype(T) && return (Symbol[], Any[])
    keys = [fn for fn in fieldnames(typeof(x)) if isdefined(x, fn)]
    values = [getfield(x, fn) for fn in keys]
    return (keys, values)
end

"""
```
getoptions(x)
```
Return a tuple of two arrays describing the child objects to be shown for `x`. 
The first array has the keys or indexes of the child objects, and the second array is the child objects.
"""
function getoptions(x::T) where T
    keys = propertynames(x)
    values = [getproperty(x, pn) for pn in keys]
    return (keys, values)
end
function getoptions(x::DataType)
    if isabstracttype(x)
        st = filter(t -> t !== Any, subtypes(x))
        return (fill(Symbol(""), length(st)), st)
    end
    empty = (Symbol[], Any[])
    x <: Tuple && return empty
    if x.name === Base.NamedTuple_typename && !(x.parameters[1] isa Tuple)
        # named tuple type with unknown field names
        return empty
    end
    fields = fieldnames(x)
    fieldtypes = Base.datatype_fieldtypes(x)
    return (fields, fieldtypes)
end
function getoptions(x::AbstractArray{T}) where T
    keys = 1:min(100, length(x))
    return (keys, x)
end
function getoptions(x::AbstractDict{<:S, T}) where {S<:Union{AbstractString, Symbol, Number},T}
    return (collect(keys(x)), collect(values(x)))
end
function getoptions(x::AbstractDict) 
    keys = repeat([:k, Symbol("_v")], outer = length(x)) 
    values = Any[] 
    for (k,v) in x
        push!(values, k)
        push!(values, v)
    end
    return (keys, values)
end
function getoptions(x::AbstractSet{T}) where T
    values = collect(x)
    keys = fill(Symbol(""), length(values))
    return (keys, values)
end

iscorejunk(x) = parentmodule(parentmodule(parentmodule(x))) === Core && !isabstracttype(x) && isstructtype(x)

"""
```
shouldrecurse(x)
```
A boolean that controls whether eye recurses into object `x`. 
`len` is the length of the object. 
This defaults to true.
"""
shouldrecurse(x) = true
shouldrecurse(::Module) = false
shouldrecurse(::Method) = false
shouldrecurse(::TypeVar) = false
shouldrecurse(x::DataType) = x !== Any && x !== Function && !iscorejunk(x)
shouldrecurse(::Union) = false

"""
```
foldobject(x)
```
A boolean that controls whether `eye` automatically folds `x`. 
This is useful for types where the components are usually not needed. 
This defaults to false.
"""
foldobject(x) = false
foldobject(x::AbstractArray) = true
foldobject(x::AbstractVector{Any}) = length(x) > 5
foldobject(::UnitRange) = true
foldobject(x::Number) = true
foldobject(x::DataType) = !isabstracttype(x) && isstructtype(x)
foldobject(x::UnionAll) = true

end
