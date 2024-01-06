# Source this script as e.g.
#
#     include("PATH/TO/devrepl.jl")
#
# from *any* Julia REPL or run it as e.g.
#
#     julia -i --banner=no PATH/TO/devrepl.jl
#
# from anywhere. This will change the current working directory and
# activate/initialize the correct Julia environment for you.
#
# You may also run this in vscode to initialize a development REPL
#
using Pkg
using Downloads: download

ENV["GKSwstype"] = 100

cd(@__DIR__)
Pkg.activate("test")

function _instantiate()
    installorg_script = joinpath("..", "scripts", "installorg.jl")
    if !isfile(installorg_script)
        @warn "$(@__DIR__) should be inside the JuliaQuantumControl development environment. See https://github.com/JuliaQuantumControl/JuliaQuantumControl#readme"
        installorg_script = download(
            "https://raw.githubusercontent.com/JuliaQuantumControl/JuliaQuantumControl/master/scripts/installorg.jl",
        )
    end
    if !isfile(joinpath("..", ".JuliaFormatter.toml"))
        download(
            "https://raw.githubusercontent.com/JuliaQuantumControl/JuliaQuantumControl/master/.JuliaFormatter.toml",
            ".JuliaFormatter.toml"
        )
    end
    include(installorg_script)
    eval(:(installorg()))
end

if !isfile(joinpath("test", "Manifest.toml"))
    _instantiate()
end
include("test/init.jl")

# Disable link-checking in interactive REPL, since it is the slowest part
# of building the docs.
ENV["DOCUMENTER_CHECK_LINKS"] = "0"

if abspath(PROGRAM_FILE) == @__FILE__
    help()
end
