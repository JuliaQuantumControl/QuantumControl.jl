using QuantumPropagators
using QuantumControlBase
using Krotov
using QuantumControl
using QuantumControl.shapes
using QuantumControl.functionals
using Documenter

DocMeta.setdocmeta!(QuantumControl, :DocTestSetup, :(using QuantumControl); recursive=true)
println("Starting makedocs")

makedocs(;
    modules=[QuantumPropagators, QuantumControlBase, QuantumControl, Krotov],
    checkdocs = :exports,
    authors="Michael Goerz <mail@michaelgoerz.net>, Alastair Marshall <alastair@nvision-imaging.com>, and contributors",
    repo="https://github.com/JuliaQuantumControl/QuantumControl.jl/blob/{commit}{path}#{line}",
    sitename="QuantumControl.jl",
    format=Documenter.HTML(;
        prettyurls=true,
        canonical="https://juliaquantumcontrol.github.io/QuantumControl.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "User Manual" => "manual.md",
        "Howto" => "howto.md",
        "API" => "api.md",
    ],
)

println("Finished makedocs")

deploydocs(;
    repo="github.com/JuliaQuantumControl/QuantumControl.jl",
)
