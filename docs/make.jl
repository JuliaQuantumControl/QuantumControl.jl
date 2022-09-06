using QuantumPropagators
using QuantumControlBase
using Krotov
using GRAPE
using QuantumControl
using QuantumControl.Shapes
using QuantumControl.Functionals
using QuantumControl.Controls
using Pkg
using Documenter

DocMeta.setdocmeta!(QuantumControl, :DocTestSetup, :(using QuantumControl); recursive=true)

PROJECT_TOML = Pkg.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
VERSION = PROJECT_TOML["version"]
NAME = PROJECT_TOML["name"]
AUTHORS = join(PROJECT_TOML["authors"], ", ") * " and contributors"
GITHUB = "https://github.com/JuliaQuantumControl/QuantumControl.jl"

println("Starting makedocs")

include("generate_api.jl")

makedocs(;
    authors=AUTHORS,
    sitename="QuantumControl.jl",
    format=Documenter.HTML(;
        prettyurls=true,
        canonical="https://juliaquantumcontrol.github.io/QuantumControl.jl",
        assets=["assets/custom.css"],
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
            "Subpackages" => [
                "QuantumPropagators" => "api/quantum_propagators.md",
                "QuantumControlBase" => "api/quantum_control_base.md",
                "Krotov" => "api/krotov.md",
                "GRAPE" => "api/grape.md",
            ],
        ],
        "History" => "history.md",
    ]
)

println("Finished makedocs")

deploydocs(; repo="github.com/JuliaQuantumControl/QuantumControl.jl")
