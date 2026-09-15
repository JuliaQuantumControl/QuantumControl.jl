# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT OR CC0-1.0

.PHONY: help test coverage htmlcoverage docs devrepl codestyle check-changelog changelog reuse clean distclean
.DEFAULT_GOAL := help

JULIA ?= julia

# The version of JuliaFormatter that the CI code style check uses
JULIAFORMATTER_VERSION := 2.3.0

ORG_URL := https://raw.githubusercontent.com/JuliaQuantumControl/JuliaQuantumControl/refs/heads/master

define PRINT_HELP_JLSCRIPT
rx = r"^([a-z0-9A-Z_-]+):.*?##[ ]+(.*)$$"
for line in eachline()
    m = match(rx, line)
    if !isnothing(m)
        target, help = m.captures
        println("$$(rpad(target, 20)) $$help")
    end
end
endef
export PRINT_HELP_JLSCRIPT

# Instantiate the environment given as the first argument
define INSTANTIATE_JLSCRIPT
import Pkg
env = ARGS[1]
if VERSION < v"1.11"
    # Julia 1.10 ignores `[sources]`, see CONTRIBUTING.md
    envcheck = joinpath("..", "scripts", "envcheck.jl")
    isfile(envcheck) || error(
        "On Julia $$VERSION, instantiating the `$$env` environment requires ../scripts/envcheck.jl from the JuliaQuantumControl development environment. See CONTRIBUTING.md."
    )
    run(`$$(Base.julia_cmd()) --startup-file=no $$envcheck apply-sources $$env`)
end
Pkg.activate(env)
Pkg.resolve()
Pkg.instantiate()
endef
export INSTANTIATE_JLSCRIPT

# Write lcov.info from the .cov files of a test run and show a summary. The
# coverage tools run in a temporary environment, so that they cannot restrict
# the versions of any package in the test environment.
define COVERAGE_JLSCRIPT
import Pkg
Pkg.activate(; temp = true, io = devnull)
Pkg.add(["CoverageTools", "LocalCoverage"]; io = devnull)
import CoverageTools
import LocalCoverage
folders = filter(isdir, ["src", "ext"])
coverage = reduce(vcat, [CoverageTools.process_folder(folder) for folder in folders])
CoverageTools.LCOV.writefile("lcov.info", coverage)
show(stdout, LocalCoverage.eval_coverage_metrics(coverage, pwd()))
println()
endef
export COVERAGE_JLSCRIPT

# Format all files with the JuliaFormatter version given as the first argument,
# in a temporary environment
define CODESTYLE_JLSCRIPT
import Pkg
Pkg.activate(; temp = true, io = devnull)
Pkg.add(Pkg.PackageSpec(; name = "JuliaFormatter", version = ARGS[1]); io = devnull)
import JuliaFormatter
JuliaFormatter.format("."; verbose = true)
endef
export CODESTYLE_JLSCRIPT

# Initialize the development REPL. The `docs` environment is stacked after the
# active `test` environment, and before the global environment that provides
# Revise. See CONTRIBUTING.md.
define DEVREPL_JLSCRIPT
insert!(LOAD_PATH, 2, abspath("docs"))
ENV["DOCUMENTER_CHECK_LINKS"] = "0"
import TOML
let
    # Report packages that are in more than one of the stacked environments with
    # different versions: only one of these versions can be loaded. For the
    # global environment, only Revise and its dependencies are relevant.
    function manifest_entries(env; roots = nothing)
        entries = Dict{String,Tuple{String,String}}()
        project_file = Base.env_project_file(env)
        (project_file isa String) || return entries
        manifest_file = Base.project_file_manifest_path(project_file)
        (isnothing(manifest_file) || !isfile(manifest_file)) && return entries
        deps = get(TOML.parsefile(manifest_file), "deps", Dict())
        names = isnothing(roots) ? Set(keys(deps)) : Set{String}()
        todo = isnothing(roots) ? String[] : filter(in(keys(deps)), roots)
        while !isempty(todo)
            name = pop!(todo)
            (name in names) && continue
            push!(names, name)
            for info in deps[name]
                depnames = get(info, "deps", String[])
                (depnames isa AbstractDict) && (depnames = collect(keys(depnames)))
                append!(todo, filter(in(keys(deps)), depnames))
            end
        end
        for name in names
            for info in deps[name]
                id = get(info, "git-tree-sha1", get(info, "path", ""))
                entries[info["uuid"]] = (name, "$$(get(info, "version", "")) $$id")
            end
        end
        return entries
    end
    entries = [
        "test" => manifest_entries("test"),
        "docs" => manifest_entries("docs"),
        "global" => manifest_entries(Base.load_path_expand("@v#.#"); roots = ["Revise"]),
    ]
    mismatches = String[]
    for uuid in union([keys(e) for (_, e) in entries]...)
        found = [(label, e[uuid]) for (label, e) in entries if haskey(e, uuid)]
        length(unique([version for (_, (_, version)) in found])) > 1 || continue
        name = found[1][2][1]
        versions = join(["$$label: $$(split(version)[1])" for (label, (_, version)) in found], ", ")
        push!(mismatches, "* $$name ($$versions)")
    end
    if !isempty(mismatches)
        @warn "Packages with different versions in the stacked test/docs/global environments. Tests or docs in this REPL may not run against the same versions as `make test` or `make docs`. For exact results, use `julia --project=test` or `julia --project=docs`.\n$$(join(sort(mismatches), "\n"))"
    end
end
try
    @eval using Revise
catch
    @warn "Revise is not available. Install it in your global environment."
end
println("""
**Development REPL for $$(TOML.parsefile("Project.toml")["name"])**

* `include("test/runtests.jl")` – Run the test suite
* `include("test/<name>.jl")` – Run an individual test file
* `include("docs/make.jl")` – Build the documentation (without checking links)
""")
endef
export DEVREPL_JLSCRIPT


help:  ## Show this help
	@if [ -f .git-blame-ignore-revs ]; then git config --local blame.ignoreRevsFile .git-blame-ignore-revs; fi
	@$(JULIA) --startup-file=no -e "$$PRINT_HELP_JLSCRIPT" < $(MAKEFILE_LIST)

test/Manifest.toml: test/Project.toml
	@if [ -f .git-blame-ignore-revs ]; then git config --local blame.ignoreRevsFile .git-blame-ignore-revs; fi
	$(JULIA) --startup-file=no -e "$$INSTANTIATE_JLSCRIPT" test
	@touch $@

docs/Manifest.toml: docs/Project.toml
	$(JULIA) --startup-file=no -e "$$INSTANTIATE_JLSCRIPT" docs
	@touch $@

# `make test` and `make coverage` put only the `test` environment on the LOAD_PATH
# (like `Pkg.test` on CI), so that a dependency missing from test/Project.toml is
# an error
test: test/Manifest.toml  ## Run the test suite
	JULIA_LOAD_PATH="@" $(JULIA) --project=test --startup-file=no --check-bounds=yes --depwarn=yes -e 'include("test/runtests.jl")'

coverage: test/Manifest.toml  ## Run the test suite with coverage, write lcov.info, and show a summary
	@find . \( -name '*.jl.*.cov' -o -name '*.jl.cov' \) -type f -delete
	JULIA_LOAD_PATH="@" $(JULIA) --project=test --startup-file=no --check-bounds=yes --depwarn=yes --code-coverage=@ -e 'include("test/runtests.jl")'
	$(JULIA) --startup-file=no -e "$$COVERAGE_JLSCRIPT"

htmlcoverage: coverage  ## Run the test suite with coverage and write an HTML report to ./coverage (requires genhtml)
	genhtml -o coverage lcov.info

docs: docs/Manifest.toml  ## Build the documentation
	$(JULIA) --project=docs docs/make.jl

devrepl: test/Manifest.toml docs/Manifest.toml  ## Start a REPL for running tests and building the documentation
	$(JULIA) --project=test --banner=no -e "$$DEVREPL_JLSCRIPT" -i

.JuliaFormatter.toml:
	@if [ -e ../.JuliaFormatter.toml ]; then \
	    ln -sf ../.JuliaFormatter.toml .JuliaFormatter.toml; \
	    echo "Linked to ../.JuliaFormatter.toml"; \
	else \
	    curl -fsSL -o .JuliaFormatter.toml $(ORG_URL)/.JuliaFormatter.toml; \
	    echo "Downloaded .JuliaFormatter.toml from $(ORG_URL)"; \
	fi

codestyle: .JuliaFormatter.toml  ## Apply the code style, and check CHANGELOG.md and [sources]
	$(JULIA) --startup-file=no -e "$$CODESTYLE_JLSCRIPT" $(JULIAFORMATTER_VERSION)
	$(JULIA) --startup-file=no test/check_changelog.jl
	@if [ -e ../scripts/envcheck.jl ]; then \
	    $(JULIA) --startup-file=no ../scripts/envcheck.jl lint --no-remote; \
	fi

check-changelog:  ## Validate the links in CHANGELOG.md (no network)
	$(JULIA) --startup-file=no test/check_changelog.jl

changelog:  ## Validate CHANGELOG.md and add any missing issue/PR link targets
	$(JULIA) --startup-file=no test/check_changelog.jl --fix

reuse:  ## Check REUSE compliance (SPDX copyright and licensing information)
	@if command -v reuse >/dev/null 2>&1; then \
	    reuse lint; \
	elif command -v uvx >/dev/null 2>&1; then \
	    uvx reuse lint; \
	elif command -v pipx >/dev/null 2>&1; then \
	    pipx run reuse lint; \
	else \
	    echo "Error: 'reuse' is not installed (see https://reuse.software)"; exit 1; \
	fi

clean:  ## Clean up build/doc/testing artifacts
	find . \( -name '*.jl.*.cov' -o -name '*.jl.cov' -o -name '*.jl.*.mem' -o -name '*.jl.mem' \) -type f -delete
	rm -f lcov.info
	rm -rf coverage docs/build
	rm -f docs/src/api/*.md
	find docs/src/examples -mindepth 1 -maxdepth 1 ! -name index.md ! -name '.*' -exec rm -rf {} +

distclean: clean  ## Restore to a clean checkout state
	rm -f Manifest.toml test/Manifest.toml docs/Manifest.toml .JuliaFormatter.toml
	rm -rf docs/src/examples/.ipynb_checkpoints
