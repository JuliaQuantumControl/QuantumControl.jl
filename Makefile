.PHONY: help test docs clean distclean devrepl codestyle
.DEFAULT_GOAL := help

JULIA ?= julia

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
	@julia -e "$$PRINT_HELP_JLSCRIPT" < $(MAKEFILE_LIST)


test:  test/Manifest.toml  ## Run the test suite
	$(JULIA) --project=test --color=auto --startup-file=yes --code-coverage="user" --depwarn="yes" --check-bounds="yes" -e 'include("test/runtests.jl")'
	@echo "Done. Consider using 'make devrepl'"


test/Manifest.toml: test/Project.toml ../scripts/installorg.jl
	$(JULIA) --project=test ../scripts/installorg.jl
	@touch $@


docs/Manifest.toml: test/Manifest.toml
	cp test/*.toml docs/


devrepl:  ## Start an interactive REPL for testing and building documentation
	$(JULIA) --project=test --banner=no --startup-file=yes -i devrepl.jl


docs: docs/Manifest.toml  ## Build the documentation
	$(JULIA) --project=test docs/make.jl
	@echo "Done. Consider using 'make devrepl'"


clean: ## Clean up build/doc/testing artifacts
	rm -f src/*.cov test/*.cov
	rm -rf docs/build
	rm -f docs/src/api/*.md

codestyle: test/Manifest.toml ../.JuliaFormatter.toml ## Apply the codestyle to the entire project
	$(JULIA) --project=test -e 'using JuliaFormatter; format(".", verbose=true)'
	@echo "Done. Consider using 'make devrepl'"


distclean: clean ## Restore to a clean checkout state
	rm -f Manifest.toml test/Manifest.toml
	rm -f docs/Manifest docs/Project.toml
	rm -f .JuliaFormatter.toml
