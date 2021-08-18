using TypeDBClient_Speed
using Documenter

DocMeta.setdocmeta!(TypeDBClient_Speed, :DocTestSetup, :(using TypeDBClient_Speed); recursive=true)

makedocs(;
    modules=[TypeDBClient_Speed],
    authors="Frank Urbach",
    repo="https://GitHub.com/FrankUrbach/TypeDBClient_Speed.jl/blob/{commit}{path}#{line}",
    sitename="TypeDBClient_Speed.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://FrankUrbach.github.io/TypeDBClient_Speed.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="GitHub.com/FrankUrbach/TypeDBClient_Speed.jl",
)
