<!--
SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>

SPDX-License-Identifier: MIT OR CC0-1.0
-->

# Contributing

Everyone is welcome to contribute! You can contribute simply by opening issues to report bugs or request features.

Development of all packages in the [JuliaQuantumControl] organization follows shared contributing guidelines. Please refer to these for instructions on reporting issues, making pull requests, running the tests, building the documentation, code formatting, and the release process:

<https://github.com/JuliaQuantumControl/.github/blob/master/CONTRIBUTING.md>


## Licensing

This package follows the [REUSE specification](https://reuse.software/): every committed file must declare its copyright and license via SPDX information. New files should carry a header in the appropriate comment style, for example:

```julia
# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT
```

Use these license identifiers by file type:

- Source code (`src/`, `ext/`, `test/`): `MIT`
- Prose and documentation (`README.md`, `docs/src/*.md`): `MIT OR CC-BY-4.0`
- Meta-docs and trivial config (other top-level `*.md`, `Makefile`, CI YAML, `Project.toml`, …): `MIT OR CC0-1.0`

For files that cannot carry a comment (images, binary assets), add an adjacent `<file>.license` sidecar; for files rewritten by tooling (`Project.toml`, generated `*.toml`, `*.bib`), add an entry to `REUSE.toml`. Documenter pages (`docs/src/*.md`) put the SPDX tags inside a leading `@meta` block. Run `make reuse` (or `reuse lint`) to verify compliance.

[JuliaQuantumControl]: https://github.com/JuliaQuantumControl
