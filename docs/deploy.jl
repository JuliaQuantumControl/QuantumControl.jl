# SPDX-FileCopyrightText: © 2026 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT OR CC0-1.0

# Deploy the documentation built by `docs/make.jl` to the `gh-pages` branch.
#
# This runs in the `docs-deploy` job of the CI workflow, separately from the
# build, so that the code executed while building the documentation never has
# access to a token with write permissions. Only Documenter is installed, in
# the version from the `docs/Manifest.toml` of the build.

import Pkg

MANIFEST = Pkg.TOML.parsefile(joinpath(@__DIR__, "Manifest.toml"))
DOCUMENTER_VERSION = VersionNumber(only(MANIFEST["deps"]["Documenter"])["version"])

Pkg.activate(; temp = true)
Pkg.add(Pkg.PackageSpec(name = "Documenter", version = DOCUMENTER_VERSION))

using Documenter

deploydocs(;
    root = @__DIR__,
    target = "build",
    repo = "github.com/JuliaQuantumControl/QuantumControl.jl",
    push_preview = true
)
