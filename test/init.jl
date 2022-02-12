# init file for "make devrepl"
using Pkg
Pkg.develop(PackageSpec(path=pwd()))
using Revise
using Plots
unicodeplots()
using JuliaFormatter
println("""
*******************************************************************************
DEVELOPMENT REPL

Revise is active. JuliaFormatter is active.
Plots with unicode backend is active.

Run

    include("test/runtests.jl")

for running the entire test suite.


Run

    include("docs/make.jl")

to generate the documentation
*******************************************************************************
""")
