mutable struct Node{Data}
    data::Data
    children::Vector{Node{Data}}
    foldchildren::Bool
    lastbranch::Bool   # used internally for working storage during `iterate`
    parent::Node{Data}

    """
        Node(data, foldchildren::Bool=false)

    Create the root of a folded tree. `data` holds the data associated with the root node,
    and `foldchildren` specifies whether its children are initially folded.
    """
    function Node{Data}(data, foldchildren::Bool=false) where Data
        new(data, Node[], foldchildren, false)
    end

    """
        Node(data, parent::Node, foldchildren::Bool=false)

    Add a new child node to `parent`. `data` holds the data associated with the child node,
    and `foldchildren` specifies whether its children are initially folded.
    """
    function Node{Data}(data, parent::Node{Data}, foldchildren::Bool=false) where Data
        child = new(data, Node[], foldchildren, false, parent)
        push!(parent.children, child)
        return child
    end
end

Node(data, foldchildren::Bool=false) = Node{typeof(data)}(data, foldchildren)
Node(data, parent::Node{Data}, foldchildren::Bool=false) where Data = Node{Data}(data, parent, foldchildren)

Base.eltype(::Type{Node{Data}}) where Data = Data
Base.IteratorSize(::Type{<:Node}) = Base.SizeUnknown()

"""
    isroot(node)

Return `true` if `node` is the root node (meaning, it has no parent).
"""
isroot(node::Node) = !isdefined(node, :parent)

"""
    toggle!(node)

Change the folding state of `node`. See also [`fold!`](@ref) and [`unfold!`](@ref).
"""
toggle!(node::Node) = (node.foldchildren = !node.foldchildren)

"""
    fold!(node)

Fold the children of `node`. See also [`unfold!`](@ref) and [`toggle!`](@ref).
"""
fold!(node::Node) = node.foldchildren = true

"""
    unfold!(node)

Unfold the children of `node`. See also [`fold!`](@ref) and [`toggle!`](@ref).
"""
unfold!(node::Node) = node.foldchildren = false

"""
    count_open_leaves(node)

Return the number of unfolded descendants of `node`.
"""
function count_open_leaves(node::Node, count::Int=0)
    count += 1    # count self
    if !node.foldchildren
        # count children (and their children...)
        for child in node.children
            count = count_open_leaves(child, count)
        end
    end
    return count
end

"""
    newnode, newdepth = next(node, depth::Int=0)

Return the next node in a depth-first search.
`depth` counts the number of levels below the root.
The parent is visited before any children.
"""
function next(node, depth::Int=0)
    if !node.foldchildren && !isempty(node.children)
        return first(node.children), depth+1
    end
    return upnext(node, depth)
end
function upnext(node, depth)
    # node.parent must be defined if we're calling this
    p = node.parent
    myidx = findfirst((==)(node), p.children)
    if myidx < length(p.children)
        return p.children[myidx+1], depth
    end
    return upnext(p, depth-1)
end

"""
    newnode, newdepth = prev(node, depth::Int=0)

Return the previous node in a depth-first search.
`depth` counts the number of levels below the root.

This traverses in the opposite direction as [`next`](@ref),
so last, deepest children are visited before their parents.
"""
function prev(node, depth::Int=0)
    p = node.parent
    myidx = findfirst((==)(node), p.children)
    if myidx > 1
        return lastchild(p.children[myidx-1], depth)
    end
    return p, depth-1
end
function lastchild(node, depth)
    if node.foldchildren || isempty(node.children)
        return node, depth
    end
    return lastchild(node.children[end], depth+1)
end

# During iteration, we mark each node as to whether it's on the terminal branch of all ancestors.
function Base.iterate(root::Node)
    root.lastbranch = true   # root has no ancestors so it is last by definition
    return root.data, (root, 0)
end

function Base.iterate(root::Node, state)
    node, depth = state
    lb = node.lastbranch
    thislb = node.foldchildren | isempty(node.children)
    (lb & thislb) && return nothing
    # We can use `next` safely because parents are visited before children,
    # so `lastbranch` is guaranteed to be set properly.
    node, depth = next(node, depth)
    p = node.parent
    node.lastbranch = p.lastbranch && node == p.children[end]
    return node.data, (node, depth)
end

struct NodeWrapper{N}
    node::N
end

function Base.iterate(rootw::NodeWrapper)
    root = rootw.node
    root.lastbranch = true   # root has no ancestors so it is last by definition
    return root, (root, 0)
end

function Base.iterate(rootw::NodeWrapper, state)
    node, depth = state
    lb = node.lastbranch
    thislb = node.foldchildren | isempty(node.children)
    (lb & thislb) && return nothing
    # We can use `next` safely because parents are visited before children,
    # so `lastbranch` is guaranteed to be set properly.
    node, depth = next(node, depth)
    p = node.parent
    node.lastbranch = p.lastbranch && node == p.children[end]
    return node, (node, depth)
end

"""
    itr = nodes(node)

Create an iterator `itr` that will return the nodes, rather than the node data.

# Example

```julia
julia> foreach(unfold!, nodes(root))
```

would ensure that each node in the tree is unfolded.
"""
nodes(node::Node) = NodeWrapper(node)
