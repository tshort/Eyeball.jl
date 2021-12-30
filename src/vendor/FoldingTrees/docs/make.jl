using Documenter, FoldingTrees

makedocs(;
    modules=[FoldingTrees],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/JuliaCollections/FoldingTrees.jl/blob/{commit}{path}#L{line}",
    sitename="FoldingTrees.jl",
    authors="Tim Holy <tim.holy@gmail.com>",
    assets=String[],
)

deploydocs(;
    repo="github.com/JuliaCollections/FoldingTrees.jl",
)
