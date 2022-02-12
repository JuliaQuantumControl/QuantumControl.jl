# init file for "make devrepl"
using Revise
using Plots
unicodeplots()
using JuliaFormatter
using LiveServer: serve, servedocs as _servedocs

servedocs(; kwargs...) = _servedocs(; skip_dirs=["docs/src/api"], kwargs...)

println("""
*******************************************************************************
DEVELOPMENT REPL

Revise, JuliaFormatter, LiveServer, Plots with unicode backend are active.

* `include("test/runtests.jl")` – Run the entire test suite
* `include("docs/make.jl")` – Generate the documentation
* `format(".")` – Apply code formatting to all files
* `servedocs([port=8000, verbose=false])` –
  Build and serve the documentation. Automatically recompile and redisplay on
  changes
*******************************************************************************
""")
