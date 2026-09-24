#!/usr/bin/env bash
# build.sh - build methods.pdf from methods.tex + refs.bib with the TinyTeX
# that Quarto installed (2026-09-11). Run from anywhere; it cds to its own
# folder. Commit the rebuilt methods.pdf with any change to the sources:
# the pages workflow publishes it as https://integrityanalysis.io/methods.pdf.
# Four pdflatex passes, not three: with longtable + hyperref the third pass
# still reported "Label(s) may have changed" on 2026-09-24. The log is
# checked for that warning and for undefined citations before the
# auxiliary files are removed, because a pass started without the .aux
# silently produces a PDF full of "??".
TT="C:/Users/steve/AppData/Roaming/TinyTeX/bin/windows"
cd "$(dirname "$0")"
"$TT/pdflatex.exe" -interaction=nonstopmode -halt-on-error methods.tex >/dev/null
"$TT/bibtex.exe" methods >/dev/null
for i in 1 2 3; do
  "$TT/pdflatex.exe" -interaction=nonstopmode -halt-on-error methods.tex >/dev/null
done
tail -2 methods.log
if grep -q "may have changed\|Citation.*undefined\|Reference.*undefined" methods.log; then
  echo "BUILD NOT CLEAN: rerun or inspect methods.log"; exit 1
fi
rm -f methods.aux methods.blg methods.out methods.toc methods.bbl methods.bbl.bak methods.log
echo "clean build"
