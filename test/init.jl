# init file for "make devrepl"
using Revise
using Plots
unicodeplots()
using JuliaFormatter
using QuantumControlBase.TestUtils: test
using LiveServer: LiveServer, serve, servedocs as _servedocs
include(joinpath(@__DIR__, "clean.jl"))

servedocs(; kwargs...) = _servedocs(; skip_dirs=["docs/src/api"], kwargs...)

println("""
*******************************************************************************
DEVELOPMENT REPL

Revise, JuliaFormatter, LiveServer, Plots with unicode backend are active.

* `include("test/runtests.jl")` – Run the entire test suite
* `test()` – Run the entire test suite in a subprocess with coverage
* `test(genhtml=true)` – Generate an HTML coverage report
* `include("docs/make.jl")` – Generate the documentation
* `format(".")` – Apply code formatting to all files
* `servedocs([port=8000, verbose=false])` –
  Build and serve the documentation. Automatically recompile and redisplay on
  changes
* `clean()` – Clean up build/doc/testing artifacts
* `distclean()` – Restore to a clean checkout state
*******************************************************************************
""")
