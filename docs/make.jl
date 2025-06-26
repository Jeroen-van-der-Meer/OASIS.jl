using Documenter
using OasisTools
using Makie

makedocs(
    sitename = "OasisTools",
    pages = Any[
        "Overview" => "index.md",
        "Docstrings" => "docstrings.md"
    ],
    modules = [
        OasisTools, Base.get_extension(OasisTools, :OasisPlots)
    ],
)

deploydocs(repo = "github.com/Jeroen-van-der-Meer/OasisTools.jl.git")