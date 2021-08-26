# init file for "make devrepl"
using Pkg
Pkg.develop(PackageSpec(path=pwd()))
using Revise
println("""
*******************************************************************************
DEVELOPMENT REPL

Revise is active

Run

    include("test/runtests.jl")

for running the entire test suite.


Run

    include("docs/make.jl")

to generate the documentation
*******************************************************************************
""")
