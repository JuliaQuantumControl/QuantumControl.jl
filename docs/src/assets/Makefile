# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT OR CC0-1.0

.PHONY: clean

controlhams.svg:
	make controlhams.pdf
	pdftocairo -svg controlhams.pdf

controlhams.pdf: controlhams.tex
	pdflatex controlhams.tex

clean:
	rm -f controlhams.pdf
	rm -f controlhams.aux
	rm -f controlhams.log
	rm -f controlhams.out
