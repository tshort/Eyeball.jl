using Eyeball
using Eyeball.FoldingTrees
using REPL
using REPL.TerminalMenus
using InteractiveUtils
using Test

# From REPL/test/TerminalMenus/dynamic_menu.jl
matchback(str) = match(r"\e\[(\d+)A", str)

# from https://github.com/JuliaCollections/FoldingTrees.jl/blob/e4d3c37b18a6ee2c3ad9a5049f6fcc4b79486886/test/runtests.jl#L47-L60
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

@testset "Basics" begin
    a = (h=zeros(5), e=:(5sin(pi*t)), f=sin, c=33im, set=Set((:a, 9, 1:5, 8)), b=(c=1,d=9,e=(i=9,f=0)), x=9 => 99:109, d=Dict(1=>2, 3=>4), ds=Dict(:s=>4,:t=>7), dm=Dict(1=>9, "x"=>8))
    root = eye(a, 1, interactive = false)
    @test count_open_leaves(root) == 11
    io = IOBuffer()
    foreach(unfold!, nodes(root))
    FoldingTrees.print_tree(io, root)
    s = String(take!(io))
    @test s[1:100] == "  : \e[32mNamedTuple{(:h, :e, :f, :c, :set, :b, :x, :d, :ds, :dm), Tuple{Vector{Float64}, Expr, typeo"
    root = eye(a, 2, interactive = false)
    @test count_open_leaves(root) == 30
    root = eye(a, interactive = false)
    @test count_open_leaves(root) == 44
end


@testset "TreeMenu" begin
    a = (h=zeros(5), e=:(5sin(pi*t)), f=sin, c=33im, set=Set((:a, 9, 1:5, 8)), b=(c=1,d=9,e=(i=9,f=0)), x=9 => 99:109, d=Dict(1=>2, 3=>4), ds=Dict(:s=>4,:t=>7), dm=Dict(1=>9, "x"=>8))
    root = eye(a, 1, interactive = false)
    menu = TreeMenu(root, pagesize = 20, dynamic = true, maxsize = 30)
    # menu = TreeMenu(root, pagesize = 20, dynamic = true, maxsize = 30, keypress = Eyeball.keypress)
    @test TerminalMenus.numoptions(menu) == 11
    io = IOBuffer()
    state = TerminalMenus.printmenu(io, menu, 2; init=true)
    str = String(take!(io))
    nback, lines = linesplitter(str)
    @test nback == 0
    @test lines[2] == " > +  \e[36mh\e[39m: \e[32mVector{Float64}\e[39m \e[35m(5,)\e[39m \e[33m40\e[39m [0.0, 0.0, 0.0, 0.0, 0.0]"
    @test lines[8] == "   +  \e[36mx\e[39m: \e[32mPair{Int64, UnitRange{Int64}}\e[39m  9=>99:109"
    @test length(lines) == 11
    menu.cursoridx = 11
    # TerminalMenus.keypress(menu, UInt32('f'))
    # @test TerminalMenus.numoptions(menu) == 19
    # node = FoldingTrees.setcurrent!(menu, menu.cursoridx) 
    # o = node.data.obj 
    # @test o isa Dict
end
