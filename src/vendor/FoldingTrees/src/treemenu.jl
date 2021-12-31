# This file is loaded conditionally for supported versions of Julia

export TreeMenu

mutable struct TreeMenu{N<:Node} <: TerminalMenus._ConfiguredMenu{TerminalMenus.Config}
    root::N
    current::N
    currentidx::Int
    currentdepth::Int
    cursoridx::Int
    chosen::Bool   # when true, indicates that `current` was chosen by user
    # Needed by REPL.TerminalMenus
    pagesize::Int
    dynamic::Bool
    maxsize::Int
    pageoffset::Int
    keypress::Any
    config::TerminalMenus.Config
end
function TreeMenu(root; pagesize::Int=10, dynamic = false, maxsize = pagesize, keypress = (m,i) -> false, kwargs...)
    pagesize = min(pagesize, count_open_leaves(root))
    return TreeMenu(root, root, 1, 1, 1, false, pagesize, dynamic, maxsize, 0, keypress, TerminalMenus.Config(kwargs...))
end

"""
    writeoption(buf::IO, data, charsused::Int; width::Int=displaysize(stdout)[2])

Print `data` to `buf` as a menu option. `charsused` is the number of characters already printed on that line.
`width` allows you to specify the display width (in characters), which defaults to the width of the terminal window.

Given a tree built from `Node{Data}`, packages implementing a `TreeMenu` may need to implement
`writeoption(buf, data::Data, charsused)`.

The implementation for `data::AbstractString` is careful to ensure that the option does not wrap to a new
line of the terminal, and to ensure that any color printing is turned off even when the line has to be truncated.
"""
function writeoption(buf::IO, str::AbstractString, charsused::Int; width::Int=(displaysize(stdout)::Tuple{Int,Int})[2])
    function print_escape_code(buf, str, idx)
        idxe = nextind(str, idx)
        c = str[idxe]
        if c == '['
            idxe = nextind(str, idxe)
            while true
                c = str[idxe]
                if '0' <= c <= '9' || c == ';'
                    idxe = nextind(str, idxe)
                elseif c == 'm'
                    # This is the end of a mode-setting code. Render it without counting it against the char count.
                    print(buf, str[idx:idxe])
                    idx = nextind(str, idxe)
                    break
                else
                    error("terminal escape code ", escape_string(str[idx:idxe]), " not supported")
                end
            end
            return idx
        end
        error("terminal escape code ", escape_string(str[idx:idxe]), " not supported")
    end

    nchars = width - charsused
    idx, k = 1, 0
    idxend = lastindex(str)
    while k < nchars && idx <= idxend
        c = str[idx]
        if c == '\n' || c == '\r'
            idx = nextind(str, idx) # don't print `\n` or `\r`, but also don't count against total
            continue
        elseif c == '\e' # ANSI terminal escape code
            idx = print_escape_code(buf, str, idx)
        else
            print(buf, c)
            idx, k = nextind(str, idx), k+1
        end
    end
    if idx <= idxend
        # Print all the remaining escape codes, to set the state correctly for the next commands
        idx = nextind(str, idx)
        while idx <= idxend
            c = str[idx]
            if c == '\e'
                idx = print_escape_code(buf, str, idx)
            else
                idx = nextind(str, idx)
            end
        end
    end
    return nothing
end

function writeoption(buf::IO, data, charsused::Int; kwargs...)
    io = IOBuffer()
    show(io, data)
    writeoption(buf, String(take!(io)), charsused; kwargs...)
end

# AbstractMenu API
function TerminalMenus.pick(menu::TreeMenu, cursor::Int)
    setcurrent!(menu, cursor)
    menu.chosen = true
    return true
end

TerminalMenus.cancel(menu::TreeMenu) = menu.chosen = false

TerminalMenus.numoptions(menu::TreeMenu) = count_open_leaves(menu.root)

function TerminalMenus.writeline(buf::IOBuffer, menu::TreeMenu, idx::Int, cursor::Bool)
    node = setcurrent!(menu, idx)
    if cursor
        menu.cursoridx = idx
    end
    node.foldchildren ? print(buf, "+") : print(buf, " ")
    print(buf, " "^menu.currentdepth)
    writeoption(buf, node.data, menu.currentdepth+4)
end

function TerminalMenus.keypress(menu::TreeMenu, i::UInt32)
    if i == Int(' ')
        node = setcurrent!(menu, menu.cursoridx)
        node.foldchildren = !node.foldchildren
        if menu.dynamic
            menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        end
    end
    return menu.keypress(menu, i)
end

function TerminalMenus.selected(menu::TreeMenu)
    menu.chosen || return nothing
    return menu.current
end

# Internals

function setcurrent!(menu::TreeMenu, idx::Int)
    node, depth = menu.current, menu.currentdepth
    Δidx = idx - menu.currentidx
    while Δidx > 0
        node, depth = next(node, depth)
        Δidx -= 1
    end
    while Δidx < 0
        node, depth = prev(node, depth)
        Δidx += 1
    end
    menu.current = node
    menu.currentdepth = depth
    menu.currentidx = idx
    return node
end
