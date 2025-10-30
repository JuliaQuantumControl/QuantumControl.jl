.PHONY: help test docs clean distclean devrepl codestyle servedocs
.DEFAULT_GOAL := help

JULIA ?= julia
PORT ?= 8000

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


help:  ## show this help
	@git config --local blame.ignoreRevsFile .git-blame-ignore-revs
	@julia -e "$$PRINT_HELP_JLSCRIPT" < $(MAKEFILE_LIST)


test:  test/Manifest.toml  ## Run the test suite
	$(JULIA) --project=test --banner=no --startup-file=yes -e 'include("devrepl.jl"); test()'
	@echo "Done. Consider using 'make devrepl'"


test/Manifest.toml: test/Project.toml
	@if [ -e ../scripts/installorg.jl ]; then \
	    $(JULIA) --project=test ../scripts/installorg.jl; \
	else \
	    $(JULIA) --project=test -e 'import Pkg; Pkg.develop(path="."); Pkg.instantiate()'; \
	fi
	@touch $@


docs/Manifest.toml: docs/Project.toml
	@git config --local blame.ignoreRevsFile .git-blame-ignore-revs
	@if [ -e ../scripts/installorg.jl ]; then \
	    $(JULIA) --project=docs ../scripts/installorg.jl; \
	else \
	    $(JULIA) --project=docs -e 'import Pkg; Pkg.develop(path="."); Pkg.instantiate()'; \
	fi
	@touch $@


devrepl:  ## Start an interactive REPL for testing and building documentation
	$(JULIA) --project=test --banner=no --startup-file=yes -i devrepl.jl


docs: docs/Manifest.toml  ## Build the documentation
	$(JULIA) --project=docs docs/make.jl
	@echo "Done. Consider using 'make devrepl'"


servedocs: test/Manifest.toml  ## Build (auto-rebuild) and serve documentation at PORT=8000
	$(JULIA) --project=test -e 'include("devrepl.jl"); servedocs(port=$(PORT), verbose=true)'


clean: ## Clean up build/doc/testing artifacts
	$(JULIA) -e 'include("test/clean.jl"); clean()'


.JuliaFormatter.toml:
	@if [ -e ../.JuliaFormatter.toml ]; then \
	    ln -sf ../.JuliaFormatter.toml .JuliaFormatter.toml; \
	    echo "Linked to ../.JuliaFormatter.toml"; \
	else \
	    curl -fsSL -o .JuliaFormatter.toml https://raw.githubusercontent.com/JuliaQuantumControl/JuliaQuantumControl/refs/heads/master/.JuliaFormatter.toml; \
	    echo "Downloaded .JuliaFormatter.toml from JuliaQuantumControl repository"; \
	fi


codestyle: test/Manifest.toml .JuliaFormatter.toml ## Apply the codestyle to the entire project
	$(JULIA) --project=test -e 'using JuliaFormatter; format(".", verbose=true)'
	@echo "Done. Consider using 'make devrepl'"


distclean: clean ## Restore to a clean checkout state
	$(JULIA) -e 'include("test/clean.jl"); clean(distclean=true)'
