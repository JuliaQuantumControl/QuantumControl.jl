using QuantumPropagators
using QuantumControlBase
using Krotov
using GRAPE
using QuantumControl
using QuantumControl.Shapes
using QuantumControl.Functionals
using Documenter

DocMeta.setdocmeta!(QuantumControl, :DocTestSetup, :(using QuantumControl); recursive=true)
println("Starting makedocs")

include("generate_api.jl")

makedocs(;
    authors="Michael Goerz <mail@michaelgoerz.net>, Alastair Marshall <alastair@nvision-imaging.com>, and contributors",
    sitename="QuantumControl.jl",
    format=Documenter.HTML(;
        prettyurls=true,
        canonical="https://juliaquantumcontrol.github.io/QuantumControl.jl",
        assets = ["assets/custom.css"],
    ),
    pages=[
        "Home" => "index.md",
        "Glossary" => "glossary.md",
        "User Manual" => "manual.md",
        "Howto" => "howto.md",
        "API" => [
            "QuantumControl" => "api/quantum_control.md",
            "Subpackages" => [
                "QuantumPropagators" => "api/quantum_propagators.md",
                "QuantumControlBase" => "api/quantum_control_base.md",
                "Krotov" => "api/krotov.md",
                "GRAPE" => "api/grape.md",
            ],
         ],
    ],
)

println("Finished makedocs")

deploydocs(;
    repo="github.com/JuliaQuantumControl/QuantumControl.jl",
)
