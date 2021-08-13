.PHONY: help test docs clean distclean testrepl docsrepl
.DEFAULT_GOAL := help

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
    match = re.match(r'^([a-z0-9A-Z_-]+):.*?## (.*)$$', line)
    if match:
        target, help = match.groups()
        print("%-20s %s" % (target, help))
print("""
Instead of "make test", consider "make testrepl" if you want to run the test
suite repeatedly.

Likewise instead of "make docs", consider "make docsrepl" if you want to
generate the documentation repeatedly.

Make sure you have Revise.jl installed in your standard Julia environment
""")
endef
export PRINT_HELP_PYSCRIPT


help:  ## show this help
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)


test: ## Run the test suite
	julia -e 'using Pkg;Pkg.activate(".");Pkg.test(coverage=true)'
	@echo "Done. Consider using 'make testrepl'"

testrepl: ## Start an interactive REPL for testing
	@julia --banner=no -e 'using Pkg; Pkg.activate("."); using Revise; println("*******\nDOCS REPL\nRevise is active\nRun\n    ] test\n*******\n")' -i


docs/Manifest.toml: docs/Project.toml
	julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'


docs: docs/Manifest.toml ## Build the documentation
	julia --project=docs docs/make.jl
	@echo "Done. Consider using 'make docsrepl'"

docsrepl: docs/Manifest.toml ## Start an interactive REPL for working on the documentation
	@julia --banner=no --project=docs -e 'using Revise; println("*******\nDOCS REPL\nRevise is active\nRun\n    include(\"docs/make.jl\")\n*******\n")' -i


clean: ## Clean up build/doc/testing artifacts
	rm -f src/*.cov test/*.cov
	rm -rf docs/build

distclean: clean ## Restore to a clean checkout state
	rm -f Manifest.toml docs/Manifest.toml
