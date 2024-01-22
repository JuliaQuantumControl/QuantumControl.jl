using QuantumPropagators
using QuantumControlBase
using Krotov
using GRAPE
using QuantumControl
using QuantumControl.Shapes
using QuantumControl.Functionals
using QuantumControl.Generators
using Documenter
using DocumenterCitations
using DocumenterInterLinks
using Pkg

PROJECT_TOML = Pkg.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
VERSION = PROJECT_TOML["version"]
NAME = PROJECT_TOML["name"]
AUTHORS = join(PROJECT_TOML["authors"], ", ") * " and contributors"
GITHUB = "https://github.com/JuliaQuantumControl/QuantumControl.jl"

DEV_OR_STABLE = "stable/"
if endswith(VERSION, "dev")
    DEV_OR_STABLE = "dev/"
end

links = InterLinks(
    "TimerOutputs" => (
        "https://github.com/KristofferC/TimerOutputs.jl",
        joinpath(@__DIR__, "src", "inventories", "TimerOutputs.toml")
    ),
    "QuantumPropagators" => "https://juliaquantumcontrol.github.io/QuantumPropagators.jl/$DEV_OR_STABLE",
    "QuantumGradientGenerators" => "https://juliaquantumcontrol.github.io/QuantumGradientGenerators.jl/$DEV_OR_STABLE",
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
        footer="[$NAME.jl]($GITHUB) v$VERSION docs powered by [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl)."
    ),
    pages=[
        "Home" => "index.md",
        "Glossary" => "glossary.md",
        "User Manual" => "manual.md",
        "Howto" => "howto.md",
        "Examples" => ["List of Examples" => "examples/index.md",],
        "API" => [
            "QuantumControl" => "api/quantum_control.md",
            "Local Submodules" => "api/quantum_control_reference.md",
            "Subpackages" => [
                "QuantumPropagators" => "api/quantum_propagators.md",
                "QuantumControlBase" => "api/quantum_control_base.md",
                "Krotov" => "api/krotov.md",
                "GRAPE" => "api/grape.md",
            ],
            "Index" => "api/quantum_control_index.md",
        ],
        "References" => "references.md",
    ]
)

println("Finished makedocs")

deploydocs(; repo="github.com/JuliaQuantumControl/QuantumControl.jl")
