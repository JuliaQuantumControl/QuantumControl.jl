using QuantumControl
using Documenter

DocMeta.setdocmeta!(QuantumControl, :DocTestSetup, :(using QuantumControl); recursive=true)

makedocs(;
    modules=[QuantumControl],
    authors="Michael Goerz <mail@michaelgoerz.net>, Alastair Marshall <alastair@nvision-imaging.com>, and contributors",
    repo="https://github.com/quantumcontrol-jl/QuantumControl.jl/blob/{commit}{path}#{line}",
    sitename="QuantumControl.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://quantumcontrol-jl.github.io/QuantumControl.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/quantumcontrol-jl/QuantumControl.jl",
)
