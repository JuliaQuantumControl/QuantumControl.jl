using Pkg

using Documenter
using QuantumPropagators
using QuantumControl
using QuantumControl.Shapes
using QuantumControl.Functionals
using QuantumControl.Generators
using Krotov
using GRAPE
import OrdinaryDiffEq  # ensure ODE extension is loaded
using Documenter.HTMLWriter: KaTeX
using DocumenterCitations
using DocumenterInterLinks


PROJECT_TOML = Pkg.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
VERSION = PROJECT_TOML["version"]
NAME = PROJECT_TOML["name"]
AUTHORS = join(PROJECT_TOML["authors"], ", ") * " and contributors"
GITHUB = "https://github.com/JuliaQuantumControl/QuantumControl.jl"

DEV_OR_STABLE = "stable/"
if endswith(VERSION, "dev")
    DEV_OR_STABLE = "dev/"
end

function org_inv(pkgname)
    objects_inv =
        joinpath(@__DIR__, "..", "..", "$pkgname.jl", "docs", "build", "objects.inv")
    if isfile(objects_inv)
        return ("https://juliaquantumcontrol.github.io/$pkgname.jl/dev/", objects_inv,)
    else
        return "https://juliaquantumcontrol.github.io/$pkgname.jl/$DEV_OR_STABLE"
    end
end

links = InterLinks(
    "Julia" => (
        "https://docs.julialang.org/en/v1/",
        "https://docs.julialang.org/en/v1/objects.inv",
        joinpath(@__DIR__, "src", "inventories", "Julia.toml"),
    ),
    "TimerOutputs" => (
        "https://github.com/KristofferC/TimerOutputs.jl",
        joinpath(@__DIR__, "src", "inventories", "TimerOutputs.toml")
    ),
    "Examples" => "https://juliaquantumcontrol.github.io/QuantumControlExamples.jl/$DEV_OR_STABLE",
    "Krotov" => org_inv("Krotov"),
    "GRAPE" => org_inv("GRAPE"),
    "QuantumPropagators" => org_inv("QuantumPropagators"),
    "QuantumGradientGenerators" => org_inv("QuantumGradientGenerators"),
    "ComponentArrays" => (
        "https://sciml.github.io/ComponentArrays.jl/stable/",
        "https://sciml.github.io/ComponentArrays.jl/stable/objects.inv",
        joinpath(@__DIR__, "src", "inventories", "ComponentArrays.toml")
    ),
    "RecursiveArrayTools" => (
        "https://docs.sciml.ai/RecursiveArrayTools/stable/",
        "https://docs.sciml.ai/RecursiveArrayTools/stable/objects.inv",
        joinpath(@__DIR__, "src", "inventories", "RecursiveArrayTools.toml")
    ),
    "DrWatson" => "https://juliadynamics.github.io/DrWatson.jl/stable/",
)

println("Starting makedocs")

include("generate_api.jl")

bib = CitationBibliography(joinpath(@__DIR__, "src", "refs.bib"); style=:numeric)

warnonly = [:linkcheck,]
if get(ENV, "DOCUMENTER_WARN_ONLY", "0") == "1"  # cf. test/init.jl
    warnonly = true
end

makedocs(;
    plugins=[bib, links],
    authors=AUTHORS,
    sitename="QuantumControl.jl",
    # Link checking is disabled in REPL, see `devrepl.jl`.
    linkcheck=(get(ENV, "DOCUMENTER_CHECK_LINKS", "1") != "0"),
    warnonly,
    doctest=false,  # doctests run as part of test suite
    format=Documenter.HTML(;
        prettyurls=true,
        canonical="https://juliaquantumcontrol.github.io/QuantumControl.jl",
        assets=[
            "assets/custom.css",
            "assets/citations.css",
            asset(
                "https://juliaquantumcontrol.github.io/QuantumControl.jl/dev/assets/topbar/topbar.css"
            ),
            asset(
                "https://juliaquantumcontrol.github.io/QuantumControl.jl/dev/assets/topbar/topbar.js"
            ),
        ],
        mathengine=KaTeX(
            Dict(
                :macros => Dict(
                    "\\Op" => "\\hat{#1}",
                    "\\ket" => "\\vert#1\\rangle",
                    "\\bra" => "\\langle#1\\vert",
                    "\\Im" => "\\operatorname{Im}",
                    "\\Re" => "\\operatorname{Re}",
                ),
            ),
        ),
        footer="[$NAME.jl]($GITHUB) v$VERSION docs powered by [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl).",
        size_threshold=1024 * 1024,
    ),
    pages=[
        "Home" => "index.md",
        "Glossary" => "glossary.md",
        "Overview" => "overview.md",
        "Control Methods" => "methods.md",
        "Howto" => "howto.md",
        "Examples" => "examples/index.md",
        "API" => [
            "QuantumControl" => "api/quantum_control.md",
            "Reference" => "api/reference.md",
            "Subpackages" => ["QuantumPropagators" => "api/quantum_propagators.md",],
            "Externals" => "api_externals.md",
            "Index" => "api/quantum_control_index.md",
        ],
        "References" => "references.md",
    ]
)

println("Finished makedocs")

deploydocs(; repo="github.com/JuliaQuantumControl/QuantumControl.jl")
