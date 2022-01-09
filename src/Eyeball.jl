module Eyeball

Base.Experimental.@compiler_options compile=min optimize=1 # infer=false

using Base.Docs

using InteractiveUtils
using REPL: REPL, AbstractTerminal

using REPL.TerminalMenus
import REPL.TerminalMenus: request
using AbstractTrees

import TerminalPager
using Statistics


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
* `e` -- Expand. Show more subobjects.
* `f` -- Toggle fields. By default, parameters are shown for most objects.
  `f` toggles between the normal view and a view showing the fields of an object. 
* `m` -- Methodswith. Show methods available for objects of this type. `M` specifies `supertypes = true`.
* `o` -- Open. Open the object in a new tree view. `O` opens all (mainly useful for modules).
* `r` -- Return tree. Return the tree (a `FoldingTrees.Node`).
* `s` -- Show object.
* `t` -- Typeof. Show the type of the object in a new tree view.
* `z` -- Summarize. Toggle a summary of the object and child objects. 
  For arrays, this shows the mean and 0, 25, 50, 75, and 100% quantiles (skipping missings).
* `0`-`9` -- Fold to depth. Also toggles expansion of items normally left folded.
* `enter` -- Return the object.
* `q` -- Quit.
"""
function eye(x = Main, depth = 10; interactive = true, all = false)
    if all
        x = All(x)
    end
    cursor = Ref(1)
    returnfun = x -> x.data.value
    redo = false    
    foldctx = (cursoridx = 1, depth = depth, expandall = true)
    function resetterm() 
        println(term.out_stream)
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
            node.foldchildren = false                 
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
                treelist(o, 8, 16, node) 
                node.foldchildren = false
                menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
            end
        elseif i == Int('d')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            _pager(getdoc(node.data.value))
            resetterm()
        elseif i == Int('e')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            o = node.data.value
            n = length(node.children)
            if length(node.children) < 1 || !(node.children[1].data.value isa ExpandPlaceholder) 
                return false
            end
            placeholder = popfirst!(node.children)
            ctx = placeholder.data.value
            shown = length(node.children)  # double what's shown
            _iterate(ctx.itr, ctx.depth, shown, node, ctx.history) 
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        elseif i == Int('m')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            println(term.out_stream, "\n\nOpening methodswith(`$(node.data.key)`) ...\n")
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
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            println(term.out_stream, "\n\nOpening methodswith(`$(node.data.key)`, supertypes = true) ...\n")
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
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            println(term.out_stream, "\n\nOpening `$(node.data.key)` ...\n")
            newchoice = eye(node.data.value)
            resetterm()
            if newchoice !== nothing
                returnfun = x -> newchoice
                menu.chosen = true
                node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
                return true
            end
        elseif i == Int('O')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            println(term.out_stream, "\n\nOpening `$(node.data.key)` ...\n")
            newchoice = eye(All(node.data.value))
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
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            io = IOContext(IOBuffer(), :displaysize => displaysize(term), :limit => true, :color => true)
            show(io, MIME"text/plain"(), node.data.value)
            sobj = String(take!(io.io))
            _pager(node.data.value)
            resetterm()
        elseif i == Int('t')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            println(term.out_stream, "\n\nOpening typeof(`$(node.data.key)`) ...\n")
            choice = eye(typeof(node.data.value))
            resetterm()
        elseif i == Int('z')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            d = node.data
            d.summarize[] = !d.summarize[]
            if d.summarize[]
                d.string[] = tostring(d.key, Summarize(d.value))
            else
                d.string[] = tostring(d.key, d.value)
            end
            for n in node.children
                dc = n.data
                dc.summarize[] = d.summarize[]
                if dc.summarize[]
                    dc.string[] = tostring(dc.key, Summarize(dc.value))
                else
                    dc.string[] = tostring(dc.key, dc.value)
                end
            end
        elseif i in Int.('0':'9')
            node = FoldingTrees.setcurrent!(menu, menu.cursoridx)
            expandall = foldctx.cursoridx == menu.cursoridx && foldctx.depth == i && foldctx.expandall
            fold!(node, i - 48, expandall)
            foldctx = (cursoridx = menu.cursoridx, depth = i, expandall = !expandall)
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        end                                                        
        return false
    end
    shown = 50
    root = treelist(x, depth - 1, shown)
    if interactive
        term = default_terminal()
        while true
            menu = TreeMenu(root, pagesize = REPL.displaysize(term)[1] - 2, dynamic = true, keypress = keypress)
            choice = TerminalMenus.request(term, "[f] fields [d] docs [e] expand [m/M] methodswith [o] open [r] tree [s] show [t] typeof [z] summarize [q] quit", menu; cursor=cursor)
            choice !== nothing && return returnfun(choice)
            if redo
                redo = false
                root = treelist(x, depth - 1, shown)
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
    string::Base.RefValue{Union{Nothing,String}}
    showfields::Base.RefValue{Bool}
    summarize::Base.RefValue{Bool}
    ObjectWrapper{K,V}(key, value, string = Ref{Union{Nothing,String}}(nothing), showfields = Ref(false), summarize = Ref(false)) where {K,V} = 
        new(key, value, string, showfields, summarize
)
end

Base.show(io::IO, x::ObjectWrapper) = print(io, tostring(x.key, x.value))

struct UNDEFPlaceholder end
const UNDEF = UNDEFPlaceholder()

struct ExpandPlaceholder{T}
    itr::T
    depth::Int 
    shown::Int
    history
end

struct All{T}
    value
end
All(x) = All{typeof(x)}(x)

struct Summarize{T}
    value
end
Summarize(x) = Summarize{typeof(x)}(x)
function Base.show(io::IO, x::Summarize{<:AbstractArray{<:Real}})
    if eltype(x) >: Missing 
        #nm = nmissing(x)
        v = skipmissing(x.value)
    else
        v = x
    end
    print(io, "x̅=", mean(v), ", q=", quantile(v, [0, .25, 0.5, 0.75, 1]))
    # nm > 0 && print(io, ", nm=", nm)
    nothing
end
Base.show(io::IO, x::Summarize) = show(io, x.value)

getdoc(x) = doc(x)
getdoc(x::Method) = doc(x.module.eval(x.name))

has_children(x) = length(x.children) > 0

function fold!(node, depth, expandall)
    if depth == 0
        node.foldchildren = has_children(node)
    else
        if foldobject(node.data.value) && !expandall
            node.foldchildren = has_children(node)
        else
            node.foldchildren = false
            for child in AbstractTrees.children(node)
                fold!(child, depth - 1, expandall)
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


struct UndefIterator{T}
    x::T
end
Base.iterate(a::UndefIterator, state = 1) = (isassigned(a.x, state) ? a.x[state] : UNDEF, state + 1)
Base.length(a::UndefIterator) = length(a.x)
undefiterator(x) = x
undefiterator(x::AbstractArray) = UndefIterator(x)

function treelist(x, depth = 0, shown = 10, parent = Node{ObjectWrapper}(ObjectWrapper{String,typeof(x)}("", x)), history = Base.IdSet{Any}((x,)))
    usefields = parent.data.showfields[] && isstructtype(typeof(x)) && !(x isa DataType) 
    itr = Iterators.Stateful(usefields ? getfields(x) : getoptions(x))
    _iterate(itr, depth, shown, parent, history)
    # parent.itr[] = itr
    return parent
end

function _iterate(itr, depth, shown, parent, history)
    for (k,v) in Iterators.take(itr, shown)
        node = Node{ObjectWrapper}(ObjectWrapper{typeof(k),typeof(v)}(k, v), 
                    parent, 
                    foldobject(v) || (depth < 1 && shouldrecurse(v)))
        if depth > -20 && v ∉ history && shouldrecurse(v)
            treelist(v, depth - 1, 10, node, push!(copy(history), v))
        end
        if !has_children(node)
            node.foldchildren = false
        end
    end
    if 0 < length(itr) < 4
        _iterate(itr, depth, shown, parent, history)
    end
    if length(itr) > 0
        marker = Node{ObjectWrapper}(ObjectWrapper{Symbol,ExpandPlaceholder}(:!, ExpandPlaceholder(itr, depth, shown, history)))
        marker.parent = parent
        pushfirst!(parent.children, marker)
    end
end

function FoldingTrees.writeoption(buf::IO, obj::ObjectWrapper, charsused::Int; width::Int=(displaysize(stdout)::Tuple{Int,Int})[2])
    if obj.string[] == nothing 
        obj.string[] = tostring(obj.key, obj.value)
    end 
    FoldingTrees.writeoption(buf, obj.string[], charsused; width=width)
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
function tostring(key, value)
    io = IOContext(IOBuffer(), :compact => true, :limit => true, :color => true)
    show(io, value)
    svalue = String(take!(io.io))
    string(style(string(key), color = :cyan), ": ", 
           style(string(typeof(value)), color = :green), " ", 
           extras(value), " ", 
           svalue)
end

function tostring(key, value::UNDEFPlaceholder)
    string(style(string(key), color = :cyan), ": #undef")
end
tostring(key, x::Summarize{<:UNDEFPlaceholder}) = tostring(key, x.value)

function tostring(key, value::ExpandPlaceholder)
    N = length(value.itr.itr)
    n = length(value.itr)
    string(style(string(key), color = :red), "   Showing items 1-", N-n, " of ", N, ". Items remaining=", n, ". Hit [e] to expand.")
end
tostring(key, x::Summarize{<:ExpandPlaceholder}) = tostring(key, x.value)

function tostring(key, x::Summarize)
    io = IOContext(IOBuffer(), :compact => true, :limit => true, :color => true)
    show(io, x)
    svalue = String(take!(io.io))
    string(style(string(key), color = :cyan), ": ", 
           style(string(typeof(x.value)), color = :green), " ", 
           extras(x.value), " ", 
           svalue)
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
    !isstructtype(T) && return nothing
    keys = fieldnames(typeof(x))
    values = (isdefined(x, i) ? getfield(x, i) : UNDEF for i in 1:length(keys))
    return zip(keys, values)
end

"""
```
getoptions(x)
```
Return a tuple of two arrays describing the child objects to be shown for `x`. 
The first array has the keys or indexes of the child objects, and the second array is the child objects.
"""
function getoptions(x)
    keys = propertynames(x)
    if keys === fieldnames(typeof(x))
        values = (isdefined(x, pn) ? getproperty(x, pn) : UNDEF for pn in keys)
    else
        values = (getproperty(x, pn) for pn in keys)
    end
    return zip(keys, values)
end
function getoptions(x::All)
    return getoptions(x.value)
end
function getoptions(x::All{Module})
    y = x.value
    keys = names(y, all = true)
    values = (isdefined(y, pn) ? getproperty(y, pn) : UNDEF for pn in keys)
    return zip(keys, values)
end
function getoptions(x::DataType)
    if isabstracttype(x)
        st = filter(t -> t !== Any, subtypes(x))
        return zip(Iterators.repeated(Symbol("")), st)
    end
    x <: Tuple && return nothing
    if x.name === Base.NamedTuple_typename && !(x.parameters[1] isa Tuple)
        # named tuple type with unknown field names
        return nothing
    end
    fields = fieldnames(x)
    fieldtypes = Base.datatype_fieldtypes(x)
    return zip(fields, fieldtypes)
end
function getoptions(x::AbstractArray{T}) where T
    return zip(eachindex(x), UndefIterator(x))
end
function getoptions(x::AbstractDict{<:S, T}) where {S<:Union{AbstractString, Symbol, Number},T}
    return x
end
function getoptions(x::AbstractDict) 
    keys = repeat([:k, Symbol("_v")], outer = length(x)) 
    values = Any[] 
    for (k,v) in x
        push!(values, k)
        push!(values, v)
    end
    return zip(keys, values)
end
function getoptions(x::AbstractSet{T}) where T
    return zip(Iterators.repeated(Symbol("")), x)
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
shouldrecurse(::Core.MethodInstance) = false
shouldrecurse(::TypeVar) = false
shouldrecurse(x::DataType) = x !== Any && x !== Function && !iscorejunk(x)
shouldrecurse(::Union) = false
shouldrecurse(::UNDEFPlaceholder) = false

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
foldobject(x::AbstractVector{Any}) = length(x) > 10
foldobject(::UnitRange) = true
foldobject(x::Number) = true
foldobject(x::DataType) = !isabstracttype(x) && isstructtype(x)
foldobject(x::UnionAll) = true

end
