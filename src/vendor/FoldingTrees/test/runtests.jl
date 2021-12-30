using FoldingTrees
using REPL.TerminalMenus
using Test

function collectexposed(root)
    function collect!(lines, depths, node, depth)
        push!(lines, node.data)
        push!(depths, depth)
        if !node.foldchildren
            for child in node.children
                collect!(lines, depths, child, depth+1)
            end
        end
        return lines, depths
    end

    lines, depths = eltype(root)[], Int[]
    return collect!(lines, depths, root, 0)
end

function getroot(node)
    while !isroot(node)
        node = node.parent
    end
    return node
end

function checknext(node, depth, lines, depths)
    for i = 2:count_open_leaves(getroot(node))
        node, depth = next(node, depth)
        @test node.data == lines[i]
        @test depth == depths[i]
    end
end

function checkprev(node, depth, lines, depths)
    for i = count_open_leaves(getroot(node)):-1:2
        @test node.data == lines[i]
        @test depth == depths[i]
        node, depth = prev(node, depth)
    end
end

# From REPL/test/TerminalMenus/dynamic_menu.jl
matchback(str) = match(r"\e\[(\d+)A", str)

function linesplitter(str)
    strs = split(str, '\n')
    s1 = strs[1]
    m = matchback(s1)
    if m === nothing
        nback, startidx = 0, 1
    else
        nback = parse(Int, m.captures[1])
        startidx = m.offset+length(m.match)
    end
    strs[1] = s1[startidx:end]  # discard the portion that moves the terminal
    @test all(s->startswith(s, "\e[2K"), strs)
    return nback, replace.(map(s->s[5:end], strs), ('\r'=>"",))
end


@testset "FoldingTrees.jl" begin
    root = Node("")
    child1 = Node("1", root)
    child1a = Node("1a", child1)
    child1a1 = Node("1a1", child1a)
    child1b = Node("1b", child1)
    child1b1 = Node("1b1", child1b)
    child1b2 = Node("1b2", child1b)
    child2 = Node("2", root)
    child3 = Node("3", root)
    child3a = Node("3a", child3)
    child3b = Node("3b", child3)
    child3b1 = Node("3b1", child3b)
    child3c = Node("3c", child3)

    for folded in (false, true)
        # For child2, folding has no impact, so we can run the same tests
        child2.foldchildren = folded

        @test count_open_leaves(root) == 13
        @test count_open_leaves(child1) == 6
        @test count_open_leaves(child2) == 1
        @test count_open_leaves(child3) == 5

        lines, depths = collectexposed(root)
        @test collect(root) == lines
        @test collect(child1) == lines[2:7]
        @test collect(child2) == lines[8:8]
        @test collect(child3) == lines[9:end]
        checknext(root, 0, lines, depths)
        checkprev(child3c, 2, lines, depths)
    end

    child1b.foldchildren = true
    @test count_open_leaves(root) == 11
    @test count_open_leaves(child1) == 4
    @test count_open_leaves(child2) == 1
    @test count_open_leaves(child3) == 5
    lines, depths = collectexposed(root)
    @test collect(root) == lines
    @test collect(child1) == lines[2:5]
    @test collect(child2) == lines[6:6]
    @test collect(child3) == lines[7:end]
    checknext(root, 0, lines, depths)
    checkprev(child3c, 2, lines, depths)

    child1b.foldchildren = false
    child1a.foldchildren = true
    @test count_open_leaves(root) == 12
    @test count_open_leaves(child1) == 5
    @test count_open_leaves(child2) == 1
    @test count_open_leaves(child3) == 5
    lines, depths = collectexposed(root)
    @test collect(root) == lines
    @test collect(child1) == lines[2:6]
    @test collect(child2) == lines[7:7]
    @test collect(child3) == lines[8:end]
    checknext(root, 0, lines, depths)
    checkprev(child3c, 2, lines, depths)

    child3b.foldchildren = true
    @test count_open_leaves(root) == 11
    @test count_open_leaves(child1) == 5
    @test count_open_leaves(child2) == 1
    @test count_open_leaves(child3) == 4
    lines, depths = collectexposed(root)
    @test collect(root) == lines
    @test collect(child1) == lines[2:6]
    @test collect(child2) == lines[7:7]
    @test collect(child3) == lines[8:end]
    checknext(root, 0, lines, depths)
    checkprev(child3c, 2, lines, depths)

    io = IOBuffer()
    foreach(unfold!, nodes(root))
    FoldingTrees.print_tree(io, root)
    @test String(take!(io)) == "  \n├─   1\n│  ├─   1a\n│  │  └─   1a1\n│  └─   1b\n│     ├─   1b1\n│     └─   1b2\n├─   2\n└─   3\n   ├─   3a\n   ├─   3b\n   │  └─   3b1\n   └─   3c\n"
    fold!(child1b)
    FoldingTrees.print_tree(io, root)
    @test String(take!(io)) == "  \n├─   1\n│  ├─   1a\n│  │  └─   1a1\n│  └─ + 1b\n├─   2\n└─   3\n   ├─   3a\n   ├─   3b\n   │  └─   3b1\n   └─   3c\n"
    @test !toggle!(child1b)
end

if isdefined(FoldingTrees, :TreeMenu)
    @testset "TreeMenu" begin
        @testset "writeoption" begin
            buf = IOBuffer()
            str = "abcdefg"
            FoldingTrees.writeoption(buf, str, 0; width=10)
            @test String(take!(buf)) == str
            FoldingTrees.writeoption(buf, str, 0; width=3)
            @test String(take!(buf)) == "abc"
            FoldingTrees.writeoption(buf, str, 5; width=10)
            @test String(take!(buf)) == "abcde"
            FoldingTrees.writeoption(buf, "Once\n upon\n a time", 0; width=100)
            @test String(take!(buf)) == "Once upon a time"
            FoldingTrees.writeoption(buf, "Once\r\n upon\r\n a time", 0; width=100)
            @test String(take!(buf)) == "Once upon a time"
            printstyled(IOContext(buf, :color=>true), "This is a long string", color=:red)
            str = String(take!(buf))
            FoldingTrees.writeoption(buf, str, 0; width=100)
            @test String(take!(buf)) == str
            FoldingTrees.writeoption(buf, str, 0; width=10)
            @test String(take!(buf)) == "\e[31mThis is a \e[39m"
            @test_throws ErrorException("terminal escape code \\ex not supported") FoldingTrees.writeoption(buf, "This is \ex junk", 0; width=10)
            @test_throws ErrorException("terminal escape code \\e[x not supported") FoldingTrees.writeoption(buf, "This is \e[x junk", 0; width=10)

            # Fallback for writeoption
            take!(buf)
            FoldingTrees.writeoption(buf, 3.2, 0; width=10)
            @test String(take!(buf)) == "3.2"
        end

        root = Node("")
        child1 = Node("1", root)
        child1a = Node("1a", child1)
        child1a1 = Node("1a1", child1a)
        child1b = Node("1b", child1)
        child1b1 = Node("1b1", child1b)
        child1b2 = Node("1b2", child1b)
        child2 = Node("2", root)
        menu = TreeMenu(root)
        @test TerminalMenus.numoptions(menu) == 8
        io = IOBuffer()
        state = TerminalMenus.printmenu(io, menu, 2; init=true)
        str = String(take!(io))
        nback, lines = linesplitter(str)
        @test nback == 0
        @test lines[2] == " >    1"
        @test lines[3] == "       1a"
        @test lines[4] == "        1a1"
        @test lines[8] == "      2"
        @test length(lines) == 8

        menu.cursoridx = 3
        TerminalMenus.keypress(menu, UInt32(' '))
        @test TerminalMenus.numoptions(menu) == 7
        state = TerminalMenus.printmenu(io, menu, 2; oldstate=state)
        str = String(take!(io))
        nback, lines = linesplitter(str)
        @test nback == 7
        @test lines[2] == " >    1"
        @test lines[3] == "   +   1a"
        @test lines[4] == "       1b"
        @test lines[8] == "\e[1A"   # ANSI escape code for "move up"
        @test length(lines) == 8

        TerminalMenus.pick(menu, 4)
        @test TerminalMenus.selected(menu) == child1b
        TerminalMenus.cancel(menu)
        @test TerminalMenus.selected(menu) === nothing

        # Dynamic `pagesize` when (un)folding:
        foreach(unfold!, nodes(root))

        menu = TreeMenu(root; dynamic = true)
        state = TerminalMenus.printmenu(io, menu, 2; init = true)
        str = String(take!(io))
        nback, lines = linesplitter(str)
        @test nback == 0
        @test length(lines) == 8
        @test lines[2] == " >    1"
        @test menu.pagesize == 8

        # pagesize shrink
        TerminalMenus.keypress(menu, UInt32(' '))
        state = TerminalMenus.printmenu(io, menu, 2; init = true)
        str = String(take!(io))
        nback, lines = linesplitter(str)
        @test length(lines) == 3
        @test lines[2] == " > +  1"
        @test lines[3] == "      2"
        @test menu.pagesize == 3

        # pagesize regrow
        TerminalMenus.keypress(menu, UInt32(' '))
        state = TerminalMenus.printmenu(io, menu, 2; init = true)
        str = String(take!(io))
        nback, lines = linesplitter(str)
        @test length(lines) == 8
        @test lines[2] == " >    1"
        @test menu.pagesize == 8

        # Fold that the for the pagesize limiting tests next:
        TerminalMenus.keypress(menu, UInt32(' '))

        # `maxsize` limiting when unfolding:

        menu = TreeMenu(root; dynamic = true, maxsize = 5)
        state = TerminalMenus.printmenu(io, menu, 2; init = true)
        str = String(take!(io))
        nback, lines = linesplitter(str)
        @test nback == 0
        @test length(lines) == 3
        @test lines[2] == " > +  1"
        @test lines[3] == "      2"
        @test menu.pagesize == 3

        TerminalMenus.keypress(menu, UInt32(' '))
        state = TerminalMenus.printmenu(io, menu, 2; init = true)
        str = String(take!(io))
        nback, lines = linesplitter(str)
        @test nback == 0
        @test length(lines) == 5
        @test lines[5] == "v      1b"
        @test menu.pagesize == 5
    end
end
