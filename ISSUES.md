# IntegrityAnalysis — open issues

Open work only, newest first. Each entry says what the work is, why it
matters, and what "done" looks like. **Closed and fully-implemented
issues are removed rather than kept below** (restructure approved by
Steve 2026-08-25): every prior version of this file, including the full
text of every closed issue and the reasoning that closed it, survives
in git history — `git log --follow ISSUES.md`. Issue numbers are stable
and therefore gappy.

---

## Where things stand — 2026-09-06 (evening; main at 166dc5b, PR #195)

**Forty PRs since 2026-09-03 (#156–#195), and the statistics changed
more in these four days than in the month before.** Each change is on
the record in `docs/method-history.md` (what was wrong, what changed,
what it cost, what it measured); the method as it runs today is
`docs/statistics.md` and nothing else (the split is #192). In the order
they landed: **the exact combination** (#170) — the trial p is still
Stouffer's sum of row z-scores, but judged against its own simulated
null rather than the normal table, which under coarse rounding
under-filled the low tail (1.4 % of honest integer-mean trials below
0.05 instead of 5 %) and could not see a table of identical integer
means however many rows agreed; **the attainable floor** marked on a
row that has said everything its rounding allows (#172; since #191 only
when the arms print identically); **the direct draw** for arms of 100 or
more with the SD at least three grid steps — the arm mean drawn, not
the N observations, thirty times faster on large trials (#176; #191
snapped it to the mean's own h/N grid after an outside audit); **the
0.1 escalation** — a trial or row below 0.1 advances to 10,000
replicates, below 0.01 to 100,000 — and **a user-settable seed**
(`?seed=` in the app, `seed` on the API's URL; #179, #181); **the
pooled SD**, variances weighted by degrees of freedom and c₄ with N − k
at every N (#183); **the per-replicate sigma draw** from the scaled
inverse chi-square, the t-test where a z-test was (#185; at three per
arm the row p's Kolmogorov–Smirnov distance from uniform fell from 0.07
to 0.016); **the trial interval's lower end** from the strictly-beyond
count, so a trial at its floor no longer prints below its own interval
(#190); **precision inference** from a plain rendering, never from
scientific notation, with an explicit per-arm precision kept rather
than overwritten (#190, #191). Also in: the **long categorical layout**
(one line per level, the count in N; #177), **a printed SD of zero**
accepted (#182), and **`.xls` dropped** — refused everywhere, readxl
out of the package (#187, from screen 2117's F3).

**The ways in** grew too: a pasted screenshot opens as a table (#157),
read full width from its first line (#159) and enlarged before OCR so a
screen-resolution picture reads whole (#168); JATS XML through the API
(#162, screened five times); zero-width characters stripped from row
labels (#164); the caption rule for `tatr = "always"` (#166); tesseract
moved to Imports so the deployed app's OCR actually runs (#158); the
build commit baked into the API image so `/health` names it (#165); an
API User's Guide that defines every field, with two by-hand clients
(#163); the nine routes named in the user guide (#160).

**Security.** An outside review (#180: four defects confirmed and fixed,
plus the documentation lines it caught) and six screens since
2026-09-05, every finding adjudicated in `docs/security-screens/log.md`:
the grid's column headers are escaped and clipboard HTML kept out of a
paste (#184, the grid XSS); every spreadsheet read is bounded — a
decompression preflight in front of every reader, a sheet-count cap,
one read per sheet (#184, #186); the CSV column gate counts what the
reader reads — every line, `#`-lines included (#186, #195); nothing
typed or posted ends a session or 500s the API — the engine is wrapped,
count columns swept for magnitude, the rounding clamp runs after the
alias renames (#188, #189, #190); plumber's native request cap set, so
an oversized Content-Length is refused 413 before buffering (#194); the
Word route bounded like JATS (#194); one page-geometry gate,
`.ppRenderablePages()`, in front of both rasterisers (#194, closing the
render half of issue 32); the sigma draw's memory peak put back to 1.6
GB and the parse child's tempdir scrubbed from API reasons (#195). The
screen now watches the engine (`R/P_Calc.R` is on
`tools/securityScreen.ps1`'s list) as well as the doors.

**Tests:** 74 files, 3,016 passing (50 / 1,901 on 2026-09-06; 45 / 1,453
on 2026-09-03), all from synthetic data; the seeded known-answer values
were re-pinned with each engine change.

**Citable numbers** (`docs/validation-ledger.md`, the 2026-09-06 sigma-draw
row): r = 0.9929 against Carlisle 2017 over 5,041 usable trials, median
|Δp| 0.014, 89.1 % within 0.05, 98.5 % alarm concordance, replicate
ceiling 10,000. Parse rate 84.9 % over the 1,865-trial Carlisle corpus
(text engine; 94.8 % with the seam where the model runs); AI-assist
rescue 91 % / 81 %. The August figures (r 0.9930, 99.0 %, 5,080 trials)
belong to the closed-form combination and are history.

**Barnett comparison** (`corpus/syntheticAgeWeightCheck.R`, unchanged):
his trial-level test flags honest integer-mean two-row trials as
under-dispersed 0.9 / 3.3 / 14.0 / 29.2 % at 20 / 100 / 500 / 1,000 per
arm; ours fails safe. His test stays a measured, cited comparison, not
part of the reported screen.

**Open decisions (Steve's):** where the Table Transformer runs in
deployment (issue 33); the parse child's memory ceiling and a total work
budget for the public app (issue 32); the location draw's scale
(σ/√mean N as shipped vs the derivable σ/√ΣN — measured equivalent
2026-09-06, method-history "Ideas noted for later"); a confirmatory
batch for the trial interval (coverage 93.4–93.7 % near an escalation
threshold); the median/IQR branch's calibration.

**Still standing**: the AWS Identity Center session duration (8 h by
default — raise it, then `aws sso login --profile steve`, or unattended
harvests fail; confirm this was done); PubTables-1M full-split report
and v2 scoring (issue 20); the issue-23 layout repairs; nightly parsing
of freshly harvested PDFs with a snapshot library (approved 2026-08-25,
pending); the 121 Carlisle-2017 outliers (issue 3 — against an engine
since revised, so the list should be regenerated from the 2026-09-06
run before adjudication); the TATR ctgov-docs scoping decision
(`tatr/HANDOFF-TATR.md`); the OCR measurement's arm 1 result (issue 22,
last seen finishing on `oldryzen` 2026-09-03). Overnight jobs as last
recorded: 2 AM S3 harvest, 3 AM OneDrive backup.

**Working alongside other sessions**: see AGENTS.md. Worktrees in use
today: `C:/Temp/ia-wt-docs` (this documentation audit),
`C:/Temp/ia-wt-s1523` (screen 1523), `C:/Temp/ia-wt-sdround`
(feature/sd-rounding-draw), `C:/Temp/ia-wt-ties` (corpus/ties-experiment).

**2026-09-24 (overnight, Fable 5.1, Steve offline):** issue 34 below is
in progress on `fix/long-layout-issue-34`. Two corpus-scale measurements
were launched from snapshot libraries in the session scratchpad
(`.../scratchpad/lib-main` = main@e16e185, `.../scratchpad/lib-after` =
the branch), both with `Rscript --vanilla` because the repository's
`.Rprofile` activates renv and silently discards `R_LIBS` — a first pair
of mass-test runs was invalidated by exactly that and discarded.
`corpus/measureMisparse.R` BEFORE run: `.NewCarlisle/misparse/` (log
`.../scratchpad/misparse-before.log`); the on-disk output that was there
did not reproduce issue 24's figures and sits beside a folder named
`contaminated`, so it was set aside untouched as
`.NewCarlisle/misparse-ondisk-untrusted-set-aside-2026-09-24`. The AFTER
run follows it into the same path and is renamed on completion.

---

## 111. Levels under a plain category heading are one variable

**Status: fixed on `fix/plain-heading-gathers-levels`, 2026-09-25**, from
CodeRabbit's reading of PR #412 (issue 105) on Kilic 2023 (Cukurova Med
J, Loadsman corpus, the corpus session's batch 25 AD1). Predates #412.

- **The defect.** "Surgical level" over "L2-3 12(57.1) 12(57.1)", "L3-4
  8(38.1) 7(33.3)", "L4-5 1(4.8) 2(9.5)": the block walker gathered n (%)
  rows as the levels of one variable only under a heading that itself
  announced the notation ("Race, N (%)"). Under a label-only heading each
  level went out as a binary variable of its own with a complement
  ("Lumbar / Not Lumbar", "Thoracic / Not Thoracic", ...) - three
  two-level tables where the page prints one three-level table, every
  complement counting the other levels' patients again. Percent-only
  children ("Caucasian 45" under "Race, %") already gathered under a
  plain heading; the n (%) cells did not.
- **What changed.** An n (%) row under any open heading is a level of
  that heading's variable unless its own label says "(%)" or "percent"
  (its own variable, as before). A lone n (%) row with no heading keeps
  the binary path. A heading that gathers only ONE level this way - a
  section heading ("Demographic data") over a single "Sex (male) 12
  (57)" line - is given back the binary form after the walk, since a
  one-column category is degenerate and would be dropped at validation.
- **What the rule cannot tell apart.** Non-exclusive binary rows under
  a heading ("Comorbidities" over "Diabetes 12 (57)", "Hypertension 15
  (71)") now gather as one variable, exactly as an announced
  "Comorbidities, n (%)" heading always did. A candidate follow-up: a
  block whose level counts exceed an arm's N is not a partition and
  could be split back into binaries. The wide (workbook) reader keeps
  its own announced-only rule (`parseWideTable.R`, `isChild`).
- **On the page.** With issue 104 (the label whole) and 105 (identical
  cells are evidence) the three level rows are one "Surgical level"
  variable with levels L2-3 / L3-4 / L4-5 in two arms of 21.
- **Tests** (`tests/testthat/test-plain-heading-gathers-levels.R`): a
  rebuilt page reads the three levels as one variable (6 expectations
  fail on the unfixed code); a lone n (%) row with no heading keeps its
  complement; a section heading over one n (%) row yields the binary row,
  not a one-level variable. The issue-104 test now looks for the level
  labels among the columns. The degenerate-category, model count-row,
  stratum, identical-cells and Loadsman layout tests still pass.

---

## 109. A variable's own n printed per cell, in brackets

**Status: fixed on `feat/per-cell-n-in-brackets`, 2026-09-25**, from the
corpus session's batch 25 AD6 (Fujii, thyroidectomy, PMID 9924225).

- **The defect.** "Last menstrual cycle(days)[n] 15.3(3.2)[17]
  16.2(2.9)[16] 16.1(3.6)[17] 15.4(3.8)[16]": the bracket after each
  cell is the number of patients that cell summarises - the
  premenopausal ones - not the arm's 25, and the row read with N 25 in
  every arm. The tokenizer read the bracket as a stray plain number.
- **What changed.** In the block walker's continuous rows, a bracketed
  integer that ends the cell's own word, or stands within a few points
  to its right, is that cell's N; where the arm N is known it must not
  exceed it, and a bracketed range ("[33-63]", issue 63) never matches.
  The other form of the same thing - 19358990's "16 (3)b" with a
  footnote "b: for the 25 patients not in menopause" - is prose and is
  not read.
- **On the page.** The menstrual-cycle row carries N 17/16/17/16;
  every other row keeps 25.
- **Tests** (`tests/testthat/test-per-cell-n-in-brackets.R`): a rebuilt
  page with the bracketed row, a bracket larger than the arm N (ignored)
  and a range row (untouched) (1 expectation fails on the unfixed
  code). The header, row-N, range, stratum, partial-arm, column-count,
  gutter and Loadsman layout tests still pass.

---

## 108. Under an announced notation the soup itself marks the slots

**Status: fixed on `fix/announced-soup-marks-slots`, 2026-09-25**, from
the corpus session's batch 25 AD4 (CJA 1994, PMID 8004733, a scan;
three arms of 20).

- **The defect.** "All values are expressed as mean ~ SD." over a page
  whose signs are "4-", "-t-" and, in three cells, the glued digit-colon
  form "5:34", "5:38", "5:5.1". The announcement repairs the soup words
  two or more to a line, but the glued digit form is a slot's evidence
  only (issue 70), and the slots were built from genuine glyphs and
  plain pluses alone - this page sets none - so "81 5:34" stayed three
  words and the first arm's Duration of operation and Duration of
  anaesthesia went unread; Height's third cell likewise.
- **What changed.** Once the notation is announced, every soup word set
  between two numbers marks its column (`.ppRepairPlusMinusGlyphs()`):
  "4-" at one x on four lines is a slot, and "5:34" at that x is the
  sign and its SD. Without the announcement the glued digit form still
  needs a genuine slot.
- **On the page.** Both duration rows read in all three arms (81/82/81
  +/- 34/29/39; 108/108/104 +/- 38/34/40). Height's third cell, "153.5
  5: 5. I", now has its sign but its SD is set as "5." and "I" - an OCR
  break the repair does not reach - and stays unread.
- **Tests** (`tests/testthat/test-announced-soup-marks-slots.R`): the
  helper under the announcement, and its refusal without it; a rebuilt
  page under "mean ~ SD" reads all three arms of both duration rows (7
  expectations fail on the unfixed code). The zero-repair, slot,
  glued-soup, junk-row and Loadsman layout tests still pass.

---

## 107. "_+" is soup too

**Status: fixed on `fix/underscore-plus-is-soup`, 2026-09-25**, from the
corpus session's batch 25 AD5 (CJA 1996, PMID 8665632, a scan under a
diagonal RETRACTED watermark).

- **The defect.** Three second-arm cells set the sign as "_+" - an
  underscore for the lower stroke - and went unread: Duration of
  operation 52.6 +/- 20.7, Acetaminophen 252.0 +/- 82.3, Pentazocine
  1.4 +/- 2.9. The slot repair of issue 65 knows strokes and
  stroke-like letters; the underscore was not among them.
- **What changed.** The underscore joins the soup class
  (`.ppSoupGlyph`), so "_+" at a slot the block's other rows mark with
  the bullet or the sign is the plus-minus.
- **On the page.** Duration of operation and Acetaminophen read in
  both arms. Pentazocine's second SD is absent from the text layer
  altogether (the line ends at the sign), so that cell stays unread.
- **Tests** (`tests/testthat/test-underscore-plus-is-soup.R`): the helper
  on a block whose bullets mark the slot; a rebuilt page reads both
  arms of the rows set with "_+" (6 expectations fail on the unfixed
  code). The slot, glued-soup, junk-row and Loadsman layout tests still
  pass.

---

## 106. Long layout: a heading line carrying a bare number is a heading

**Status: fixed on `fix/heading-with-bare-digit`, 2026-09-25**, from the
corpus session's batch 25 AD7 (Fujii, PMID 10589648) and the "2"
suffixes on 11573601 and 11004073.

- **The defect.** "Pdi (cm H2O)" prints its subscript as a word of its
  own, "CO (L/min-1)" its superscript as "21", so the heading line
  carries a bare number and the classifier calls it data. The
  repeated-measures reader took its headings from label-only lines
  (issue 91), so the rows beneath such a heading took the heading
  ABOVE: the cardiac output rows came out as "PAOP (mm Hg) 2" (the
  previous variable's name plus a dedupe suffix), 11573601's Pdi rows
  as "Haemodynamics: 20 Hz stimulation".
- **What changed.** A data line whose every token is a bare integer,
  none of them a value under the Baseline column, with letters among
  its words, is a heading; the bare numbers are dropped from its text
  ("CO (L/min )", "Pdi (cm H O)").
- **On the pages.** 10589648: HR, MAP, RAP, MPAP, PAOP, CO, three arms
  of 10. 11573601: the Pdi rows under "P di (cm H O)". 12933396 and
  11004073 unchanged. One residue: on 11004073 the subscript "2" sits
  on the first Pdi row's own line, not the heading's, and stays as a
  suffix on that row's name ("20-Hz stimulation 2").
- **Tests** (`tests/testthat/test-heading-with-bare-digit.R`): a
  rebuilt page with a "21" superscript and a "2" subscript on heading
  lines names the rows beneath each (3 expectations fail on the
  unfixed code). The long-layout, legend, canine, heading, letter-group
  and Loadsman layout tests still pass.

---

## 105. Identical n (%) cells under a category heading are evidence, not one echo

**Status: fixed on `fix/identical-n-pct-cells-under-heading`, 2026-09-25**,
from the corpus session's batch 25 AD1 (Kilic 2023, Cukurova Med J,
Loadsman corpus, page 5).

- **The defect.** "L2-3 12(57.1) 12(57.1)" under the heading "Surgical
  Level", two arms of 21, read as a continuous row with mean 12 and
  SD 57.1, while its sibling rows "L3-4 8(38.1) 7(33.3)" and "L4-5
  1(4.8) 2(9.5)" were n (%). The rule that reads "a (b)" as n (%)
  when b is a as a percentage of the arm N wants two distinct (n, %,
  N) signatures - a guard against a coincidence in one arm echoed by
  chance in another - and two arms printing the same cell are one.
- **What changed.** Under a category heading, where the rows are the
  levels of one variable, every arm's cell checking as n / N is
  evidence enough, identical or not: the cells are counted, not the
  distinct signatures. Elsewhere the rule stands, so a "Score 10
  (50.0) 10 (50.0)" row under a mean (SD) footnote is still mean (SD).
- **On the page.** With issue 104 (the label "L2-3" whole, no phantom
  arm) the three level rows are n (%) rows in two arms of 21.
- **Tests** (`tests/testthat/test-identical-n-pct-cells-under-heading.R`):
  a rebuilt page with identical cells under a heading reads them as
  counts (3 expectations fail on the unfixed code); the same cells with
  no heading and a mean (SD) footnote stay continuous. The degenerate-
  category, model count-row, stratum, row-N and Loadsman layout tests
  still pass.

---

## 104. A hyphenated code is one word ("L2-3")

**Status: fixed on `fix/level-code-is-one-word`, 2026-09-25**, from the
corpus session's batch 25 AD1 (Kilic 2023, Cukurova Med J, Loadsman
corpus, page 5).

- **The defect.** The spinal levels "L2-3", "L3-4", "L4-5" head three
  rows of counts. The tokenizer's guard refuses a digit run that a
  letter or digit touches, but it looks only at the character before
  the digit, and that is the hyphen: the "3" of "L2-3" started a token.
  The label was cut to "L2", the "3" fed a phantom arm column at the
  label's x (a column fed by labelled lines, so issue 46 kept it), the
  table read three arms with the first nameless and N-less, and the
  level rows lost their arm N.
- **What changed.** A second guard on the token pattern: a digit run
  whose hyphen, en dash or minus follows a letter or digit is part of
  that word. A range in a cell ("31-57") is untouched, since the
  interval alternative takes it whole from its first number.
- **On the page.** Two arms of 21, the level labels whole, Age, Weight,
  Height and both durations as printed, Male/Female and ASA as
  category rows. The first level row, "L2-3 12(57.1) 12(57.1)", still
  reads as mean (SD): its two cells are identical, and the n (%)
  evidence rule wants two distinct signatures - issue 105.
- **Tests** (`tests/testthat/test-level-code-is-one-word.R`): the
  tokenizer on "L2-3", "T10-11", a bracketed range and a bare range; a
  rebuilt Kilic page reads two arms of 21 with the labels whole and no
  phantom arm (6 expectations fail on the unfixed code). The tokenizer,
  text-precision, junk-row and Loadsman layout tests still pass.

---

## 103. "Divided into three groups of Methods D 10 each": the running head inside the sentence

**Status: fixed on `feat/groups-of-n-past-running-head`, 2026-09-25**,
from the corpus session's batch 25 AD8 (Fujii, PMID 11004073).

- **The defect.** After issues 91 and 95 every cell of the trial's
  Table 1 read with its name, three arms, and N stayed missing although
  the Methods say "divided into three groups of 10 each": the text
  extractor interleaves the two-column page's running head into the
  sentence, "divided into three groups of Methods D 10 each", and the
  "k groups of n" reader took "Methods" for the size.
- **What changed.** The pattern steps over up to three stray words
  between "of" and the size when "each" follows the size - the anchor
  that makes the number the group size and not a dose or a duration
  further along the sentence. A sentence with the stray words and no
  "each", or with four of them, licenses nothing.
- **On the page.** Three arms of 10 (Group I no study drug, II, III)
  with the sentence as source; the 24 cells as before.
- **Tests** (`tests/testthat/test-groups-of-n-past-running-head.R`):
  the interleaved sentence, the plain sentence, a sentence whose "each"
  belongs to a dose, and one with four stray words (3 expectations fail
  on the unfixed code). The arm-size and layout tests still pass.

---

## 102. A "Changes in X" caption heads a time-course table, and on equal scores the lower table number wins

**Status: fixed on `fix/changes-in-caption-tiebreak`, 2026-09-25**, a
regression found by the corpus session's batch 25 (AD3: Fujii, Anesth
Analg 2001;92:762, PMID 11226115).

- **The defect.** On 366548d the trial read Table 1 "Hemodynamic Data
  and Changes" (six variables, four arms of 8). On e4a00ea, with the
  long-layout reader naming rows (issues 91, 95), Table 2 "Changes in
  Pdi, % Edi-cru, and % Edi-cost" parses to the same score, and its
  caption scores nought while Table 1's pays the hemodynamic penalty of
  the caption scorer; the candidate contest kept the higher total and
  the hemodynamic table was gone from the result.
- **What changed.** Two rules. A caption that announces changes in
  something, with no word for baseline, heads a time-course table -
  baseline in one column, later timepoints in the rest - and loses a
  point (`.ppCaptionScore()`); issue 80 penalised "changes ... from",
  this is the bare "changes in". And in the candidate contest, on
  equal totals the candidate whose caption carries the lower table
  number wins (`.ppTableNumber()`): the first table is where a trial's
  baseline data conventionally sit. Before this the earlier candidate
  in caption-score order kept a tie.
- **On the pages.** 11226115 reads Table 1 again (HR, MAP, RAP, MPAP,
  PAOP, CO; four arms of 8). 10589648, whose Table 2 is also "Changes
  in Pdi", keeps Table 1.
- **Tests** (`tests/testthat/test-changes-in-caption-tiebreak.R`): the
  table number from "Table 1", "TABLE II", "Tab. 3" and none; the
  caption penalty and its absence beside a baseline word; a rebuilt
  page with both tables reads Table 1 (4 expectations fail on the
  unfixed code). The change-from-baseline caption and Loadsman layout
  tests still pass.

---

## 101. Long layout: the group count from the legend, and a caption sentence is not the header

**Status: fixed on `feat/long-layout-k-from-legend`, 2026-09-25**, from
the corpus session's batch 24 AC1's fifth paper (Fujii, Br J Anaesth
2001, PMID 11573601).

- **The defect.** Two things. The caption's legend sentence - "study
  drug, group II received propofol ... different from baseline
  (P<0.05)" - carries both a Group word and a Baseline word, and the
  reader's gate took it for the header line: a Group column at the
  sentence's "group", a tolerance of two hundred points, and the arm
  names filled with caption text ("=integrated di-cost", "of the costal
  part"). And on this page only the first row's "I" survives in the
  text layer, so the largest numeral seen was I and the rule of issue
  95, which indexes a value row without a numeral by its place in the
  run, had no run to fill.
- **What changed.** A header line is a row of column names: twelve
  words at most, none ending in a comma, a semicolon or a full stop; a
  sentence with both words is skipped. And when the block shows a
  numeral but no numeral above I, the legend - the caption lines, the
  footnote, the ten lines beneath the block - is read for "group
  <numeral>" and the largest bounds the run (two to eight); a legend
  with no numeral in the block licenses nothing.
- **On the page.** Three arms of 10 (Group I, II, III), eight variables:
  Heart rate, MAP, and the 20-Hz and 100-Hz rows of Pdi, %Edi-cru and
  %Edi-cost. One residue: the "P di (cm H 2 O)" heading line carries a
  bare "2" and so counts as data, and its rows are prefixed with the
  heading above it ("Haemodynamics: 20 Hz stimulation") - the numbers
  are right and the rows are distinct.
- **Tests** (`tests/testthat/test-long-layout-k-from-legend.R`): a
  rebuilt page whose caption carries the legend sentence and whose
  rows keep only the first "I" reads three arms of ten and three
  variables from the Baseline column (9 expectations fail on the
  unfixed code). The long-layout, canine, heading, letter-group and
  Loadsman layout tests still pass.

---

## 100. "(n =3o)": the letter o for a zero after a glued equals sign

**Status: fixed on `fix/size-zero-after-equals`, 2026-09-25**, from the
corpus session's batch 24 (CJA 1998, PMID 9512856, a scan).

- **The defect.** The page prints "(n = 3o) (n =3o)" over its two
  arms. Issue 75's zero repair (`.ppRepairSizeZeros()`) knows the size
  glued whole ("(n=3o)") and split three ways ("(n", "=", "3o)"); the
  second form here - the equals sign glued to the size, "(n", "=3o)" -
  was neither, so the first arm read 30 and the second read as an arm
  of 3 named "o)".
- **What changed.** A word that is an equals sign followed by digits
  with a letter o among them, after a word that is "(n" or "n", is the
  size; the o becomes a zero. Nothing else changes: "=7.4o" after "pH"
  is untouched.
- **On the page.** Two arms of 30; Age, Height and Weight in both.
- **Tests** (`tests/testthat/test-size-zero-after-equals.R`): the helper
  on all three forms with a non-size left alone; a rebuilt page with
  "(n = 3o) (n =3o)" reads two arms of 30 (4 expectations fail on the
  unfixed code). The zero-repair, utility and Loadsman layout tests
  still pass.

---

## 99. "(n = 20 of each)" is the size of every arm, and fills the arms a scanned header left blank

**Status: fixed on `feat/n-of-each-statement`, 2026-09-25**, from the
corpus session's batch 24: the four CJA scans (PMIDs 9717598, 9350368,
9512856, 9836028) that print one arm's "(n = 20)" and lose the other's.

- **The defect.** Issue 87 fills a blank arm by NAME from a "(n = 20)"
  beside that name in the text, and these papers name no arm beside a
  size: they say "diltiazem or saline (n = 20 of each)". That shape was
  not one the size-statement reader (`.ppGroupsOfN()`) knew, and with
  some sizes printed the deterministic ladder asked nothing else.
- **What changed.** Shape (d) of `.ppGroupsOfN()`: "(n = 20 of each)",
  "(n = 40 per group)", "(n = 15 in each group)" is a statement for
  every arm with the group count unstated, like the sentence of issue
  89; a parenthesis that follows "one of three groups" belongs to shape
  (a) and is not read twice, and a power statement is refused. In the
  block walker, with some arms printed and some blank, a statement for
  every arm (count unstated, or naming this table's arm count) fills the
  blanks when its size is the size every printed arm already shows; a
  statement that disagrees with the page fills nothing.
- **On the pages.** 9717598 and 9836028 now fill (their third arm from
  the text, agreeing with the printed 20s). 9350368 does not: its
  statement is "(n=40 of each)" for the strata, not the four arms of
  20, and the reader refuses it as it should. 9512856 prints "(n = 3o)"
  with a letter o, across three words, which issue 75's zero repair
  does not reach - a separate matter.
- **Tests** (`tests/testthat/test-n-of-each-statement.R`): the shapes
  at the helper level, a lone "(n = 20)" and a power statement refused;
  a rebuilt page with one arm's size printed gets the other from the
  statement, and a disagreeing statement leaves it blank (5 expectations
  fail on the unfixed code). The arm-size and layout tests still pass.

---

## 98. "(n ~ 20)": a tilde for the equals sign in the header

**Status: fixed on `feat/header-n-tilde`, 2026-09-25**, from the corpus
session's batch 24 (the CJA scans PMIDs 9717598, 9350368, 9836028).

- **The defect.** The scanned header reads "(n = 20)" over one arm and
  "(n ~ 20)" or "(n~20)" over the next: the OCR of an equals sign in a
  small font is a tilde. The header rules of the block walker accept
  "n =" and, since issue 97, "n:"; the tilde-headed arm had no N while
  its neighbour did, and its name kept the "(n ~ 20)".
- **What changed.** The eight header-N patterns accept "n ~" beside
  "n =" and "n:", and the header word cleaner strips the tilde.
- **On the pages.** 9717598's Group D, 9350368's second ET and LMA and
  9836028's Group D all read 20 with clean names; with issue 99 as well
  the count-less "(n = 20 of each)" no longer has to fill them.
- **Tests** (`tests/testthat/test-header-n-tilde.R`): a rebuilt page
  headed "(n ~ 20)" and "(n~20)" reads two arms of 20 with clean names
  (2 expectations fail on the unfixed code). The colon-header, row-N,
  stratum, ordinal-header, partial-arm, header-count, gutter and
  Loadsman layout tests still pass.

---

## 97. "(n:25)" under the arm names is the arm-size line

**Status: fixed on `feat/header-n-colon`, 2026-09-25**, from the corpus
session's batch 24 AC3 (Fujii, thyroidectomy, PMID 9924225; "allocated
randomly to one of four groups (n:25 for each)").

- **The defect.** The table prints "Placebo 20 ug/kg 40 ug/kg 100
  ug/kg" over "(n:25) (n:25) (n:25) (n:25)", with cells such as
  "46.3(31-57)" set five points apart. Every header rule of the block
  walker wanted "n =": the line was not a header, the header count of
  issue 71 was nought, the gap rule fused four columns into two, and no
  arm had its N. Two arms read where four are printed.
- **What changed.** Each of the eight header-N patterns in
  `parseBaselineTableHeuristics.R` accepts "n:" beside "n =" (as issue
  89 did for the size statements in the text), and the header word
  cleaner strips the colon as it strips the equals sign, so the arm
  names carry no ":" residue.
- **On the page.** Four arms of 25 - Placebo, 20, 40 and 100 ug/kg
  (the superscript of "kg-1" prints as "91" in the text layer and stays
  in the name) - with Height, Weight, the menstrual-cycle day and both
  durations in all four; Age's range unusable as it should be.
- **Tests** (`tests/testthat/test-header-n-colon.R`): a rebuilt page
  with the "(n:25)" line and close-set cells reads four arms of 25, cut
  by the header count, with clean names (2 expectations fail on the
  unfixed code: two arms, N missing). The row-N, stratum, ordinal
  header, partial-arm, header-count, gutter and Loadsman layout tests
  still pass.

---
## 96. A column of upright short words is not a rail

**Status: fixed on `fix/rail-needs-tall-words`, 2026-09-25**, a
regression of issue 93 caught by the fixture of issue 91.

- **The defect.** The rail stripper (`.ppStripRotatedText()`) takes
  four or more narrow words at one x spanning a third of the page for
  a rotated rail, and since issue 93 every word at that x within the
  span goes with them. A long-layout table's group column - "II" on
  four or more rows, five points wide and eight tall - is four narrow
  words at one x spanning a third of the page: it was taken for a
  rail, and with issue 93 every "I" and "III" beside it went too. The
  fixture of issue 91 then lost its whole group column and read as a
  wide table. Before issue 93 the same page lost only its "II"s, which
  issue 88's lost-label rule quietly filled.
- **What changed.** A rail's words are set sideways, so at least two of
  the stack must be far taller than wide (height at least twice the
  width); upright short words never are. Real rails (the OUP and LWW
  rails, URL words 90 to 165 points tall) pass as before.
- **Tests** (`tests/testthat/test-upright-column-not-rail.R`): four
  blocks of I / II / III at one x are untouched (3 expectations fail on
  the unfixed code); a genuine rail with its tall words is still
  stripped whole. The rail, axis, column and layout tests still pass,
  and the fixture of issue 91 reads as long layout with both fixes.

## 95. Long layout: the group column without a header word, and blocks that lost their numerals

**Status: fixed on `feat/long-layout-group-column-by-labels`, 2026-09-25**,
from the corpus session's batch 24 AC1: five canine papers (Fujii, PMIDs
10589648, 10475325, 11004073, 11573601, 10958102), "three groups of 10"
or "of seven", all failing on missing N.

- **The defect.** Two things kept the repeated-measures reader (issue
  34) from these pages. The header line names the timepoints but not
  the group column - "Baseline 60 min", "Variable Baseline Fatigued" -
  and the gate wanted both words, so the wide reader took the two
  timepoints for arms and each group row for a variable ("I", "II",
  "III", "I 2" ... thirty-six rows, N nowhere). And the text layer
  keeps the roman numerals only on the first variable's rows: every
  later block - "MAP (mm Hg)" over three or four value rows - lost all
  of them, so even with the column found, most rows had no index and
  the most-lines-fit rule refused the layout.
- **What changed.** When a header line names a Baseline column but no
  Group column, the group column is found from the labels themselves:
  group words (a roman numeral, a capital letter or two, a small
  integer) stacked at one x on four or more lines beneath the header,
  left of Baseline. And the lost-label rule of issue 88 is widened: a
  value row with no group word continues an open run (the next index)
  or starts a new one at I when the previous run is complete; only a
  row with a value under Baseline and a label of at most five words is
  indexed this way, so a subscript on a line of its own or a Results
  sentence in a full-width block is not. The 1..k run rule and the
  most-lines-fit rule still judge the whole, and a wide table whose
  level rows stack "I", "II", "III" once fails them as before.
- **On the pages** (with the branch alone): 10475325 reads four arms
  of 10 with six variables and 10958102 three arms of 7 with eleven;
  10589648 and 11004073 read their Table 1 as long layout too but lose
  the candidate contest to a wide reading until the rows are named
  (issue 91 names them; the scorer of issue 46 credits no "Unnamed"
  row), so those two land when both fixes are on main. 11573601's
  header carries "Group" and its rows keep their numerals; it fails
  elsewhere (its legend fills the arm names with caption text) and is
  a separate matter.
- **Tests** (`tests/testthat/test-long-layout-group-column-by-labels.R`):
  a rebuilt page with no Group header, a lost II in the first block and
  two later blocks without numerals reads four arms of ten and three
  variables from the Baseline column (9 expectations fail on the
  unfixed code); a wide table with a Baseline column and one stack of
  roman level rows is left to the wide reader. The long-layout, canine,
  letter-group and Loadsman layout tests still pass.

---

---

## 94. "Allocated to one of four groups of 15 patients each" states the arm sizes

**Status: fixed on `feat/groups-of-n-patients-each`, 2026-09-25**, from
the corpus session's batch 24 AC2 (Fujii, Anaesthesia 1998;53:244, PMID
9613269, the same table as Loadsman Anaesthesia1998_244).

- **The defect.** The "k groups of n" reader (`.ppGroupsOfN()`) wanted
  "into": "divided into four groups of 15". The Methods of this trial
  say "allocated randomly to one of four groups of 15 patients each",
  and with no N in the table all four arms of Age, Height, Weight and
  Duration validated as missing N.
- **What changed.** The pattern accepts "to one of" where it accepted
  "into". Everything else about the statement - the verb before it,
  the optional noun after the size, the "every statement for this arm
  count must agree" rule of `.ppGroupNFor()` - is unchanged.
- **On the page.** Four arms of 15 (Great toe-PTC, Thumb-PTC, Great
  toe-TOF, Thumb-TOF) with the sentence as source; sixteen rows.
- **Tests** (`tests/testthat/test-groups-of-n-patients-each.R`): the
  helper on the sentence, the "into" form still read, a sentence with
  neither refused; a rebuilt page with no N in the table gets four arms
  of 15 (6 expectations fail on the unfixed code). The arm-size and
  layout tests still pass.

---

## 93. A figure's axis under the table is not a row, and the rail's short words go with the rail

**Status: fixed on `fix/rail-strip-keeps-column`, 2026-09-25**, a
regression of issue 86 found by the corpus session's batch 23b (AB1:
Saitoh, Br J Anaesth 1995;74:293, Loadsman corpus, Table 1 on page 2,
two groups of 15).

- **The defect.** Once issue 86 stripped the OUP rail, the block ran on
  into the time axis of Figure 2 beneath the table: "15 20 25 ... 100",
  eighteen integers eleven points apart and no label. Issue 46 drops a
  column fed only by label-less lines, but these ticks are closer
  together than the gap the columns are cut at, so they bridged the two
  arm columns into one before any column could be judged, and the
  table read one arm ("PTB group PTT group"), Height and Weight in one
  arm each and Sex not at all. The rail had hidden this: its URL word
  and the label lines it left ended the block before the axis. The
  rail's short words - "at", "on", "12," - are as wide as they are tall
  and stayed, one glued to a row label as "Weight (kg) at".
- **What changed.** Before the columns are clustered, a label-less
  line of six or more plain integers, evenly spaced across the page
  (every gap within a quarter of the median) and stepping by one
  constant amount, is an axis: its tokens are dropped and the line is
  junk. No table prints such a row without a label. And a word at the
  rail's own x, within the rail's vertical span, is part of the rail
  whatever its shape (`.ppStripRotatedText()`).
- **On the page.** Two arms of 15, Sex 7/8 in both, Height 166.2
  (11.0) / 164.9 (10.5), Weight 57.7 (9.4) / 56.5 (9.9) under a clean
  label; Age's range stays unusable. The arm names still carry caption
  fragments ("(PTT) groups (mean (SD PTB group"), as they did before
  issue 86 - a separate matter.
- **Tests** (`tests/testthat/test-axis-ticks-under-table.R`): the
  stripper drops "at", "on", "2015" at the rail's x within its span and
  keeps an "at" below it; a rebuilt page with the axis straight beneath
  the table reads two arms with both cells of Height and Weight (6
  expectations fail on the unfixed code). The issue 46 test's tick line
  is now dropped as an axis before the level step, and its expectation
  says so. The rail, column and layout tests still pass.

---

## 92. A colon between two integers is a ratio, not the sign ("19:21" under "Sex M:F")

**Status: fixed on `fix/colon-ratio-not-fused-sign`, 2026-09-25**, a
regression of issue 85 found by the corpus session's batch 23b (AB2:
CJA 1997;44:390, page 3, four arms 40/40/40/10).

- **The defect.** Issue 85's fused-sign glyph set included the colon,
  so a "Sex M:F" row printing "19:21 19:21 19:21 5:5" was split into
  three cells of 19 +/- 21 and one of 5 +/- 5: a continuous variable
  that did not exist, which moved the trial's P_FULL from 0.013 to
  0.125.
- **What changed.** The colon is out of the fused-sign set. An OCR
  sign of that shape ("5:9", issue 77) is still read by the slot rule,
  which needs the column's other rows to set a genuine glyph there.
  The "Sex M:F" row is skipped as before issue 85 (a bare number with
  no SD); reading "19:21" as a two-level count is a separate reading,
  not made here.
- **Tests** (`tests/testthat/test-colon-ratio-not-fused-sign.R`): the
  helper leaves a line of colon ratios alone while still splitting the
  letter forms; a rebuilt page with a "Sex M:F" row reads Age, Height
  and Weight and no continuous Sex (4 expectations fail on the unfixed
  code). On the real page Age, Height and Weight are unchanged and Sex
  M:F is skipped.

## 91. Long layout: a row's label keeps its leading number, and a heading above the group rows names them

**Status: fixed on `feat/long-layout-block-heading`, 2026-09-25**, from
the corpus session's batch 23 on Fujii 2003 (PMID 12933396, Table 1
"Changes in Hemodynamics, Pdi, and %Edi").

- **The defect.** The repeated-measures reader (issue 34) named each
  row from the text before its first token. On "20-Hz stimulation I
  15.9 +/- 1.5" the tokenizer reads the "20" of "20-Hz" as a number,
  so the label was empty and the row "Unnamed"; and the variable
  printed as a heading on a line of its own above its group rows -
  "Pdi (cm H2O)" over the 20-Hz and 100-Hz rows, "%Edi-cru", "%Edi-cost"
  - was a label-only line the reader skipped. Eight of the table's ten
  variables were "Unnamed" ... "Unnamed 6" while every number was right.
- **What changed.** `.ppLongRowLabel()`: the label is the text before
  the first token in or beyond the Group column (the group index or
  the value), so a number inside the label's own words stays with it.
  The most recent short heading (a label-only line of five words or
  fewer after the header) is kept: it names a row that has no label of
  its own ("HR (bpm)" over "I 142 +/- 11") and prefixes a label that
  starts with a digit and cannot stand alone ("Pdi (cm H2O): 20-Hz
  stimulation"). A row whose label is a name in itself keeps it, as
  the wide reader keeps a continuous row's label under a category
  heading.
- **On the page.** Ten variables, all named: HR, MAP (mm Hg), Pdi (cm
  H O) [the subscript 2 is on a line of its own] with its 20-Hz and
  100-Hz rows, %Edi-cru and %Edi-cost likewise; three arms of 8.
- **Tests** (`tests/testthat/test-long-layout-heading-rows.R`): a
  rebuilt page with a labelled block, a heading over two numeric-led
  rows and a heading over bare rows reads four named variables (7
  expectations fail on the unfixed code). The long-layout, canine,
  letter-group and Loadsman layout tests still pass.

---

## 90. The sign set as a digit ("47.357.9"), and a soup word glued to the SD alone ("50.1 k8.0")

**Status: fixed on `feat/digit-fused-sign`, 2026-09-25**, from the
corpus session's batch 23 on AAS1998_851 (Saitoh, Acta Anaesthesiol
Scand 1998;42:851): after issue 85 Height read four arms, but Age
("48.4k7.2 46.9Z7.7 47.357.9 44 50.1 k8.0") and Weight ("56.429.2
56.7?9.0 57.8Z9.4 66 58.527.8") were still skipped as bare numbers
with no SD.

- **The defect.** Issue 85 reads a cell word with a LETTER where the
  sign was, two or more to a line. Three cells on this page set the
  sign as a digit, and one line splits its last cell into a bare
  number and a soup word glued to the SD. The digit form is ambiguous
  on its own ("47.357.9" could split three ways), so no rule read it.
- **What changed.** A line with two or more sign cells (letter-fused
  or the plus-minus glyph itself) fixes the precision of its cells:
  one decimal count for the means, one for the SDs. With that settled,
  `.ppRepairFusedSigns()` also reads (a) a word of two decimal points
  as mean, one stray digit, SD - "47.3" "5" "7.9" is the only split at
  one decimal each side - and (b) a soup word glued to an SD alone
  ("k8.0") that follows a bare number of the line's mean precision
  ("50.1"). Neither form is read on a line with fewer than two sign
  cells; the digit form needs a decimal on each side; where the
  line's sign cells disagree on precision only the letter form is
  read. The letter form itself now also counts the line's true glyphs
  toward its two-cell floor.
- **On the page.** Age reads 48.4/46.9/47.3/50.1 (SD 7.2/7.7/7.9/8.0)
  and Weight 56.4/56.7/57.8/58.5 (9.2/9.0/9.4/7.8), n 40/40/40/15,
  beside Height as before; the volunteers flag still fires.
- **Tests** (`tests/testthat/test-digit-fused-sign.R`): the helper on
  the Age and Weight lines, a glyph line with one digit-fused cell, a
  line with no sign cell (untouched) and a line whose precisions
  disagree (letters only), with the split words' extents; a rebuilt
  Saitoh page reads Age, Height and Weight across four arms (11
  expectations fail on the unfixed code). The sign-repair and layout
  tests still pass.

---

---

## 89. Three more ways a paper states its arm sizes, and the power statement that is not one

**Status: fixed on `feat/size-sentence-shapes`, 2026-09-25**, from the
corpus session's batch 22 spec of every size-stating sentence in the 48
missing-N Carlisle trials (PMIDs 9861126, 9924225, 14749151, 10357343).

- **The defect.** The "k groups of n" reader (`.ppGroupsOfN()`) knew
  "divided into three groups of 20" and "(n = 20 each)" but not the
  colon of "(n:50 each)", nor a total that the group count divides
  ("150 female patients ... allocated randomly to one of three groups"),
  nor a size on a sentence of its own with the group count unstated
  ("Twenty patients were randomly assigned to each treatment group").
  Its number words stopped at twenty. And a power statement ("60
  patients per group would be sufficient") was at risk of being read as
  an allocation.
- **What changed.** `n\s*[=:]` accepts the colon; the number words
  reach thirty to hundred; three sentence shapes are read: (a) "one
  of/into K groups (n = N each)", (b) "T patients ... one of/into K
  groups" giving N = T / K only when whole and T >= 2K, (c) "N patients
  were [randomly] assigned/allocated to each [treatment] group" with the
  group count recorded as NA. A shape whose sentence window mentions
  sufficiency, power, sample size, detection, requirement or a
  calculation is refused. `.ppGroupNFor()` prefers a statement naming
  the table's arm count and falls back to a count-less one, which
  serves any k. The duplicate test in `add()` copes with NA.
- **Tests** (`tests/testthat/test-size-sentence-shapes.R`): each shape
  at the helper level, the refusals (a total that does not divide, the
  power statements), the number words, and a rebuilt page with no N in
  the table filled from the count-less sentence while the power
  statement alone leaves it empty (17 expectations fail on the unfixed
  code). The arm-size and layout tests still pass.

---

## 88. Fujii's canine tables: roman groups, a lost label, and the sign as U+2AFE

**Status: fixed on `feat/canine-long-layout`, 2026-09-25**, from the
corpus session's batch 22 (the issue 84 recheck; PMID 12933396 the
cleanest case, 12088956 identical in shape).

- **The defect.** Sixteen of the eighteen animal papers among the 48
  missing-N Carlisle trials are Fujii canine tables of one shape:
  "Variable | Group | Baseline | Fatigued | Treatment | Recovery", the
  groups I, II and III as rows under each variable. Three things kept the
  repeated-measures reader out. The text layer reports the font's
  plus-minus as U+2AFE, which the tokenizer did not know, so no cell was
  a mean ± SD; the middle group's "II" is missing from the text layer
  altogether, so its row carried no index; and issue 76 numbered letter
  labels by first appearance, which would have made III the second
  group. The wide reader then took the Baseline and Fatigued columns for
  two arms and the group rows for separate variables, with no N - and
  issue 84's ladder, offered "three groups of eight each", abstained
  because k = 3 named more arms than the two the parse had.
- **What changed.** The tokenizer and the slot repair know U+2AFE as the
  sign. In the reader a roman numeral under Group is its own index; a
  value line with nothing before its first number, between roman rows,
  is the next group when that fills a gap the numerals seen in the block
  bound (never a phantom Group IV after the last III); the groups are
  named by their numerals and by the legend, whose "=" may be U+2AFD in
  that font ("Group I = no study drug"). The size then comes from the
  text as issue 84 provides: three arms of eight, the Baseline column
  only.
- **Tests** (`tests/testthat/test-canine-long-layout.R`): U+2AFE
  tokenizes as the sign; a rebuilt page with roman groups, a lost II, the
  legend and "three groups of eight each" reads three arms of eight from
  the Baseline column, named by the legend (fails on the unfixed code).
  The issue 34, 76 and sign tests still pass.

---

## 87. Some arms print an N, the rest do not: the ladder fills them by name

**Status: fixed on `feat/partial-arm-n-by-name`, 2026-09-25**, from the
corpus session's batch 22 (PMIDs 8004733, 9717598, 9350368, 9512856 on
the deterministic Carlisle pass).

- **The defect.** The arm-size ladder of issue 42 runs under one gate:
  every arm without N. That is right for its positional rules, which
  assume nothing is known, but it shut out the arm-NAME match too, so a
  table that printed one arm's size beside a "(n = 20)" naming the other
  arm in the text failed validation for the missing N.
- **What changed.** With some sizes printed, the block walker asks the
  ladder by name only (`namesOnly = TRUE` in `.ppFillArmNFromText()`):
  a mention whose preceding words name a missing arm fills it, with the
  sentence as source; the elimination and positional rules stay behind
  the every-arm gate. A named arm whose name is a stop word of the match
  ("control", "study") is not matched, as before.
- **Tests** (`tests/testthat/test-partial-arm-n-by-name.R`): the ladder
  by name on a hand-built mention frame, and its refusal to eliminate
  under `namesOnly`; a rebuilt page printing one arm's size gets the
  other from the text by name (fails on the unfixed code). The arm-size
  and layout tests still pass.

---

## 86. The OUP download rail, seven points wide, is a rotated rail

**Status: fixed on `fix/oup-rail-rotated-words`, 2026-09-25**, from the
corpus session's batch 21 finding AA1 (PMIDs 9389277 and 9861126, BJA).

- **The defect.** "Downloaded from https://academic.oup.com/bja/article/
  .../254374 by ... user on 25 September 2026" runs up the right margin
  of every OUP page. The rotated-rail stripper of issue 35 took a word
  for a rail candidate when its reported width was six points or less -
  the LWW rail it was measured on - and the OUP rail is set one point
  larger, so none of its words qualified. The URL's article number
  became a fourth arm with N = 254996 (320553 on the other paper), and
  the validator refused the table for its size.
- **What changed.** A word up to eight points wide whose height is at
  least twice its width is a rail candidate too - a rotated word is far
  taller than wide, an upright two-letter word is about as wide as it is
  tall - and the rail test (four or more such words on one x, spanning a
  third of the page) decides as before. Both pages now read three arms
  with no phantom.
- **Tests** (`tests/testthat/test-oup-rail-rotated-words.R`): a page of
  word boxes with the OUP rail's own geometry loses its four rail words
  and keeps every upright word (fails on the unfixed code); a rebuilt
  page with the rail beside its table reads two arms of 30 and no
  phantom. The issue 35 and 38 rail tests and the Loadsman layout tests
  still pass.

---

## 85. The sign fused inside the cell word ("48.4k7.2")

**Status: fixed on `feat/fused-sign-in-cell-word`, 2026-09-25**, from the
corpus session's batch 20 finding Z1 (Saitoh, Acta Anaesthesiol Scand
1998;42:851; Loadsman corpus, page 3).

- **The defect.** The scanned page's text layer sets each mean ± SD cell
  as one word with a letter or symbol where the sign was - "48.4k7.2",
  "46.9Z7.7", "168.0?8.5", "166.9k8.4" - and once with the digit 5
  ("47.357.9"). The tokenizer's number pattern refuses a digit run that a
  letter touches on either side, so the rows held no cell: the
  deterministic pass read Gender alone and scored a Gender-only table
  (p 0.0029, meaningless).
- **What changed.** `.ppRepairFusedSigns()` in `R/utils.R`, called after
  the sign and size repairs at the head of `.ppParseBlock()`: a word of
  the shape NUMBER, one or two glyphs that are not digits, NUMBER - the
  glyphs not "e"/"E" (an exponent) nor "x"/"X" (a dimension) - is a mean
  ± SD cell when the line holds two or more of them, and is split into
  its three words with the sign as the plus-minus glyph, the widths
  shared by character count. The digit-fused form ("47.357.9") is left as
  it is: without a legend naming the digit it cannot be split, and the
  row is reported as unusable rather than misread. On the page Height
  now reads four arms; Age and Weight, each with a digit-fused cell,
  stay reported for the reviewer or the model.
- **Tests** (`tests/testthat/test-fused-sign-in-cell-word.R`): the helper
  on fused cells, on an exponent, a dimension and a lone fused word; the
  split words keep the cell's extent; a rebuilt page reads Age, Height
  and Weight across four arms (fails on the unfixed code). The sign,
  glyph, junk-row and Loadsman layout tests still pass.

---

## 84. A deterministic table whose arms all lack N gets the model route's arm-size ladder

**Status: implemented on `feat/deterministic-arm-n-from-text`,
2026-09-25**, from the corpus session's batch 21 (the deterministic
Carlisle-168 pass on adf5b75).

- **The gap.** Of the 82 Carlisle trials the deterministic reader did not
  analyse, 55 failed validation, and 48 of those for one reason: the
  table printed no arm sizes. Thirty-nine of the 48 state the sizes in
  the text - "divided into three groups of 20" (9) or "(n = 20)" beside
  the arm's name (30). The model-read table has had that recovery since
  issue 42 (`.ppArmNFromDocument()`, under the gate that every arm lacks
  N, with the CONSORT flag on the result); the deterministic table had
  only its own ladder inside the block walker, which reads "(n = k)"
  mentions by arm name and by position but never the "k groups of n"
  statement, and never the document-text ladder as a whole.
- **What changed.** After the block walker's own ladder, a table whose
  value arms all still lack N is given, in order: the "k groups of n"
  statement when every such statement for this arm count agrees
  (`.ppGroupNFor()`), then the document-text ladder by arm name and by
  position (`.ppArmNFromDocument()` on the document's text, passed down
  as `docText`). Each size carries its sentence as its source, so
  `reviewFlags()` asks for it to be checked against the CONSORT diagram
  exactly as for a model-read table. A table that prints any arm's size
  is left as it was.
- **Tests** (`tests/testthat/test-deterministic-arm-n-from-text.R`): a
  rebuilt page with no printed sizes and "divided into two groups of 20"
  in its text reads two arms of 20 with the sentence as source and the
  CONSORT flag (fails on the unfixed code); "(n = 30)" beside each arm's
  name; a table printing one arm's size is untouched. The arm-size and
  layout tests still pass.

---

## 83. A duration whose label is in another script, with an English gloss, is kept

**Status: fixed on `fix/non-latin-duration-labels`, 2026-09-25**, from the
corpus session's batch 19 finding Y1 (MTS2006_17, Loadsman corpus).

- **The defect.** On a page that prints Table 1 in Japanese, the model
  returns the row's Japanese name with the gloss "(surgery duration)".
  With the table's block at hand a duration is judged as the table's row
  (issue 74), by the block test of issue 61 - the label's first two words
  of three letters or more on a line of the block - which can never find
  "surgery" in a Japanese block, so the row was refused as another
  table's, against the durations policy.
- **What changed.** A duration whose label carries a code point beyond
  Latin Extended-B (another script) is kept on the durations option's
  terms, block or no block; an outcome in such a label ("(postoperative
  pentazocine required)") is still refused by its vocabulary, and a
  Latin-script duration not printed in the block is still another
  table's row. The script test is by code point, not by a PCRE class,
  which needs UTF mode.
- **Tests** (`tests/testthat/test-non-latin-duration-labels.R`): the
  Japanese labels with their glosses against a Japanese block and with
  no block; the Latin-script cases unchanged; accented Latin script is
  Latin.

---

## 82. The announced "mean + SD" rule's two-cell floor counts the cells already read

**Status: fixed on `fix/plus-rule-counts-read-cells`, 2026-09-25**, from
the corpus session's batch 19 finding Y4 (Saitoh, Can J Anaesth
1995;42:992; Loadsman corpus, the six-arm page of issue 65).

- **The defect.** A regression of issue 77. The slot repair now turns a
  plain "+" into the sign at any slot under an announced soup, and on
  that page it read five of Age's six plus signs before the block
  walker's announced "mean + SD" rule ran; the sixth, "49.4 + 5.9", sat
  in a column no other line marked (its neighbours' signs were soup) and
  was left to that rule, which requires at least two plus pairs on the
  line. Counted alone it fell under the floor, its two numbers stayed
  plain, and the fifth arm's Age was lost - on a page issue 65 had made
  whole, with no flag but "Age (5 of 6)".
- **What changed.** The floor counts the cells the line already holds:
  a lone plus pair beside one or more mean +/- SD cells is one more cell,
  while a lone pair on a line with no cell at all is still refused (the
  lone annotation the floor exists for). A line with no pair is left as
  it is, as before.
- **Tests** (`tests/testthat/test-plus-rule-counts-read-cells.R`): a
  rebuilt six-arm page whose fifth column no other line marks reads every
  arm of Age (fails on the unfixed code); a lone "5 + 2" on a line with no
  cell, off the sign columns, is still refused under an announced "mean +
  SD". The issue 45, 65, 70 and 77 tests still pass.

---

## 81. A level row in the editors' view carries its variable

**Status: implemented on `feat/editors-view-level-names`, 2026-09-25**, to
Steve's direction of 2026-09-25.

- **The gap.** The editors' view (the journal-style table the app
  downloads and the API returns as `journalTables`) printed a category's
  levels as indented rows under a "Sex, n" heading: "    MALE", "
  FEMALE". The grid's level columns are shared across variables, and
  once the indent is lost to a spreadsheet or a CSV a sheet reading
  "MALE, FEMALE, 1, 2, 3, 1, 2, 6, 7" does not say that 1-3 are ASA
  classes and 1, 2, 6, 7 are pain categories.
- **What changed.** `buildBaselineTables()` names each level row for
  its variable - "Sex: MALE", "ASA: 1", "Pain score: 6" - under the
  heading as before; a column already named for its variable is not
  prefixed twice. The wide reader, which reads the editors' view back
  into the template, gives the bare level back under its heading, so
  the round trip returns the column MALE, not a new column "SEX: MALE".
- **Tests** (`tests/testthat/test-baseline-view.R`): the level rows carry
  the variable and no indented row remains; levels shared between ASA
  and a pain score read unambiguously. The editors'-view and stacked
  Baseline Tables round-trip tests of `test-wide-table.R` pass with the
  named rows.

---

## 80. A table of changes from baseline is not the baseline table

**Status: fixed on `fix/change-from-baseline-caption`, 2026-09-25**, from
the corpus session's batch 17 finding W1 (Fujii 1994, Can J Anaesth; PMID
8055614), after issues 76 and 77.

- **The defect.** Once issue 77's sign repairs made its rows readable,
  "TABLE II Changes in Pdi (cmH20) from pre-fatigue values" out-scored
  the page's Table I ("Haemodynamic data and changes": score 10, caption
  -2) at score 12, caption 0, and the whole-document parse returned a
  table of changes as the baseline table - on the batch's route and the
  app's. The caption scorer marked down "outcome", "complication",
  "haemodynamic" and the like, but not a caption that says its cells are
  changes from, or responses to, the state before treatment.
- **What changed.** `.ppCaptionScore()` marks such a caption down like an
  outcome caption (-3, once): "changes in ... from ...", "changes from
  baseline / pre-<word> / initial / control values", "responses to ...",
  "... during / after / following surgery, anaesthesia, induction,
  infusion, treatment, the study". A caption that says baseline
  elsewhere keeps its standing ("Baseline characteristics and changes
  from baseline"); "Changes from baseline in blood pressure", whose only
  "baseline" is the one it changes from, loses the word's bonus as well.
  Table I now wins the page: 6 variables x 2 arms of 10 from its
  Pre-fatigue column, on the whole document and with `pages = 3`.
- **Tests** (`tests/testthat/test-change-from-baseline-caption.R`): the
  scorer on the two captions of that page and on four more wordings; a
  baseline caption is never marked down; a rebuilt page holding both a
  plain table and a table of changes picks the plain one (fails on the
  unfixed code). The caption, anchor and Loadsman layout tests still pass.

---

## 79. A validator warning that lets the table pass

**Status: implemented on `feat/validator-warning-code`, 2026-09-25**, to
Steve's direction of 2026-09-25 ("implement a warning that allows the
validator to pass ... A warning will allow comparisons to be made against
ground truth, while also highlighting to validating software as well as
human reviewers where there may be problems that need further scrutiny").

- **The gap.** The validator passed a table or failed it. A row that
  analyses but deserves a look - an SD larger than its mean, a variable
  with the same value and no dispersion in every arm, two variables of
  one trial with identical N, mean and SD in every arm - was either
  flagged only by the PDF parser (and so invisible for a spreadsheet) or
  cost the whole table, and the corpus session spent time working out
  what had failed and why.
- **What changed.** `.iaRowWarnings()` in `R/validateData.R` judges the
  rows the analysis will see and files each finding as an issue with the
  code `warning` - row, column, note - without setting `FAIL`. An SD is
  judged against a non-negative mean only (a change score is not). The
  app paints such cells lavender, explains the code in the legend and on
  hover, and logs "Validation passed with n warning(s)" with the rows;
  the analysis runs. The service returns `warnings` beside a successful
  `/analyze` reply, each `{row, col, code, note}`, and the API guide
  lists the code.
- **Tests** (`tests/testthat/test-validator-warning-code.R`): the helper
  on a table holding all three shapes and a clean pair of rows; a
  negative mean is not judged; `validateData()` passes with eight
  warnings and files none on the clean rows; `.apiAnalyze()` returns
  them beside `ok = TRUE`; the app source paints and explains the code.

---

## 78. The P across trials is combined from the numeric trial p, not from its display

**Status: fixed on `fix/stouffer-uses-numeric-trial-p`, 2026-09-25**, to
Steve's direction of 2026-09-25 ("use the actual number, not the displayed
number, for the P across trials").

- **The defect.** A trial's Summary line carries its p as a display:
  four significant figures, or "<0.0001" when the one-sided 97.5% Monte
  Carlo bound licenses it. Both Stouffer combinations across trials - the
  results workbook's Summary sheet and the API's `overallP` - read that
  display back as a number, so a trial at 0.000003 entered the
  combination as 0.0001 (z = 3.7 for z = 4.5) and a four-figure display
  entered as its rounded value. The study-level p was conservative, and
  most so for the trials a fraud screen cares about. Within a trial
  nothing was lost: the trial p is the exact combination over the
  replicates.
- **What changed.** `P_Calc()` keeps the numeric p of every line in a
  `.PNUM` column - on the Summary line, the trial p at full Monte Carlo
  precision (still floored at 1/(m+1), the honest limit of the
  simulation). One helper, `.iaOverallP()` in `R/baselineTable.R`, takes
  the number when it is there and the display otherwise (a frame from an
  older build, a P typed by hand), and both combinations call it. The
  workbook's Test Results sheet and the API's CSV drop the column; the
  displays are unchanged.
- **Tests** (`tests/testthat/test-stouffer-numeric-trial-p.R`): the helper
  on a hand-built frame combines 1e-6 rather than 1e-4 and falls back on
  the display without the column or with an NA; the CSV carries no
  internal column; `P_Calc()`'s Summary line carries a numeric p at or
  below its display. The KIND test now expects the column.

---

## 77. A plain "+" at a slot the sign itself marks, the sign dropped entirely, and a legend that spells "S D"

**Status: fixed on `feat/slot-plus-and-dropped-sign`, 2026-09-25**, from
the corpus session's batch 17 finding W1 (Fujii 1994, Can J Anaesth; PMID
8055614).

- **The defect.** That page's OCR sets the plus-minus as "5:9", "-1-",
  "+" and, in six cells, as nothing at all: "142 10", "121 14", "14 2",
  "2.0 0.5". Its legend reads "All values are expressed as mean -t- S D",
  with the SD split. Issue 65's slot repair reached the soup words only:
  a "+" is never repaired by a slot (issue 45's lone "5 + 2"), the legend
  did not announce with "S D", and a dropped sign is not a word at all.
  Two cells per variable were read at best, under the four-row floor of
  the repeated-measures reader.
- **What changed.** In `.ppRepairPlusMinusGlyphs()`: (a) the legend may
  spell SD as "S D" or "S.D."; (b) a plain "+" between two numbers is the
  sign at a slot that two or more lines mark with the sign itself (not
  with a "+"), or, under an announced soup, at any slot - issue 45's
  lone "5 + 2" beside one signed line is still left alone; (c) the sign
  dropped entirely: two numbers straddling such a slot with a gap of four
  to twenty points between them get the sign inserted, the second number
  not negative. The gap bound keeps two arms' counts on an "n 20 20" row,
  forty points apart, from becoming one cell.
- **Tests** (`tests/testthat/test-slot-plus-and-dropped-sign.R`): the "+"
  at a strong slot and the lone "+" left alone; the dropped sign with the
  count row and the negative number untouched; the "S D" legend with "+"
  cells and a glued "5:9". The issue 45, 63, 65, 67 and 70 tests still
  pass.

---

## 76. The repeated-measures layout with letter groups, a "Pre-<word>" column, and a legend for the arm names

**Status: fixed on `feat/long-layout-letter-groups`, 2026-09-25**, from
the corpus session's batch 17 finding W1 (Fujii 1994, Can J Anaesth; PMID
8055614; the issue 59b design note).

- **The defect.** Table I is the long layout of issue 34 - "Variable |
  Group | Pre-fatigue | Fatigue" - with the groups printed as the letters
  C and N under Group, the baseline column named "Pre-fatigue", the unit
  on each variable's second line ("HR" / "(bpm)"), and the arm names
  only in the footnote legend "C = control, N = nicardipine" and the text
  "control group (Group C, n = 10)". The reader wanted integer indices
  and a "Baseline"/"Pre" column, so the layout fell to the wide reader,
  which took the two timepoints for two arms and each variable's group
  rows for separate variables ("HR (bpm), Group C" with two arms of 20,
  Table II's Pdi rows merged in; 45 rows, p 0.9999).
- **What changed.** A capital letter or two, or a roman numeral, under
  the Group column is a group label, numbered in the order the labels
  first appear (the 1..k run rule then applies as before), and cut off
  the end of the row's label. The baseline column may be a "Pre-<word>"
  column from a closed list (fatigue, op, operative, treatment, drug,
  induction, infusion, dose, study, intervention, exercise, stimulation),
  with the hyphen as a dash or the Unicode minus too. Letter groups are
  named by the legend ("C = control" in the footnote or the lines beneath
  the block), else "Group C". A group row with an index but no usable
  value still opens or continues its variable, so the next group's row is
  not filed under the variable above (RAP's C row, a fused "5+2", had left
  RAP's N row under MAP); such rows do not count toward the layout's
  admission. A letter group's size comes from a size mention whose
  preceding words end with "Group C" when every such mention agrees.
- **On the page** (with issue 77's sign repairs): 6 variables x 2 arms of
  10 from the Pre-fatigue column - HR 146/142, MAP 121/121, RAP N 5,
  MPAP, PCWP 8/9, Qt 2.0/1.9 - with RAP's C row reported as skipped (its
  cell is the fused word "5+2").
- **Tests** (`tests/testthat/test-long-layout-letter-groups.R`): a rebuilt
  page with the letters, the Pre-fatigue column, the unit lines and the
  legend reads two arms of 10 named by the legend and the Pre-fatigue
  values only (fails on the unfixed code); the issue 34 and Loadsman
  layout tests still pass.

---

## 75. A letter O for a zero in an arm size ("(n=4O)")

**Status: fixed on `fix/ocr-zero-in-arm-size`, 2026-09-25**, from the
corpus session's batch 17 finding W2 (Fujii 1999, Can J Anaesth; PMID
10522590).

- **The defect.** The scanned page's text layer prints the header sizes
  as "(n=4O)" beside "(n=40)". The size regex read 4, the remainder "O)"
  became part of the first arm's name ("Granisetron O)"), and the first
  arm went out with N = 4 - a wrong number - which the hybrid merge then
  doubled into a phantom arm beside the model's real one (p 0.082 to
  0.0009 on a table with the wrong N and a duplicated column). Issue 48's
  phantom-arm rule did not reach it: the phantom had values.
- **What changed.** `.ppRepairSizeZeros()` in `R/utils.R`, called at the
  head of `.ppParseBlock()` after the plus-minus repair: within a word
  that is an "(n = k)" group, or the number word of a split one ("(n" "="
  "4O)"), a letter O among digits is a zero. At least one digit must be
  present, and nothing outside such a group is touched. The page reads
  two arms of 40 with clean names.
- **Tests** (`tests/testthat/test-ocr-zero-in-arm-size.R`): the helper on
  glued and split forms and on words that must not change ("Oral",
  "SpO2", "n=O"); a rebuilt page with "(n=4O)" reads two arms of 40 with
  clean names (fails on the unfixed code).

---

## 74. Post-randomisation quantities in a baseline table: the `durations` option

**Status: implemented on `feat/durations-option`, 2026-09-25**, to Steve's
decision of 2026-09-25, from the corpus session's batch 15b finding U1.

- **The question.** A baseline table often prints durations of surgery
  and of anaesthesia, blood loss, the fluids given. Randomised at
  induction, they are measured after the intervention and are not
  baseline values; randomised after surgery (a postoperative analgesia
  trial), they precede the intervention and have the same statistical
  standing as any other baseline variable. That is a judgement for each
  trial, not a rule the engine can apply from a label. Meanwhile the
  outcome refusal of issues 54, 61, 64 and 66 treated them as outcomes,
  and on the model-only routes - which have no table block to spare a
  printed row - removed 58 printed duration variables from 28
  retry-decided Carlisle trials, moving the Table 12 count of human
  trials at p < 0.001 from 15 to 10.
- **The decision (Steve).** Take the author's word by default: a
  baseline table is meant to hold pre-randomisation values, so the rows
  stay in, and the reader is told. The app shows a radio button when a
  parsed table prints them - "Include durations" (the default) and
  "Exclude durations" - to call attention to the possible error; the
  service and the app's address take `durations=exclude` to switch the
  default. For a corpus the recommended route is two passes: parse the
  PDFs to a spreadsheet, scan it for entries that are likely
  post-baseline and delete those rows, then upload the edited
  spreadsheet for the analysis of human-adjudicated baseline variables.
- **What changed.** `.ppDurationLabel()` names the durations class
  (durations of surgery, anaesthesia, operation or procedure; operative
  and anaesthesia time; blood loss; incision-to-delivery intervals;
  intra-operative fluids). It leaves the outcome vocabulary: with the
  chosen table's block at hand a duration is judged as the table's row
  (printed there, spared; brought in from another table, refused as
  before); with no block - the model-only routes - it is never refused.
  `parseBaselineTable(durations = "include" | "exclude")`, applied to
  whatever route produced the table, keeps the rows with a flag that
  names them, or moves them to `$skipped` with the reason. The service
  takes `?durations=exclude` on `/parse` and `/analyze`, validated like
  the seed and echoed when sent. The app reads `?durations=exclude` from
  its address, shows the radio button once a parsed table prints such
  rows, and on "Exclude durations" blanks their values in the grid
  (the names stay, as the parser's skipped lines do) and on "Include
  durations" restores them.
- **Tests** (`tests/testthat/test-durations-option.R`): the class on
  labels that belong and labels that do not ("Duration of diabetes",
  "QT interval"); the outcome test with and without a block; the option
  on a rebuilt page through `parseBaselineTable()` and through the batch
  reader's subprocess; the service's argument reader; the app's address
  reader; the app's radio button blanking and restoring rows in a
  `testServer()` session. The issue 64 and 66 tests now expect the
  durations kept and a true outcome refused.

---

## 73. A stratum's name stands at the row-label margin, left of the arm columns

**Status: fixed on `fix/stratum-lead-left-of-arms`, 2026-09-25**, from the
corpus session's batch 16 finding V1 (Akkuş 2020, J Anesth 34:512; Loadsman
corpus, page 4).

- **The defect.** An arm name that wraps - "Group stand-" over "ard (n =
  49)" beside "Group triple (n = 49)" - puts a labelled "(n = k)" line
  under the header, and the stratum rule of issue 55 took "ard" for a
  stratum: arm 1 lost its N (a stratum's sole size is never an arm's) and
  every row went out prefixed "ard: ".
- **What changed.** A labelled size line is a stratum only when its
  name begins left of the first arm column (the row-label margin, where a
  stratum's name is printed); a wrapped arm name's second line begins
  inside its arm's column and is left to the header, which reads its
  "(n = 49)" for that arm. The arm is named "Group stand- ard".
- **Tests** (`tests/testthat/test-stratum-lead-left-of-arms.R`): a rebuilt
  page with the wrapped arm name reads two arms of 49 with no prefix and
  every cell (fails on the unfixed code); a stratum line at the margin is
  still a stratum.

---

## 72. The page's gutters are taken widest first, and no band is ever dropped

**Status: fixed on `fix/widest-gutters-no-hole`, 2026-09-25**, from the
corpus session's batch 16 finding V1 (Akkuş 2020, J Anesth 34:512; Loadsman
corpus, page 4, Table 1, two arms of 49).

- **The defect.** `.ppPageBands()` meant to keep the two widest
  low-coverage runs as gutters, but sorted the candidates by width and
  then re-sorted them by position before taking two - the two LEFTMOST
  runs, whatever their width - and then dropped any band narrower than a
  fifth of the page. On that page three runs qualified: two gaps inside
  Table 1's own columns (19 and 12 points) and the page's real gutter
  (25 points). The two table gaps were taken, the 55-point band between
  them was dropped, and the words in it - the table's second arm, "Group
  triple" and every one of its cells - belonged to no column and were
  read by no candidate. The column-1 candidate read one arm; the
  full-width candidate read the table interleaved with column-2 prose
  and stopped at the first long prose line. On d04ccb6 the full-width
  reading happened to win (3 variables x 2 arms, a junk "ard: " prefix
  from the wrapped arm name, issue 73); on e88bd83 the one-arm column
  reading read 11 variables and won, and the screen saw one arm.
- **What changed.** The gutters are taken widest first, and a gutter is
  kept only if every band it leaves is at least a fifth of the page wide;
  a narrower one is skipped, not cut and discarded. No band is dropped,
  so every word of the page lies in exactly one band. With issue 73 the
  page reads 11 variables x 2 arms of 49 from column 1.
- **Tests** (`tests/testthat/test-widest-gutters-no-hole.R`): a page of
  word boxes with two table-internal gaps left of the real gutter gives
  two bands cut at the gutter with every word in a band (fails on the
  unfixed code); a genuine three-column page still gives three bands; a
  gutter that would leave a band too narrow is skipped.

---

## 71. The header's "(n = k)" count is a second opinion when the gap rule fuses two narrow columns

**Status: fixed on `feat/columns-from-header-count`, 2026-09-25**, from the
corpus session's batch 15a finding T1 (Fujii & Itakura 2009, Int J Gynecol
Obstet; PMID 19358990).

- **The defect.** Three arms of 30 in columns 35 points apart; the
  "(n = 30)" header tokens sit 8 points right of the cells beneath them,
  so the gap between the first two columns' tokens is 22 points and the
  column clustering (a cut wherever neighbouring midpoints are more than
  25 points apart) fused them. The deterministic engine has read two arms
  there on every build - "Placebo Propofol, 0.25" and "g/kg Propofol,
  0.5 mg/kg" - and the trial's reading was the hybrid's, which changed
  with the model's reply. (The corpus session filed it as a d04ccb6
  regression; the deterministic reading is identical on 8e8fbd5.)
- **What changed.** `.ppClusterColumns()` takes an expected count `k`:
  the midpoints are cut at the k - 1 widest gaps, accepted only when the
  narrowest of those gaps is a real column gap (12 points or more) and
  wider than every column's own spread - a header that counts a total
  column asks for one column too many, and the spread test refuses the
  split of a real column. The block walker asks for it when the header
  prints k "(n = k)" groups and the gap rule found fewer, with only FULL
  ROWS beneath the header voting (exactly one cell per arm; at least two
  such rows): an arm-name line above the header that carries numbers
  ("Propofol, 0.25 g/kg") and a short row set between the columns ("Dose
  of propofol at the 0 (2) 28 (3)") would otherwise widen a column past
  its cut. And the header count is taken from a "(n = k)" line that
  follows such an arm-name line - a line of plain numbers only - where
  before the first data line ended the search (a row's own "(n = k)" line,
  issue 47, always follows a measured row).
- **On the page.** 7 variables x 3 arms of 30: Placebo, "Propofol, 0.25",
  "Propofol, 0.5".
- **Tests** (`tests/testthat/test-columns-from-header-count.R`): the
  clusterer with `k` on fused midpoints, on one column too many, and on a
  column whose spread exceeds the cut; a rebuilt page whose columns the
  gap rule fuses reads three arms of 30 (fails on the unfixed code).

---

## 70. A glued plus-minus soup never eats the number it is glued to

**Status: fixed on `fix/glued-soup-never-eats-number`, 2026-09-25**, from
the corpus session's batch 15a finding T2 (Fujii 1996, Can J Anaesth; PMID
8706192).

- **The defect.** Issue 65's glued form ("-t-32": the soup and the SD as
  one word) used a character class that held "4" and ".", so "+4.9" - a
  plain plus set against its SD, which the plus rules of issue 45 own -
  matched as the soup "+4." and the SD "9". Height's second arm went out
  as 154.1 ± 9.0 for the printed 4.9: a wrong number, not a lost one, and
  in a hybrid result the flags had nothing to say. Introduced on d04ccb6;
  the other three regressions the corpus session filed with it (PMIDs
  19358990, 7497558, 9649986) are not the engine's - the deterministic
  reading is identical on 8e8fbd5 and d04ccb6 for all three, and the
  change was the model's reply on the hybrid route.
- **What changed.** The glued prefix is strokes and stroke-like letters
  only, with no digit and no dot; a dot is no longer soup at all. One
  digit form is admitted, "5:" - a digit and a colon, which is how that
  page's OCR sets the sign in "55.3 5:5.4" - and only at a sign slot,
  never on the announcement alone. The page now reads 8 variables x 4
  arms with every Weight and Duration cell (the first Height cell,
  "155.0-1-5.5", is one fused word and stays lost).
- **Tests** (`tests/testthat/test-glued-soup-digits.R`): "+4.9" at a slot
  is left alone; "5:5.4" at a slot is the sign glued to its SD and on the
  legend alone is not; "4." and "." between two numbers are never a sign.
  The first two fail on the unfixed code.

---

## 69. A row label that wraps onto two lines beneath its values

**Status: fixed on `feat/label-wraps-twice`, 2026-09-25**, from the corpus
session's batch 15 residue on Fujii 2006 (PMID 17126782, after issue 67).

- **The defect.** "Propofol doses" over the values, then "given at", then
  "first (mg)*": three lines for one name. The continuation rule of
  2026-09-24 absorbed one line, and the row went out as "Propofol doses
  given at". (The corpus session's guess, that the rule did not apply to
  stratum-prefixed rows, was not it: the prefix is added afterwards; the
  rule simply stopped after one line.)
- **What changed.** The continuation rule loops: each further label-kind
  line is tested as the first was (begins with a lower-case letter or a
  bracket, at most 40 characters, no digit outside brackets, no indented
  child beneath it) and absorbed, up to three continuations. A
  capitalised line still ends the name. And `.ppCleanLabel()` drops a
  footnote marker (*, dagger, double dagger, section sign) from the end
  of a label before the unit rule, so "first (mg)*" loses its unit as
  "first (mg)" does - the row is "Propofol doses given at first".
- **Tests** (`tests/testthat/test-label-wraps-twice.R`): a rebuilt page
  reads the three-line name whole (fails on the unfixed code); a
  capitalised heading after a continuation is the next variable, with its
  levels intact.

---

## 68. A row label on the line above its values, the unit beneath

**Status: fixed on `feat/label-above-values`, 2026-09-25**, from the corpus
session's batch 14 finding S1 (Rezk 2015, Clin Exp Obstet Gynecol; Loadsman
corpus, page 3, Table 1 "Maternal characteristics").

- **The defect.** In a narrow first column "Duration of active phase
  (hours)" wraps to two lines and the typesetter centres the cells on the
  pair: "Duration of active phase" / "5.25 ± 0.86  5.31 ± 0.85" /
  "(hours)". The values' line carries no label at all, so the row went out
  as "Unnamed" on both engines, and the name above it opened a category
  heading that nothing used. The wrapped-label rule of 2026-09-24 covers
  the opposite layout only (label on the values' line, continuation
  beneath).
- **What changed.** A value line with no label directly beneath the line
  that opened the heading takes that line as its name, and the heading
  closes - a level of a category always carries its own label, so a
  label-less value line under a heading is the heading's own wrapped
  name, never a level. The unit line beneath is then absorbed by the
  continuation rule as any wrapped second line is. `catHeaderAt` records
  which line opened the heading.
- **Tests** (`tests/testthat/test-label-above-values.R`): a rebuilt page
  names the row "Duration of active phase" with its two cells, leaves no
  "Unnamed" row and no "(hours)" heading, and validates (fails on the
  unfixed code); a category heading over labelled level rows is still a
  heading.

---

## 67. A legend that names a letter as the plus-minus ("Values are means F SD") makes that letter the sign

**Status: fixed on `feat/announced-letter-glyph`, 2026-09-25**, from the
corpus session's batch 13 finding R1 (Fujii 2006, PMID 17126782).

- **The defect.** The Symbol-font plus-minus is mapped to "F" throughout
  Table 1 - "Age (y) 30 F 4 31 F 5 32 F 5 31 F 4" - and the legend reads
  "Values are means F SD or numbers." The deterministic engine read two
  variables and one arm, so the stratum lines of issue 55 ("Young
  patients (n = 80)", "Elderly patients (n = 80)") had no rows to prefix,
  and the trial's reading was the model's alone: a different shape on each
  run (32 prefixed rows and p 0.003 on one build, eight arms and p 0.9999
  on the next - the pooled-strata value). The corpus session's guess, that
  issue 63's "[ranges]" rule stripped the stratum line's "[n = 60]", was
  not it: that rule removes "[ranges]"/"[range]"/"[min-max]" only, and the
  deterministic reading is identical on d40fbbb, e4660eb, d024752 and
  8e8fbd5.
- **What changed.** The announcement scan of `.ppRepairPlusMinusGlyphs()`
  (issue 65) accepts "means" as "mean", and a single letter as the
  announced glyph; the letter between two numbers is then the sign, two
  or more to a line as the other announced notations require. A letter is
  never a sign unannounced, and only the announced letter is one. The
  digit case ("mean 6 sd") stays with the block walker's digitSD rule.
- **On the page.** 10 variables x 4 arms of 20, nothing skipped, every
  row prefixed by its stratum - deterministic, no model needed.
- **Tests** (`tests/testthat/test-announced-letter-glyph.R`): the helper
  on hand-built lines (announced letter repaired, unannounced left, "means
  and SD" names no glyph, another letter is not the sign); a rebuilt page
  reads its three continuous variables and validates. Both fail on the
  unfixed code.

---

## 66. The outcome refusal applies on the explicit `ai = "always"` route too

**Status: fixed on `feat/refusal-on-always-route`, 2026-09-25**, from the
corpus session's batch 13 finding R2 (Fujii, PMID 9542558; engine "ai").

- **The defect.** Issue 64 put the outcome refusal on the retry route (the
  deterministic pass failed and the model read the page alone) and left
  the explicit `ai = "always"` route untouched. The corpus batches use
  exactly that route as their second pass, so every retry-decided trial
  (about 55 of the 149 Carlisle trials) bypassed the refusal: on PMID
  9542558 the model's reading kept Table 2's operative management
  (duration of surgery, duration of uterus exteriorised, I-D interval,
  total ephedrine, total fentanyl, tubal ligation) beside Table 1's five
  rows - 16 rows became 40 and p moved from 0.059 to 7e-05 - while the
  same page through the fallback route (PMID 15476909) was refused.
- **What changed.** The refusal is one helper, `.ppRefuseModelOutcomes()`
  in `R/parseBaselineTable.R`: on a model-only result (`engine` "ai") the
  vocabulary of `.ppOutcomeLabel()` decides, a refused row leaves `$data`
  and `$provenance` for `$skipped` with its reason, and a flag names it.
  The retry route and the `ai = "always"` route both call it. The roxygen
  for `ai = "always"` says so.
- **Tests** (`tests/testthat/test-refusal-on-always-route.R`): a mocked
  model table through `ai = "always"` keeps Age and refuses "Duration of
  surgery", "I-D interval" and "Total ephedrine" with the reason and the
  flag (fails on the unfixed code); the helper leaves a result with no
  outcome label untouched and ignores other engines.

---

## 65. A scanned page's plus-minus soup is repaired by the column where the other rows set the sign

**Status: fixed on `feat/ocr-plusminus-slots`, 2026-09-25**, from the corpus
session's batch 12 finding Q1 (Fujii 1994, Can J Anaesth 41:291; PMID
7954995).

- **The defect.** The OCR text layer sets the plus-minus differently from
  one cell to the next: "46.7 • 7.7 46.3 • 11.8 44.1 + 9.0 45.4 + 7.9",
  then "152.9 • 5.4 154.4 :i: 4.9 153.8 + 4.8 152.8 -t- 5.1", "54.2 -I-
  7.1", "82 4- 31 81 -t-32". The bullet and the plus are known (issue
  45), the rest were not, and a row with fewer than two readable cells
  lost every cell it had: four rows of five. The table spans both page
  columns, and the half of it inside column 1 (4 variables x 2 arms)
  then out-scored the whole of it read full width (2 variables x 4
  arms), so the screen saw two arms of four and the model was consulted
  for the rest.
- **What changed.** Before a block is tokenized, its lines are read for
  their plus-minus *slots*: x positions at which two or more lines set a
  genuine sign (the glyph, the bullet, "+/-", or a "+" between two
  numbers). In any line, a short glyph-soup word (up to four characters
  of strokes, dots, colons, "i", "I", "l", "t" or "4") that starts at a
  slot between two numbers is the sign; one glued to its SD ("-t-32") is
  cut off. The block must show at least two genuine signs of its own, or
  announce the notation with a soup glyph ("All values are expressed as
  mean -t- SD." - then every line with two or more soup cells is
  repaired, slot or no slot). A plain "+" is evidence for a slot but is
  never repaired here; whether "5 + 2" is a cell stays with issue 45's
  rules. A glued soup must be at least two characters, so a negative
  number is never touched. `.ppRepairPlusMinusGlyphs()` in `R/utils.R`,
  called at the head of `.ppParseBlock()`.
- **On the page.** The full-width reading is now 5 variables x 4 arms of
  25 with nothing skipped, and it wins (score 31 against 21 for the cut
  half).
- **Tests** (`tests/testthat/test-ocr-plusminus-slots.R`): a rebuilt page
  with the paper's glyphs reads all five variables across four arms and
  validates; all-soup rows with no genuine sign and no announcement are
  left alone; the announcement alone licenses the repair; the helper on
  hand-built lines (a slot needs two lines, a lone glyph at no slot is
  not a sign, a negative number is never a glued sign, the plain "+" is
  not repaired).

---

## 64. The outcome refusal applies on the AI-only retry route too, by vocabulary alone

**Status: fixed on `feat/refusal-on-ai-route`, 2026-09-25**, from the
corpus session's batch 11 finding P2 (Fujii, PMID 9773135; engine "ai").

- **The defect.** Issues 54 and 61 refuse a model-added outcome variable
  in the hybrid merge. On the retry route - the deterministic engine
  failed and the model read the page alone - nothing did: the model's
  table carried Table 2's operative management (duration of surgery,
  duration of uterus exteriorised, I-D interval, tubal ligation) beside
  Table 1's Age, Height, Weight, Gestational age and Multiparous, and
  p moved from 0.24 to 0.039.
- **What changed.** The test is one helper, `.ppOutcomeLabel(labels,
  blockText)`: the vocabulary of issue 54, sparing a label printed in the
  chosen table's block (issue 61). The merge calls it with the block; the
  AI-only retry route calls it with no block, so the vocabulary alone
  decides, and a refused row leaves `$data` and `$provenance` for
  `$skipped` with its reason and a flag. The explicit `ai = "always"`
  route is untouched.
- **Tests** (`tests/testthat/test-refusal-on-ai-route.R`): the helper with
  and without a block; a mocked AI-only parse keeps Age and refuses
  "Duration of surgery" and "I-D interval" with the reason and the flag.

---

## 63. A mean ± SD cell with a bracketed range appended, a "+" as its plus-minus, and a "[ranges]" label suffix

**Status: fixed on `feat/meansd-with-range`, 2026-09-25**, from the corpus
session's batch 11 finding P1 (Fujii 1998, Eur J Anaesthesiol 15:287; PMID
9649986).

- **The defect.** Rows print as "Height (cm) [ranges] 153.3 + 6.7[147-171]
  157.8 +6.5[145-172] …" across four arms of 30: the plus-minus set as a
  plain "+", and the range in brackets straight after the SD. The
  tokenizer took the mean as a plain number and the "6.7[147-171]" as a
  median with a range, so every such row was skipped; only Age survived
  on `e8c145d`, and p moved from 0.057 to 0.60.
- **What changed.** A mean ± SD token may carry a bracketed range, and a
  "+" between two numbers is a plus-minus when a bracketed range follows
  (without the range it stays two numbers for the announced rules of
  issue 45); the range's separator may be a hyphen, an en dash, the
  Unicode minus or "to". A trailing "[ranges]" / "[range]" / "[min-max]"
  on a label is notation and is removed before the unit.
- **On the page.** Age, Height and the two durations read deterministically
  with four arms of 30. Residues: the Weight row is interleaved with the
  page's upside-down running head ("ueadoing … sickness"), and the arm
  names are lost to a mangled header; Height's third cell prints
  "157.346.1" with the glyph dropped entirely.
- **Tests** (`tests/testthat/test-meansd-with-range.R`): the tokenizer on
  both cell forms and on a rangeless "5 + 2"; the label suffix; a rebuilt
  page reads its three variables and three arms of 30 and validates.

---

## 62. A column of a different population beside the randomised arms is a review flag

**Status: fixed on `feat/other-population-arm-flag`, 2026-09-25**, from
the corpus session's batch 9 finding O2 (AAS1998_851, Saitoh).

- **The defect.** Table 1 sets fifteen volunteers beside three randomised
  current groups of 40 (and a single "supramaximality" patient, rightly
  dropped). The cells are right, but the volunteers are not an arm of the
  trial, and carried as a fourth arm they moved P_FULL from 0.34 to
  0.043 on the categorical rows.
- **What changed.** `reviewFlags()` names an arm whose header word is
  volunteers, healthy controls or subjects, normal subjects or controls,
  or non-randomised, and asks for the column to be removed before
  analysis unless it was randomised too. The engine does not decide what
  the trial randomised; the reviewer does.
- **Tests** (`tests/testthat/test-other-population-arm-flag.R`): the flag
  fires for such names and names the arm; ordinary arms raise nothing.

---

## 61. The outcome refusal spares a model row that the chosen table itself prints

**Status: fixed on `feat/refusal-spares-printed-rows`, 2026-09-25**, from
the corpus session's batch 9 finding O1 (Polat 2015 KJMS; Sakızcı-Uyar
2021 EJA).

- **The defect.** Issue 54 refuses a model-added variable whose label
  names an outcome, meant for rows the model brings in from another
  table. Both papers print "Duration of anesthesia" and "Duration of
  surgery" in their own Table 1; the deterministic pass skipped them (a
  median, a cell it could not read), the model supplied them, and the
  refusal threw them out: Polat rested on Age and BMI (P_FULL 0.60 →
  0.16), Sakızcı-Uyar lost two of its rows.
- **What changed.** The block parser returns the text of its own block
  (caption to last data row) as `blockText`, the driver and the hybrid
  assembly carry it, and the refusal spares a model label whose first two
  words of three letters or more appear on one line of that block: the
  engine reads what the caption's table prints, on either route. Whether
  a post-randomisation duration printed in a baseline table belongs in
  the screen is a policy question, held for Steve.
- **Tests** (`tests/testthat/test-refusal-spares-printed-rows.R`): with a
  mocked model supplying the table's own skipped "Duration of surgery
  (min)" and a "Time to first analgesic request" from elsewhere, the
  first is kept and the second refused; the block text rides on the
  result.

---

## 60. The row flags are recomputed on the merged table, so a degenerate row the model adds is named

**Status: fixed on `feat/post-merge-row-flags`, 2026-09-25**, from the
corpus session's batch 8 finding N4 (PMID 15281514, a canine paper).

- **The defect.** The hybrid merge appended eight "%Edi" rows at 100.0 ±
  0.0 - a normalised baseline fixed by construction - and issue 36's
  degenerate flag, computed on the deterministic table before the model's
  rows joined it, never named them; the reviewer saw a clean flag list
  over a table with eight rows that carry no sampling information.
- **What changed.** After the merge, the flags that describe rows -
  degenerate rows, duplicated tuples, SD above the mean, a variable short
  of arms - are taken from `reviewFlags()` on the merged result and added
  once to the flags already carried.
- **Tests** (`tests/testthat/test-post-merge-row-flags.R`): with a mocked
  model adding a variable at 100.0 ± 0.0 in every arm, the hybrid result
  carries the degenerate flag naming it, and the flags the merge already
  carried appear once.

---

## 59. The announced plus-minus digit as a token of its own: "Values are mean 6 sd." and cells "141 6 9"

**Status: partly fixed on `feat/digit-plusminus-token`, 2026-09-25**, from
the corpus session's batch 8 finding N1 (Fujii 1999, PMID 10475325).

- **The defect.** The Symbol-font plus-minus of that paper is set as the
  digit 6, separated from its numbers by spaces ("Values are mean 6 sd."
  and "=" as "5": "HR 5 heart rate"), so every cell was three plain
  tokens. Issue 45's "mean2SD" rule handled the fused form ("49.527.9")
  only; the cells stayed counts, the long layout (groups as rows,
  Baseline / Fatigued / 30 min as columns) was read wide with the
  timepoints as arms, and the model, completing, added ", Fatigued"
  rows.
- **What changed.** With a digit announced between "mean" and "SD", three
  plain tokens in a row whose middle one is that digit are one mean ± SD
  cell, at least two such triples on the line, as the other announced
  notations require; unannounced, a 6 between two counts stays three
  counts.
- **What remains.** With the cells read, the repeated-measures reader of
  issue 34 still declines this table (its Group II row lost its label to
  the text layer, and the header line carries the caption's wrapped
  text), so the wide path reads Baseline and Fatigued as the arms. The
  reader's admission rule is the next step on this paper.
- **Tests** (`tests/testthat/test-digit-plusminus-token.R`): the announced
  page reads three arms with their means and SDs and validates; an
  unannounced "4 6 3" row stays counts.

---

## 58. A supplementary table's caption, "Table S1", is a caption anchor

**Status: fixed on `feat/supplementary-table-anchor`, 2026-09-25**, from
the Loadsman corpus's 2018RezkIJGO, which files its baseline table as
"Table S1. Characteristics of the study participants" while its Table 1
is an outcome.

- **The defect.** The caption anchor knew only a plain or Roman numeral
  after "Table", so "Table S1" was no caption and a paper whose baseline
  table is supplementary had no candidate for it. (That paper's
  supplement is not in its PDF - page 5 holds the captions alone - so it
  remains unparsed; the rule stands for the supplements that are.)
- **What changed.** "S" followed by one or two digits is a table number
  for `.ppCaptionAnchors()`, `.ppCaptionStart()`, `.ppCaptionAnchorList()`
  and the bare-caption rule of issue 45.
- **Tests** (`tests/testthat/test-supplementary-table-anchor.R`): the
  anchor, the caption-start test and the anchor list accept "Table S1";
  a rebuilt page whose only table is "Table S1" parses.

---

## 57. A gutter no line of the page crosses is a column boundary at eight points wide

**Status: fixed on `feat/narrow-gutter-band`, 2026-09-25**, from the
Loadsman corpus (Altuntaş 2016, Turk J Anaesthesiol Reanim), one of the
five papers `corpus/checkLoadsman.R` still could not parse.

- **The defect.** The page's two columns are nine points apart, short of
  `.ppPageBands()`' minimum gap of twelve, so no band was found and the
  table in column 2 was read interleaved with column 1's prose ("Sex
  0.510" on the line "ence to VAS (while resting, coughing, during
  mobilization)"): no usable rows.
- **What changed.** A run of at least eight points that NO line of the
  page crosses is a gutter too. Zero coverage over every line is the
  signature of the page's own layout: a gap inside a table's columns is
  crossed by the prose lines above and below it, and the twelve-point
  rule with its 8% tolerance stands for those.
- **On the corpus.** `corpus/checkLoadsman.R`: 81 → 82 of 87 (Altuntaş
  reads Group I/II/III of 30, Age, Sex, ASA and the table's clinical
  rows); the caption-straddle pages and the layout suites are unchanged.
- **Tests** (`tests/testthat/test-narrow-gutter-band.R`): an eight-point
  gutter no line crosses splits a synthetic page; the same gap crossed by
  six lines does not; a wide gutter still splits when a few lines cross
  it.

---

## 56. "Group 60 50 40 30 20 Volunteers": a Group line whose values are the arms' names is the arm-name line

**Status: fixed on `feat/group-name-line`, 2026-09-25**, from the corpus
session's batch 5 finding K2 (CJA 1995;42:992, Saitoh).

- **The defect.** Six arms named by their stimulating current, "Group 60
  50 40 30 20 Volunteers", over "n 15 15 15 15 15 15". The line was data
  to the classifier - the label "Group" with five plain numbers - so it
  was skipped as a bare number and the six arms went unnamed (their N
  came from the n row).
- **What changed.** Beside the ordinal rule of issues 45 and 50: a data
  line whose label is the word Group (or Arm, Treatment) and whose values
  are all whole numbers, standing above the first line that holds a value
  cell, is the arm-name line; reclassified as a label, its numbers name
  the arms as printed and the words after them name the rest. A "Group"
  row of counts below the first value line stays data.
- **Tests** (`tests/testthat/test-group-name-line.R`): the rebuilt page
  names its six arms "60" … "Volunteers" with N 15 from the n row; a
  "Group" level row under a heading, below the values, is still a level.

---

## 55. A labelled "(n = k)" line inside a table opens a stratum: the rows beneath carry its arm sizes and its name

**Status: fixed on `feat/stratum-header`, 2026-09-25**, from the corpus
session's batch 7 finding M1 (Fujii & Nakayama 2006, Clin Ther; PMID
16982288).

- **The defect.** Table I prints "Young patients (n = 75) (n = 25) (n =
  25) (n = 25)" and, half-way down, "Older patients (n = 75) (n = 25) (n
  = 25) (n = 25)" under a column header of "(n = 50)", each stratum with
  the same variables as "Mean (SD)" / "Range" sub-rows. The stratum lines
  were header kinds the walker skipped (the first one, above the first
  data row, even fed the header's arm sizes), so the rows beneath took
  the column header's 50, the second stratum's variables came out as
  "Age, y 2", and the hybrid reading had every variable three times
  (p 0.14 → 0.25 for a table the model alone had read right).
- **What changed.** A labelled "(n = k)" line after the first header line
  - the label at least three letters and not the N row's own words - is a
  stratum line wherever it sits. The header reads its arm sizes from the
  column header alone; the block walker starts at the first stratum line
  when one stands above the first data row; on reaching a stratum line
  it sets the arm sizes for the rows beneath (a match left of the first
  arm column, the stratum's own total, is ignored) and closes any open
  heading. After the walk, each stratum's rows take its name as a prefix
  ("Young patients: Age, y"), and a name `.ppUniqueName()` had suffixed
  because an earlier stratum used it takes its base back. The arms table
  keeps the column header's sizes. A bare "(n = k)" line - no label - is
  the row above's own n as before (issue 47). And a label line beginning
  with a footnote marker (*, †, ‡, §) never opens a heading: the page's
  "*No significant between-group differences were found." had become a
  category heading for the stray numbers beneath it.
- **On the page.** Two strata of three arms of 25: Age, Height, Weight
  and Initial propofol dose as "Young patients: …" and "Older patients:
  …", Sex as a fraction category in each; the table validates; three named arms of 50 in the arms table. (A first
  reading left the label column's "Characteristic" as a fourth arm holding
  a header "(n = 50)": the footnote "*No significant …" carried no space
  after its asterisk, the stop pattern let the prose beneath run on into
  the block, and its numbers seeded that column. The marker now ends the
  block with or without the space.)
- **Tests** (`tests/testthat/test-stratum-header.R`): the rebuilt page
  reads both strata with N 25, prefixed names, no " 2" suffix, the
  fraction categories per stratum, the footnote as no heading, the arms
  table at 50; a bare "(n = k)" line under a row is still that row's n.
- **Follow-up (batch 8, N2: Fujii & Shiga 2006, PMID 17163298).** A
  first size line that names a population and states ONE size
  ("Younger patients (20–40y) [n = 60]"), the arm names standing on a line
  of their own above it, is a stratum too - taken for the column header
  it gave every arm the stratum's 60 and left the first stratum's rows
  unprefixed; a "[" before the size is cut like a "("; and the arms table
  falls back to the sizes the walk found (an N row inside a stratum) where
  the column header printed none. That page now reads both strata of three
  arms of 20 with prefixed names.

---

## 54. A variable the model adds to the baseline table is refused when its label names an outcome

**Status: fixed on `feat/refuse-model-outcome-rows`, 2026-09-25**, from
the corpus session's batch 6 finding L2 (Polat 2018 CMJ, Akkaya 2016) and
batch 7 finding M3 (Fujii 9542558).

- **The defect.** Asked for the baseline table beside the deterministic
  reading, the model on some runs returned the page's other tables too:
  "Time to T10", "Time to first analgesic request", Bradycardia /
  Hypotension / Nausea / Pruritus (Tables 2-3 of Polat), VAS and ODI at
  every follow-up (Akkaya), the operative-management table - duration of
  surgery, intervals, ephedrine and fentanyl doses - appended to Fujii
  9542558's five rows (p 0.059 → 6e-05). The call is not reproducible
  (thinking on), so a run may read every table on the page; the
  deterministic table is the baseline table by caption.
- **What changed.** In the hybrid merge a model-added variable whose
  label carries outcome vocabulary - time to, onset, first or rescue
  analgesia, VAS, ODI, a week/month/day of follow-up, post- or
  intra-operative, bradycardia, hypotension, nausea, vomiting, pruritus,
  shivering, satisfaction, complication, adverse, side effect, recovery,
  extubation, emergence, success, "at 24 h", duration of
  surgery/anaesthesia/operation, interval, ephedrine, phenylephrine,
  atropine, neostigmine, consumption, a total dose - is refused with its
  reason: it goes to `$skipped` and a flag names it, so a reviewer can
  bring it back by hand if the page files it as a baseline
  characteristic. The deterministic rows are never touched.
- **Tests** (`tests/testthat/test-refuse-model-outcome-rows.R`): with a
  mocked model returning a baseline variable, two outcome variables and
  an adverse-event category, the hybrid result adds the baseline
  variable, refuses the three others with the reason, and flags them.

---

## 53. A count (%) row the model called continuous is filed as a category, by the deterministic engine's own identity

**Status: fixed on `feat/model-count-pct-rows`, 2026-09-25**, from the
corpus session's batch 6 finding L3 (Ozkan 2019, Der Anaesthesist 68:90;
arms n = 26/25).

- **The defect.** The model returned "Intubation success (at the
  first-pass attempt)" 26 (100) / 20 (80) and "Mallampati score" 8 (31) /
  4 (16) as continuous rows, and the template took them as it does every
  model row: MEAN 26, SD 100. The percentages are the counts' share of the
  arm sizes, which the deterministic engine's own "a (b)" cells are tested
  for (issue 35) but a model row never was.
- **What changed.** In `.ppAiToTemplate()` a continuous row whose every
  arm prints a whole-number "mean", an "sd" in [0, 100], a known arm N,
  and an "sd" that is the count's percentage of that N to the rounding
  of one decimal, is filed as a category with the count and its
  complement (N − count), not as a mean and an SD. A label with "score",
  "index" or "ratio" keeps the model's reading whatever its numbers.
- **Tests** (`tests/testthat/test-model-count-pct-rows.R`): the success
  row becomes counts 26/20 with complements 0/5 while Age stays
  continuous and a "score" row is left alone; a row whose "sd" is not the
  count's share stays continuous.

---

## 52. The same variable under a label suffix, one cell apart, is one variable in the hybrid merge

**Status: fixed on `feat/label-suffix-merge-pairs`, 2026-09-25**, from the
corpus session's batch 5 finding K3 (CJA 1997;44:390, Saitoh).

- **The defect.** The table's "Weight" and the model's "Weight - kg" held
  the same six cells but one: the page prints "57.9 ± 64", a missing
  decimal point, which the table's reading takes as 6.4 and the model as
  64.0. The value signature did not match, both variables survived, and
  the variable was counted twice in the Stouffer combination.
- **What changed.** In the arm-by-arm comparison, two variables whose
  labels agree once a trailing unit or suffix is set aside (", kg",
  "- kg", "(kg)", "; cm") and whose cells agree in at least half the arms
  are one variable: the table's own reading is kept, the model's dropped,
  and a flag names the pair and the number of cells that differ, so a
  reviewer checks that cell against the printed table. A similar label
  whose cells mostly differ is still a new variable.
- **Tests** (`tests/testthat/test-label-suffix-merge-pairs.R`): with a
  mocked model returning "Weight - kg" one cell apart from the table's
  "Weight", the result holds Weight once with the table's cells and flags
  the pair; a "Weight - kg" whose cells all differ is added as new.

---

## 51. A continuous variable with fewer cells than the table has arms is a review flag, and a table the model completes reports itself as hybrid

**Status: fixed on `feat/short-variable-flag`, 2026-09-25**, from the
corpus session's batch 5 finding K2 (CJA 1995;42:992, six arms of 15)
and batch 6 finding L1.

- **The defect.** Age was read in all six arms, Height and Weight in
  four - the OCR of two cells failed - and the deterministic table was
  accepted as it stood: no review flag, so the fallback never consulted
  the model, and both variables entered the analysis two arms short
  (P_FULL 0.0368 against the model's six-arm 0.128 on the earlier build).
  Two more, found on the way: when the model's only contribution was to
  complete a variable's missing arm lines (issue 37's arm-by-arm merge),
  the result still called itself "heuristic" and dropped the model's
  notes; and the model's reply (`aiReply`, issue 43) rode only on the
  AI-only route, never on a hybrid result.
- **What changed.** `reviewFlags()` names every continuous variable that
  carries fewer cells than the table has arms ("Height (4 of 6)"); the
  flag gates the model consult, and the merge fills the missing cells
  from the model's reading, tagged "ai". A result the model completed
  without adding a variable is labelled "hybrid", carries the model's
  notes, and carries `aiReply`; the hybrid assembly carries `aiReply`
  too.
- **Tests** (`tests/testthat/test-short-variable-flag.R`): a rebuilt
  page with one unreadable cell raises the flag naming the variable and
  its count while full variables do not; with a mocked model the result
  is hybrid, the missing cell is filled and tagged, and the reply rides
  along.

---

## 50. An arm-name line of ordinals that goes on to head the statistic columns; arm sizes stated only in a CONSORT flow

**Status: fixed on `feat/ordinal-header-trailing`, 2026-09-25**, from the
corpus session's batch 5 finding K1 (RezkJMFNM2014, J Matern Fetal
Neonatal Med 2015;28:93), lost on `dc39659` after issue 39 let the
deterministic engine claim its unnumbered "Table Maternal characteristics
…".

- **The defect.** Three things. The header "Group 1 Group 2 Group 3 ANOVA
  test p value" was a data line to the classifier - issue 45's ordinal
  rule wanted nothing after the last number - so the arms went unnamed
  and the line was skipped as a bare number. The only sizes are in the
  flow diagram, "Assessed for eligibility (n=109) … Excluded (n=19) …
  Randomized (n=90) … Analyzed (n=30) Analyzed (n=30) Analyzed (n=30)",
  and the same "N = 30" under every arm of Tables 2-4: fourteen mentions
  for three arms, which the position rule (exactly k mentions summing
  to the total) refused. And the "ANOVA test" F column clustered as a
  fourth arm, so even the right count of mentions could not make "3 ×
  30 = 90".
- **What changed.** (1) The ordinal rule requires only the run of "word
  number" pairs from the line's start; what follows the last number is
  left to name the columns beyond the arms. (2) The position rule, when
  the mentions outnumber the arms, sets aside those that state a
  randomized total or sit in the flow's screening vocabulary (eligible,
  assessed, excluded, enrolled, lost, withdrawn, discontinued …); if
  exactly k remain they are tried by position as before, and if more
  remain but every one states the same n and k × n is the stated total,
  that n is every arm's, with its sentence. (3) "Randomized (n=90)", the
  flow's own box, counts as a stated total. (4) The text ladder sees only
  the arms that carry value cells (mean ± SD, mean (SD), n (%), a
  fraction, a median); a statistic column gets no N there and, having
  neither N nor cell, is dropped at assembly.
- **On the page.** Group 1/2/3 of 30 each; Age, Parity*, Gestational age
  and IAI with the printed values; validates.
- **Tests** (`tests/testthat/test-ordinal-header-consort.R`): the
  rebuilt page names its arms from the ordinal header, fills them from
  the flow, and reports no "ANOVA" arm; the position rule still refuses
  when the remaining mentions disagree or when k × n is not the total.

---

## 49. A categorical variable printed as one line, its levels named after the colon and every arm's counts side by side

**Status: fixed on `feat/levels-across-line`, 2026-09-25**, from the corpus
session's findings on RezkHiF2020 (the rotated table of issue 38) and
RezkPH2019 (K4 of batch 5).

- **The defect.** "Age (years): 20–30 31-40  78 (47.6%) 86 (52.4%)  70
  (43.75%) 90 (56.25%)  74 (45.7%) 88 (54.3%)" - the level names after
  the label's colon, then two n (%) cells per arm across the line; three
  such rows on the page. Six cells on a three-arm table seeded six
  columns, the continuous rows' three cells fell into three of them, and
  the report carried three phantom arms holding category counts; the
  levels came out as rows "≥", "≥P3", "Category 2" … and category
  columns "20", "80", "72".
- **What changed.** Before the columns are clustered, a data line is
  set aside as a spread row when the arm count k is printed in the
  header ("(n = 164)" k times), the line holds m × k n (%) cells in one
  run with an integer m ≥ 2, nothing but level parts before them and at
  most p-values after, and the text between the colon and the first cell
  names exactly m levels (`.ppSpreadLevels()`: a lone ≥/≤/</> is glued
  to the token after it). Its cells feed no column; the block walker
  emits the row from them, cell i to arm ⌈i/m⌉ and level (i−1) mod m + 1,
  with the level names as the category columns. A spread row whose k
  disagrees with the arms actually read is skipped with its reason.
- **On the page.** RezkHiF2020 now reads three arms of 164/160/162; Age
  (20–30, 31-40), Parity (P1-2, ≥P3) and Body mass index (18–25,
  25.1–29.9, ≥30) as category rows with the printed counts; the five
  continuous rows and the binary n (%) row as before; validateData
  accepts the table.
- **Tests** (`tests/testthat/test-levels-across-line.R`): the level
  names with a glued sign; a rebuilt page whose two spread rows read arm
  by arm beside ordinary continuous and binary rows, with the header's
  three arms and no phantom.

---

## 48. "Number" alone labels the N row; an arm with an N and nothing else is a phantom

**Status: fixed on `feat/n-row-label`, 2026-09-25**, from CJA 1996;43:362
(Loadsman corpus, Saitoh), whose Table I prints "Number 15 15 15 15" under
an arm-name header without "(n = k)".

- **The defect.** The N row's label pattern knew "n", "No. of patients"
  and "Number of patients/subjects" but not a bare "Number", so the line
  was skipped as a bare number and the arm sizes came from the Methods
  ladder instead - three of four, because the fourth arm's name is an
  OCR misreading ("PIT-AP" for the Methods' "PTT-AP") the ladder could
  not place. Reading the row then surfaced a fifth cluster on that page
  with an N and neither a header word nor a cell, reported as an arm.
- **What changed.** The N row's label is "n", "N", "No.", "Number", or
  "No./Number of" followed by a group noun (patients, subjects, cases,
  participants, animals, dogs, rats, rabbits, pigs, women, men, children,
  infants, volunteers); "Number of previous operations" is still a
  variable. At assembly an arm that has an N but neither a name nor a
  single data cell is dropped as the label-column phantoms already were.
- **On the page.** Four named arms of 15, Sex, Age, Height, Weight.
- **Tests** (`tests/testthat/test-n-row-label.R`): "Number" and its kin
  label the N row and every arm takes its size; a label that merely
  begins with a count word is not the N row.

---

## 47. A "(n = k)" line printed under a row's cells is that row's N

**Status: fixed on `feat/row-n-line`, 2026-09-25**, from the corpus
session's re-run of Fujii 2002 (PMID 12182258) on `dc39659`.

- **The defect.** "Last menstrual cycle, d*  15 ± 4  16 ± 3  16 ± 2  16
  ± 3" is followed by "(n = 12) (n = 13) (n = 12) (n = 12)" under its
  cells, and the footnote says why ("*N = 49. Patients who had
  experienced menopause were excluded"): that row was measured on fewer
  patients than the arm. The line is a header kind to the classifier
  and was skipped, so the row went out with the arm's N of 20 - and the
  hybrid merge, seeing the model's row with the printed 12/13/12/12 and
  the same means and SDs, kept both and double-counted the variable.
- **What changed.** In the block walker a "(n = k)" line directly under
  a continuous row, each count under one of the row's cells, sets that
  row's N arm by arm (the printed row-level n); every other row keeps
  the arm's N. With the N agreeing, the merge's value signature
  recognises the model's row as the same row and drops it.
- **Tests** (`tests/testthat/test-row-n-line.R`): the row under the
  "(n = k)" line takes 12/13/12/12 while its neighbours keep 20, and the
  table validates; with a mocked model returning that row under a
  different label, the hybrid result holds it once.

---

## 46. The OCR of a figure beneath a scanned table, and a footnote sentence between caption and header, stay out of the arms and the rows

**Status: fixed on `feat/junk-ocr-rows`, 2026-09-25**, from the corpus
session's junk-label finding G3 (CJA 1995;42:1096 = Fujii PMID 8595684, a
scanned page with an OCR text layer).

- **The defect.** Beneath that Table I the OCR of a figure's axis — "30",
  "20", "10" down the left, "15 20 25 30 35 40" along the bottom, "i I |
  I I t" for its ruled baseline — runs on inside the block. The lines
  carry numbers and no label, so they were data to the classifier, and
  their x positions seeded three columns no table cell ever used: the
  arm count went to five, the fence that keeps prose out of the arm
  names widened with it (three words per column), and the footnote
  sentence set between caption and header — "were no differences in
  number of patients, age, sex, height, or body weight" — named the arms
  "were no", "differences in", …, "or body PTC". The ticks became levels
  "Category" 1–3 of a heading "Sr", and "i I | I I t" a heading of its
  own.
- **What changed.** (1) A column fed only by label-less lines is not an
  arm column: header Ns aside, every cell of a table sits on a labelled
  line, so such columns are dropped with their tokens after clustering,
  and the columns re-clustered. (2) The prose fence applies to every
  label line that would name the arms, not only the one above a "(n =
  k)" header. (3) Under a heading, counts on a line with no label — or
  a "label" without a letter, what remains of a line whose tokens the
  column rule dropped — are not a level; skipped with the heading
  named. (4) A label line holding a "|" (a ruled border as OCR reads it)
  never opens a heading.
- **On the page.** With issue 45's "+"/bullet reading, CJA1995_1096 now
  reads its FULL-WIDTH Table I - four arms (PTBC, PTC, PTBC-TOF, PTC-TOF),
  Age, Height and Body weight, twelve cells that match the page, and
  nothing else. Before, the junk columns sank the full-width reading and
  the column-1 half (two arms) won. One residue: the fourth arm's N reads
  5 where OCR set the printed "15" as "i 5" on the "Number of patients"
  line, and a printed N outranks the text ladder's 15.
- **Tests** (`tests/testthat/test-junk-ocr-rows.R`): the rebuilt layout
  (footnote sentence, header without "(n = k)", the figure beneath) parses
  to two named arms of 15 and three variables, the ticks skipped as
  "no level name", no "Sr", "Time" or "|" row; a table whose every line is
  labelled is untouched by the column rule.

---

## 45. Three more ways a page prints its plus-minus, an arm-name line of ordinals, and a caption whose title sits under a bare "Table 1"

**Status: fixed on `feat/plusminus-glyphs`, 2026-09-25**, from the corpus
session's junk-label findings G2/G3 on the Saitoh papers of the Loadsman
corpus: CJA 1995;42:1096 (scanned), CJA 1997;44:390, Acta 1997;41:741.

- **The defect.** On each page the real Table 1 parsed to nothing and a
  results table or the model won. CJA 1995's OCR text layer sets the
  plus-minus as a plain "+" ("45.5 + 11.4", caption "(Number or mean +
  SD)") or a bullet ("56.7 • 6.9"); CJA 1997 mixes the bullet with a "+"
  in one row ("45.6 • 8.2 47.7 + 7.7 …") and names its arms "Group 1
  Group 2 Group 3 Group 4", a line the tokenizer read as the label
  "Group" with the values 1–4; Acta 1997's font maps the plus-minus to
  the digit 2, so the legend says "mean2SD" and a cell reads "49.527.9",
  one token to the tokenizer, and its caption line is the bare "Table 1"
  with the title on the line beneath, worth nothing to the caption score
  against Table 2's "fade/total (%)" rows.
- **What changed.** (1) A bullet between two numbers tokenizes as mean ±
  SD (tokenize.R; a bullet there means nothing else). (2) Two more
  announced notations beside the "mean − SD" dash re-read: "mean + SD"
  announced, a pair of non-negative plain tokens whose only separator in
  the printed line is "+" is one cell (at least two on the line); and a
  "+" pair is read unannounced on a line that already holds two mean ±
  SD cells. "mean2SD" announced (a digit between "mean" and "SD"), a
  token holding two decimal points is split at the occurrence of that
  digit where both halves are decimal numbers with the same number of
  decimals — "49.5|27.9", not "49.52|7.9" — and only when exactly one
  split qualifies; integer cells stay as they are. (3) A data line whose
  numbers are exactly 1..k in order, each preceded by the same word, is
  the arm-name line: reclassified as a label, its words name the arms.
  (4) A caption whose anchor line is the bare "Table N" takes the
  numberless line beneath as its title, for scoring and for the report.
- **On the corpus.** `corpus/checkLoadsman.R`: 79 → 80 of 87 (CJA1997_390
  now parses: four arms of 40/40/40/10, Age, Height, Weight). CJA1995_1096
  reads Age, Height and Body weight with N = 15/15; its residue — arm
  names taken from a prose sentence between caption and header, and two
  rows from a figure's OCR'd axis beneath the table ("Sr", "Time") — is
  the junk-label issue that follows. AAS1997_741 reads Table 1 with
  three arms of 15; "Gender (MIF) 718 718 718" (the "/" glyph mapped to
  "1") is not repairable and is skipped.
- **Tests** (`tests/testthat/test-plusminus-glyphs.R`): the bullet
  tokenizes; the announced "+" page parses with the bullet row; the
  unannounced "+" is read only beside two mean ± SD cells, and a lone
  "5 + 2" is not; "Group 1..4" names the arms; the "mean2SD" page splits
  its fused cells and takes its title line into the caption, and the
  same cells stay fused when nothing announces the notation.

---


---

## 44. A variable's heading above the first data line, legend-labelled statistic lines, and stretched watermark letters

**Status: fixed on `feat/heading-above-first-row`, 2026-09-25**, from the
corpus session's batch 4b (Fujii 2002, PMID 12182258, Carlisle-168: the
"Mean ± SD" and "R Duration of anesthesia, min 20l ±" rows).

- **The layout.** Every variable of that Table 1 is set as a heading
  line with its statistics beneath it on lines labelled by the statistic:
  "Age, y" / "Mean ± SD 46 ± 8 47 ± 8 …" / "Range 33-57 34-63 …". The
  block walker starts at the first data line, so the first variable's
  heading was never seen and its row went out named "Mean ± SD"
  (the statRow rule names such a row by the open heading, and "Height,
  cm", whose heading lies inside the loop, was right). Each "Range" line
  was taken for the counts of a level and became a category row named
  "Height, cm 2" with the range's endpoints as cells.
- **The watermark.** The page also carries a watermark whose letters
  `pdf_data()` reports one at a time, each with a box 130 points wide at
  normal height, threaded between the table's lines and even off the
  page (x = −62): "C", "A", "R", "ET". The rail stripper looks for the
  opposite shape (narrow and tall), so they stayed: "A" became a label
  line between "Age, y" and its statistics, "R" a prefix on "Duration of
  anesthesia". That row's first cell, "20l ± 40" (the digit 1 set as a
  letter l), left its unread half in the label too.
- **What changed.** (1) `.ppStripStretchedGlyphs()` (pageLayout.R) drops
  a word wider than 30 points per character — no printed word is — and
  runs with the rail stripper. (2) The label lines directly above the
  first data line are read for a heading, with the label branch's own
  test and two more: the line lies left of the first value column (an
  arm-name line without "(n = k)" is a label line too, and sits over the
  columns), and it is not the caption's legend sentence ("Values are
  mean ± SD …"). (3) A "Range" / "Min–max" line under a heading is
  skipped with its reason ("range without mean or SD"), the heading
  staying open. (4) A one-letter label line never replaces the open
  heading. (5) A trailing "<word> ±" fragment is cut from a mean ± SD
  row's label; the unreadable arm is lost either way, and the row keeps
  its readable arms.
- **On the paper.** Eight variables named as printed (Age, Sex, Height,
  Body weight, Last menstrual cycle, Duration of surgery, Duration of
  anesthesia, Thyroid status), no junk rows, the three Range lines in
  `skipped` with their reason. `corpus/checkLoadsman.R` gains Altinsoy
  2015 and EJA1997_327 (78 of 87 on this tree, which predates issue 39).
- **Tests** (`tests/testthat/test-heading-above-first-row.R`): the
  stacked layout parses with its headings as row names, the Range lines
  skipped by name under their heading, the category intact; an arm-name
  line above the first data line is not taken for a heading; stretched
  letters are dropped while ordinary, one-letter and rotated words are
  kept; a one-letter label line leaves the open heading alone, and the
  "20l ±" fragment leaves the label.

---

## 43. The model's reply rides along verbatim on the parse result

**Status: fixed on `feat/model-raw-reply`, 2026-09-25**, from the corpus
session's batch 4b finding J2 (PMID 15278663 read as two arms on one run
and three on the next).

- **The defect.** The model transcription call runs with extended
  thinking on, which fixes the sampling temperature at 1, so two runs of
  the same page can disagree; the reply was parsed to JSON and discarded
  inside `aiFallback.R`, and only the merged table survived in the corpus
  checkpoints, so a disagreement could not be attributed to the model or
  to the template step.
- **What changed.** `.ppClaudeStructuredOutput()` attaches the reply text
  to the structured output, and `parseBaselineTableAI()` returns it as
  `aiReply` (the JSON text as the model wrote it; NULL when a test double
  supplied the parsed list). The corpus batch stores it in the checkpoint;
  the app and the API are unchanged.
- **Tests** (`tests/testthat/test-model-raw-reply.R`): a reply split
  across two text blocks arrives as one string; through the whole route
  (mocked at the HTTP boundary) `aiReply` is the reply and parses back to
  the arms; a test double that hands back a plain list leaves it NULL.

---

## 42. A model-read table with no arm sizes gets the document-text ladder

**Status: fixed on `feat/model-arm-n-from-text`, 2026-09-25**, from the
corpus session's batch 4b finding J1 (Carlisle-168 on `bf9245b`).

- **The defect.** Nine of the eleven trials that failed validation
  failed on `N missing` in every row, all model-read on the retry
  (12933396, 15281514, 9806685, 11004073, 12088956, 8055614, 7889590,
  11132748, 8513526 — Fujii's canine papers). Their sizes are stated in
  the Methods ("Dogs were randomly divided into three groups of eight
  each", "In Group Ia (n = 5) ... In Groups IIa, IIb, and IIc (n = 8 in
  each)") and nowhere in the table; the model transcribes the page it is
  shown, so its arms came back with no N, and the text ladder of
  `armNRecovery.R` ran only inside the deterministic block parser.
- **What changed.** `.ppArmNFromDocument()` runs the two sources the
  deterministic engine and the repeated-measures reader already use, in
  the same order — the "into k groups of n" statement for exactly this
  many arms, then the "(n = k)" mentions matched to the arm names — and
  `parseBaselineTableAI()` applies it to the model's arms under the same
  gate: only when no arm has an N; a table that printed any size keeps
  the model's reading as it is. Each N carries its sentence in
  `armNSource`, the result carries the "verify against the CONSORT flow
  diagram" flag, and the fallback route keeps that flag behind its
  "deterministic parse failed" note. In the name match a roman group
  tag ("Ia", "IIb") now counts as a distinctive word, matched whole, so
  "Group I" does not claim "Group Ia"'s mention.
- **What it does not do.** 8513526 states three different sizes (two
  abstracts and the Methods disagree); the ladder's name match takes a
  mention only when every matching mention agrees, so a self-contradicting
  paper is left with N missing rather than a guess — the sentence used,
  when one is, is in the flag.
- **Tests** (`tests/testthat/test-model-arm-n-from-text.R`, the model
  mocked at the HTTP boundary so the whole route runs): the groups-of-n
  sentence sizes every arm, with the sentence in the flag and in
  `reviewFlags()`; per-group "(n = k)" mentions reach the right arms by
  their roman tags; a table that printed any size is left alone, and a
  document that states nothing leaves N missing; the fallback route
  keeps the model result's flags.

---

## 39. A paper's only table, captioned "TABLE" with no numeral, is found

**Status: fixed on `feat/unnumbered-caption`, 2026-09-25**, from the
corpus session's Loadsman batch (CJA1997_390 and CJA2003_342, the Saitoh
papers: "TABLE Demographic data", "TABLE Patient characteristics (number
or mean ± SD)").

- **The defect.** `.ppCaptionAnchors()` matched "Table" only when the
  next word was a numeral, so a journal that leaves a paper's single
  table unnumbered had no caption anchor at all, no candidate, and the
  parse failed with "no usable baseline table". Both papers went to the
  model, which read the outcomes.
- **What changed.** A bare "TABLE" or "Table" — the word itself, not a
  lower-case "table" inside a sentence — followed by a Capitalised word
  (which a numeral "I"/"II" and a cross-reference "Table shows" are not)
  is an anchor, provided it starts its block: unlike a numbered anchor,
  which is kept and demoted when prose precedes it, the unnumbered one
  has no evidence beyond the gap to its left. `.ppCaptionStart()` now
  answers "does this line begin a caption?" for the block walker, the
  continuation-page extender and the TATR adapter, so an unnumbered
  caption on a following page ends a block exactly as a numbered one.
  An unnumbered caption scores as a numbered one (`.ppCaptionScore`).
- **On the corpus.** `corpus/checkLoadsman.R`: 76 → 79 of 87 parse
  deterministically. CJA2003_342 reads its four arms (Sex 6/9, Age,
  Weight, Height) — its arm sizes are printed nowhere but in the sex
  fraction, which is issue 41. CJA1997_390 now finds its caption but
  still yields no rows: the page's "±" glyph reaches poppler as "•" or
  "+" ("45.6 • 8.2 47.7 + 7.7"), a font-encoding residue for a later
  issue.
- **Found on the way (issue 40).** The "first table" bonus in
  `.ppCaptionScore()` — +2 for "Table 1" / "Table I" — is a
  case-sensitive pattern, so it has never fired on a printed caption
  (only on a lower-case "table 1"). Making it fire is a scoring change
  across the whole corpus and is left for a measured PR of its own.
- **Tests** (`tests/testthat/test-unnumbered-caption.R`): the anchor
  forms that do and do not match (bare "TABLE" + capitalised word with
  and without a gap, a numbered cross-reference kept but demoted, a
  sentence's "table", "Table shows", "TABLE II" counted once);
  `.ppCaptionStart()` on eight lines; a synthetic page whose only table
  is "TABLE Demographic data" parses with its three arm sizes and
  values.

---

## 40. The "first table" caption bonus never fired

**Status: switched on, `feat/first-table-bonus`, 2026-09-25** (filed
2026-09-25 while fixing issue 39).

- **The defect.** `.ppCaptionScore()` adds 2 for a caption that begins
  "Table 1" or "Table I", the reasoning being that baseline data is
  nearly always the first table. The pattern was case-sensitive, so it
  matched only a lower-case "table 1" - which no journal prints - and
  every printed caption had scored without it since the rule was
  written.
- **The measurement** (`corpus/measureMisparse.R` on the 1,110
  Carlisle-linked PDFs, snapshot libraries built from main `dc39659`
  with and without the fix): fully corroborated files 435 → 444 of ~940
  with the bonus at +2 (441 at +1); corroborated share of our mean/SD
  pairs 59.4% → 61.2%; fourteen files changed bucket, twelve up (zero or
  partial → full) and two down (PMID 14687093, 14722167: the bonus picks
  the paper's real "Table 1 Induction characteristics" / "Table 1
  Physical characteristics" but the reading of it is poor, and Carlisle
  recorded Table 2's values).
- **What changed.** The pattern is case-insensitive at +2, and an
  unnumbered caption ("TABLE Demographic data", issue 39) - a paper's
  only table, so its first - takes the bonus too, so issue 39's equality
  of the two forms holds.
- **Tests** (`tests/testthat/test-unnumbered-caption.R`): a second
  table scores 2 less than the first, Arabic or Roman.

---

## 41. Arm sizes printed only as a sex fraction

**Status: fixed on `feat/arm-n-from-fraction`, 2026-09-25** (filed
2026-09-25 from the Loadsman corpus, CJA 2003;50:342).

- **The defect.** The table prints no "n =" anywhere; its only statement
  of the arm sizes is "Sex (female/male) 6/9" in every arm. The n (%)
  derivation of arm N (`.ppDeriveArmN`) had no counterpart for a
  fraction cell, so the table parsed with N missing in every arm and
  failed validation.
- **What changed.** Under the same gate as the n (%) derivation - only a
  table that printed no arm size at all - an arm whose every printed
  a/b fraction cell sums to one and the same value takes that value as
  its N, with its source recorded ("derived from k printed a/b fraction
  cell(s) of this arm"); two fraction rows that disagree leave N unknown,
  one of them not being the whole arm. `reviewFlags()` names the source
  beside the n (%) one.
- **On the page.** CJA2003_342 now reads four arms of 15 (Sex, Age,
  Weight, Height) and validates.
- **Tests** (`tests/testthat/test-arm-n-from-fraction.R`): every arm's N
  is the fraction's sum, with its source and flag, and the table
  validates; disagreeing fractions leave that arm unknown while agreeing
  ones are taken; one printed "(n = 15)" switches the derivation off.

---

## 38. A table printed sideways is read upright

**Status: fixed on `feat/rotated-table-page`, 2026-09-25**, from the
corpus session's finding I1 (`RezkHiF2020`, *Hypertens Pregnancy* 2020,
Loadsman corpus).

- **The defect.** The baseline table — Table 1 "Maternal
  characteristics", three arms of 164/160/162 — is printed rotated 90°
  on page 5. `pdf_data()` reports every one of its words with the box
  swapped (a few points wide, as tall as the word is long): exactly the
  signature the watermark-rail stripper (2026-08-22) removes, so the
  whole table vanished from the deterministic engine, and the caption
  page-chooser handed the model the *outcomes* page. Both engines scored
  Tables 2 and 3 (severe hypertension, NICU admission, neonatal
  mortality…) as the baseline table: 46 categorical rows, P_FULL = 1.0.
- **What changed.** `.ppRotatedBlock()` (pageLayout.R) finds a page's
  rotated words — a multi-character word taller than it is wide — and,
  when there are enough to be a table rather than a rail (at least 30,
  and a fifth of the page's multi-character words; that page has 142 of
  457), takes every rotated word plus the short words inside their box
  (a "±" or "162)" is square and cannot show its rotation) and
  transposes them into an upright page. The reading direction is read
  from the caption: on a table rotated counter-clockwise (the usual
  case) the word after "Table" sits *above* it on the page, so
  x′ = pageHeight − (y + height); clockwise, x′ = y. The block is
  appended to the document's pages before the rail stripper runs;
  `pageSource` maps it back to the real page for the report ("Table on
  page 5 (printed sideways; read upright)"), for the model's page image
  and for the `pages` argument, and a sideways page has no look-ahead
  and no continuation page.
- **On the article.** "Table 1. Maternal characteristics." wins; SBP
  152.12/151.13/151.1 (5.62/5.24/5.33), DBP, gestational age and
  duration of hypertension read with n = 164/160/162 — the numbers the
  corpus session read from the page — and `validateData` accepts the
  table. Two residues: the three categorical rows print their levels
  across the line ("20–30 31-40 78 (47.6%) 86 (52.4%) …"), a layout the
  engine does not model, so they are skipped with a reason; and the arm
  names are fragments until issue 37's header fix is in the same tree.
- **Tests** (`tests/testthat/test-rotated-table-page.R`): the pdf()
  device sets text sideways with `srt = 90` (`makeTablePdf()` now takes
  it) and poppler reports it exactly as it reports the real page, so a
  synthetic page with a rotated three-arm table beside upright prose
  exercises the whole route — the block is found and transposed without
  the prose, the caption and cells read in order, and the parse returns
  the caption, the values, the three arm sizes and the *real* page
  number; an upright page yields no block.

---

## 37. The hybrid merge compares continuous variables arm by arm; a header's "(n = k)" belongs to the name on its left

**Status: fixed on `fix/hybrid-merge-and-header-n`, 2026-09-25**, from
the corpus session's findings F2, F3, G1 and H2 (Loadsman and Fujii
corpora), each diagnosed read-only from its checkpoint.

- **What was wrong.** The merge's value-signature dedupe (2026-08-25)
  compared a variable's *complete* set of arm tuples, so a deterministic
  row that had read only some arms — "Height; cm" with 2 of 3 arms on
  `Anaesthesia2002_218`, "BMI kg/m" with 1 of 2 on `Akkuş 2020 JA` — never
  matched the model's complete row, and the variable survived twice,
  once under each name; on `PMID_9602596` (Fujii) every variable of the
  table was doubled that way (21 duplicated cells of 27, p = 0.0146 with
  each variable counted twice). A deterministic arm with no N never
  matched a model arm with one (`Kulturoglu 2024 JA`), and the model's N
  was not taken. A model level column differing from a deterministic one
  only by case ("male" beside "Male", `Sener 2008 EJA`) made two columns
  that normalise to one, and the validator refused the table. And the
  header "RIB group (n=24)  PECS group (n=24)  Control group (n=24)",
  left-aligned over columns narrower than the headings, put each
  count's midpoint nearer the *next* column's centre: arm 1's N went to
  arm 2, arm 2's to arm 3, arm 3's to the p-value column, and the stray
  "24)" opened the next arm's name.
- **What changed.** A model variable *is* a deterministic variable when
  every deterministic arm tuple (MEAN, SD, SE) appears among the model's,
  with N compared only where both sides have one; then the model's row is
  dropped, a deterministic arm with no N takes the model's N (flagged
  "taken from the model — verify against the header"), and arms the
  deterministic pass did not read are appended under the *deterministic*
  label, tagged "ai" in provenance. Categorical variables keep the
  whole-signature rule. A model level column whose squished, case-folded
  name equals a deterministic column's is that column. In the header, a
  "(n = k)" is read for the column of the word before it — the last word
  of the arm's name — and the count's own words are left out of every
  arm name. Kulturoglu reads three arms of 24 and validates.
- **Tests** (`tests/testthat/test-hybrid-merge-arms.R`, canned model
  replies through the real merge): a same-arms duplicate under another
  label is dropped while a genuinely new variable is added; a model row
  with a third arm the page did not read joins the deterministic
  variable and fills its missing Ns, with the flag and the provenance
  tag; a "male"/"female" model row lands in the deterministic
  "Male"/"Female" columns and the table validates; a synthetic header in
  Kulturoglu's geometry gives all three Ns and no stray "24)".
- Held, unchanged: the validator-level duplicate assertion (issue 36's
  reasoning — the duplicates are sometimes the data).

---

## 36. Rows that carry no sampling information are flagged at parse time: same value with zero dispersion in every arm, a median pinned at its quartile, and identical tuples under two labels

**Status: fixed on `feat/degenerate-row-flag`, 2026-09-25**, from the
corpus session's batch-1 and batch-2 findings on the Loadsman corpus,
at Steve's instruction ("add the degenerate-row flag at parse time").

- **The cases.** `MTS2006_49` prints "%Edi 100.0 ± 0.0" in every group
  by construction; `Akelma 2020 TJMS` prints intraoperative ephedrine
  as "0 (0–20) | 0 (0–20) | 0 (0–10)" — median = Q1 = 0 in every arm — and
  that one row scored p = 0.0039 and took the trial from 0.0084 to
  0.00094. Agreement at a bound is forced by the bound. And the
  retracted Saitoh trials `BJA2001_814` and `CJA2003_342` print Age and
  Weight with identical numbers in every arm — faithfully read from the
  page — so a duplicated (N, MEAN, SD) tuple across labels is sometimes
  the data, not the parser: a flag, never an assertion.
- **What changed.** `reviewFlags()` names (a) any variable whose every
  arm prints the same value with zero dispersion, or whose median equals
  its Q1 (or Q3) in every arm, as "fixed by design or by a floor, not a
  sample; consider removing before analysis"; and (b) any set of
  variables printing identical N, mean and SD in every arm, as "a row
  read twice, or the table as printed; check the page". Neither removes
  a row: removal is the validator's business and a contract decision
  (the non-fatal `suspect` code, still held for Steve with issue 35's
  SD > MEAN advisory). Both flags consult the AI under `ai =
  "fallback"`, as every flag does.
- **Tests** (`tests/testthat/test-degenerate-flags.R`, synthetic pages):
  each flag asserted by name on its own page; the controls that must not
  fire — zero SD in some arms only, the same mean with real SDs, an
  ordinary median row beside the pinned one, a clean table; and the
  duplicated pair still validates, because the engine does not refuse.
- Documented in `docs/parsepdf-architecture.md` §05f and the user guide's
  PDF section.

---

## 35. Duplicated variables, counts read as mean (SD), a banner word in a label — and the month-old library that produced the finding

**Status: fixed on `fix/loadsman-parse-defects`, 2026-09-24, from
`docs/audits/2026-09-24-duplicate-rows-and-percent-as-sd-cowork.md`** — a
finding delivered by a Cowork session running `author_batch.R` over 52
randomised trials supplied by John Loadsman (editor, *Anaesthesia and
Intensive Care*). One decision is held for Steve (below).

**First, what produced the finding.** The batch scripts run from
`C:/dev/Fujii Boldt Reuben`, outside the repository's renv, so
`library(IntegrityAnalysis)` resolves to the R user library — and the
copy installed there is **0.1.0, built 2026-08-21**. Every Loadsman
checkpoint, the Carlisle-168 workbook of 2026-09-24 and the figures in
the finding were produced by an engine that predates the value-signature
dedupe of the AI merge (2026-08-25), the repeated-measures reader
(issue 34) and every fix between. This is the fourth instance of the
stale-library trap in the memory file `snapshot-library-provenance`; the
standing remedy — reinstalling the user-library copy from the repository
— has been Steve's call since 2026-09-02 and still is. Both batch scripts
now print the library they load (path, version, build date, repository
HEAD), store it in every checkpoint as `provenanceLib`, and **stop** on a
copy older than 0.2.0. Their seeds were already set by the Cowork
session (re-seeded inside `score()`, so a resumed run matches an
uninterrupted one).

**The three defects, re-measured on current `main` (841648d) before
anything was changed:**

1. *The same variable twice, under a truncated and a full label* (Polat
   2015 DA, 18 papers). **Already fixed on `main`** by the 2026-08-25
   value-signature dedupe: the hybrid run of Polat on current code prints
   "Dropping 2 model variable(s) whose values duplicate deterministic rows
   under another name: Amount of intraoperative fluid, Infusion duration
   of study drug" and returns 15 rows — 9 continuous (3 variables × 3
   arms of 30), Gender, and the model's Septoplasty. What remained wrong
   was the *truncation*: "Amount of intraoperative" is the first line of
   a label whose second line, "fluid (ml)", carries no value and so was a
   label-kind line the row never saw. **Fixed**: a label-kind line right
   after a data row that begins with a lower-case letter or a bracketed
   unit is the row's continuation (journals capitalise a variable's first
   line), joined to the label and never a block header; the look-ahead
   runs past the block's last data row, where the last variable's
   continuation sits. Polat now reads "Amount of intraoperative fluid"
   and "Infusion duration of study drug".
2. *"n (%)" read as mean and SD* (Akkaya 2015 EJA: 31 of 48 rows with
   SD > MEAN; p = 0.0029). **Reproduced on `main`** — the page's only
   candidate is an outcome table of counts with no "%" printed anywhere,
   and "18 (90)" fell to the vocabulary rules' default, mean (SD).
   **Fixed** by evidence from the cells: when, in every arm that has a
   value, the bracketed number is the first as a percentage of the arm's
   N at the printed precision (first number a whole count within N; at
   least two arms; at least one nonzero), the row is "n (%)" — checked
   ahead of the vocabulary rules. Akkaya now returns 0 continuous count
   rows and 8 level columns; its VAS rows are medians. A table whose
   mean (SD) cells are *mostly* SD > MEAN (half or more, three or more
   cells) raises a review flag, which consults the AI under
   `ai = "fallback"`.
3. *"Downloaded Mild"* (same paper). **Reproduced on `main`.** The
   rotated-rail stripper (`.ppStripRotatedText`, 2026-08-22) measured a
   rail's span between its words' *tops*; a rotated word's text runs on
   for `height` points (the URL is 120 tall), so this five-word rail
   spanned 184 of 700 points by tops and was kept, and "Downloaded"
   (36 points tall, starting 4 above "Mild") joined the Mild line.
   **Fixed**: the span is top-of-first to bottom-of-last (340 here).

**Held for Steve — the per-row validator issue.** The finding asks that
"a scored continuous row with SD > MEAN raises an issue". Every issue
code the validator has (`missing`, `unreadable`, `incongruent`,
`too_large`, `too_much_compute`, `error`, `structural`) is a defect
that fails the table; a skewed variable — opioid consumption 3.2 ± 5.1,
previous operations 0.4 ± 0.8 — legitimately prints SD > MEAN and must
be analysed as it stands. A non-fatal advisory needs a **new issue
code** (say `suspect`, painted amber, never blocking), which is a change
to the API contract (docs/api-users-guide.md's table of seven codes) and
the grid legend. Until that decision, the invariant lives at the parse
(the table-level flag above) and in the corpus check.

**Tests (committed):** `tests/testthat/test-loadsman-layouts.R` — the
Akkaya rail geometry through the stripper; a wrapped label joined on a
middle row and on the last row, and a capitalised next line *not*
joined; "a (b)" cells that satisfy the identity read as counts while
"Age 40 (12)" beside them stays a mean; the same table with no arm N
falling to mean (SD) and raising the flag; and the hybrid merge with a
canned model reply (mocked `parseBaselineTableAI`) dropping the fuller-
label duplicate by value while keeping "ASA I" and "ASA II" as two
variables — the regression the finding warned a careless fix would
cause. `corpus/checkLoadsman.R` — the real articles, skips when absent:
Polat 9 continuous rows, N = 30, no repeated tuple, no truncated twin,
both wrapped labels whole; Akkaya no banner word, 0 continuous rows with
SD > MEAN, 8 level columns; the cumj paper keeps ASA I and ASA II; and
over the corpus (46 of 52 parse deterministically) every table with
SD > MEAN on half its mean (SD) cells carries the flag. All pass.

**Nothing else moves — measured.** `runMassTest.R`, 61 PDFs, each side
from its own installed snapshot under `Rscript --vanilla`: 60 parsed / 1
failed on both, the same file. 50 of 60 ROW vectors identical; the ten
that differ are all the wrapped-label rule reading a name whole
("Uterine incision–to–" → "Uterine incision–to– delivery time, s";
"Cervical" → "Cervical dilation, cm") plus one variable *gained*
(PMID_15915019: "Procedure during general anesthesia 38 (88) / 35
(83)", counts by the identity rule; trial p 0.095 → 0.12). One trial
crosses a threshold with an identical ROW vector — PMID_17197846,
0.05012 → 0.0467, every row p within 0.004 — which is the unseeded
Monte Carlo of the mass-test script, as issue 34 established. Suite:
125 files / 4,106 passed / 0 failed / 33 skipped on the branch, with one ERROR in test-vocacapsaicin-layout.R whose expectation named the truncated label "Nonsteroidal anti-inflammatory"; the label is now read whole ("... drugs"), the expectation updated, and the file re-run clean. The misparse measurement (`measureMisparse.R`) can
see the identity rule only as pairs *removed* — a count row that was a
mean/SD pair is one no longer — so a misfire on a genuine mean (SD) row
would show as a lost corroborated pair; a run on this branch's snapshot
was launched at PR time against the `e41609c` baseline (no parser change
between `e41609c` and `841648d`).

**The misparse measurement found two more defects before the merge
(2026-09-24, on the branch at `3cc107c`).** Against the `e41609c`
baseline: 426 of 938 files fully corroborated (45.4%, was 417 of 936),
5,018 uncorroborated pairs (was 5,510), 4,443 of Carlisle's pairs missed
(was 4,457), corroborated pairs unchanged at 7,285; 968 of 1,016 triples
identical, 16 files changed bucket, 13 of them for the better
(`PMID_16508400` 48 pairs with 39 uncorroborated → 8, all corroborated;
`PMID_15681945` 40 → 16, all corroborated). The three that went the
other way were each read on both snapshots:

- `PMID_16792606` (2 pairs, both lost): **the identity rule misfired.**
  "Age 43 (15)" in arms of 280 and 279 satisfies 100 × 43 / 280 = 15.4
  → "15" at integer precision, and the two arms print the same values,
  so they were one check counted twice. The rule now counts *distinct*
  (count, bracket, N) tuples and needs three of them at integer
  precision, two when the bracket carries a decimal (a tolerance ten
  times as sharp). Akkaya's twelve arms pass with room to spare; a
  two-arm integer table with no "%" is left to the vocabulary rules and
  the flag. The page is a committed test; the Age row is a mean again.
- `PMID_16738291` (8 corroborated → 6, plus 4 wrong): **a candidate
  switch.** The full-width candidate joins the two columns' captions —
  "TABLE I Baseline characteristics TABLE III Treatment outcomes" — and
  its block mixes the two tables; once the wrapped-label rule made one
  of its lines usable it outscored the single-column reading by three
  and filed Table III's outcome values under Age and Height. A caption
  naming two tables is two tables — *when the page also offers the
  halves.* A first version docked every two-anchor caption by 8 and the
  second misparse run showed both ways that is wrong: on `PMID_15681941`
  the page is one full-width layout with Table 1 beside Table 3 and no
  column split, so the straddle was the only reading holding Table 1
  and an outcome table won; on `PMID_12193491` the second anchor was
  prose that ran onto the caption line ("… (Table II)"). And a dock was
  not enough anyway: four phantom arms each with a printed N out-score
  two real ones by more than any caption bonus. Now
  `.ppSetAsideStraddles()` sets a two-anchor candidate aside
  (`capScore` −100: read only if nothing else on the page parses) only
  when a *twin* exists — a candidate on the same page whose caption
  begins with the same first table and names no other. Table I wins on
  16738291 and Table 1 on 16179044; 15681941 keeps its straddle; 12193491
  keeps TABLE I. The four pages are `corpus/checkCaptionStraddle.R`; the
  rule is unit-tested on hand-built candidate lists, and a synthetic
  side-by-side page that the column splitter does *not* split pins the
  rule's documented limit (no twin, straddle read).
  *Third misparse run (branch at `3c3f6d7`, after the merge):* 428 of
  937 fully corroborated (45.7%), 5,009 uncorroborated pairs, 4,449 of
  Carlisle's missed; 15681941 and 12193491 no longer move. One new
  mover, `PMID_20608923` (8 corroborated → 3 wrong): the "Table 1" twin
  exists on that page but parses to *nothing*, and the set-aside
  straddle — which held Height and Weight — lost by default to an
  outcome table. So the rule moved from caption time to selection time
  (`fix/straddle-selection`): the straddle is *marked*, parsed like any
  candidate, and deferred; it competes only if its twin produced no
  usable rows. 16738291 and 16179044 still take the twin; 15681941 and
  12193491 keep their readings; 20608923 reads Table 1. Five pages in
  `corpus/checkCaptionStraddle.R`. The remaining movers are the known
  noise (16311286, 16480346) and 16792606's genuine "Duration of
  anaesthesia" row that Carlisle did not enter.
  *Fourth misparse run (`fix/straddle-selection` at `42db921`, the tree
  #339 merged):* **429 of 937 fully corroborated (45.8%)**, 5,006
  uncorroborated pairs, 4,441 of Carlisle's missed — the best of the
  series (baseline `e41609c`: 417 / 5,510 / 4,457).
- `PMID_16311286` (3 → 0 corroborated): scorer noise on a broken page.
  Both readings — Table 1 as one arm with no N, ten "variables" mostly
  fragments, and Table 3, an outcome table — fail validation; the
  wrapped-label rule merged one fragment, Table 1 lost a point, and the
  tie that had favoured it broke the other way. Neither reading was ever
  analysable; the pairs it "lost" were mean (range) cells that happened
  to match. Left as it is.

One file stopped parsing (`PMID_12594136`): it had "parsed" one valueless
row from an outcome table; now no usable rows, which is the honest
result. A second misparse run on the corrected branch is recorded here
by follow-up.

**Mass test on the corrected branch (`206c5c6` snapshot vs `main`
841648d):** 60/61 parsed on both; 49 of 60 ROW vectors identical. The
eleven that differ: nine are labels read whole and the variable gained
by the identity rule (above); one is the two-anchor rule correcting a
straddle — on `main`, `PMID_16179044` was read from a full-width block
captioned "Table 1 Patient characteristics … Table 4 Induction time of
sedation, intra-operative propofol", four phantom arms, "Propofol target
concentration" and a nonsense "ASA grade 12 (12)" filed as baseline, trial
p 0.992; the branch reads the real Table 1 — Age, Weight, Height, two
arms of 55 with identical printed means — and p = 0.026 is the genuine
result on the genuine table; and one is the unseeded Monte Carlo wobble
across 0.05 with identical rows (`PMID_17197846`), as before. Suite on the
corrected branch: 125 files / 4,121 passed / 0 failed / 33 skipped.

**A regression the corpus session found on the pushed branch (its batch
1, 2026-09-25; the merge was stopped for it).** Peker 2020 IJMS validated
on `main` and failed on the branch: the wrapped label "Need for rescue
medication (number of patients)" — now read whole, correctly — named the
two parts of its "12/30" cells "… (number of patients) 1" and "… 2", and
`.iaNormalizeNames()` renames the *first* column containing NUMBER to
`N` unconditionally (as it does TRIAL, MEASURE and DECM: a hand-made
spreadsheet's header spellings, and the rule cannot know a column is a
category), so the table was refused structurally as two columns
normalising to `N`. On `main` the truncated label had no bracket and no
collision. **Fixed**: `.iaSafeColumnName()` respells those four words
(number → no., trial → trl, measure → meas., decm → dec.) in every
category column either engine names — the heuristics' three naming sites
and the AI route's `.iaLevelColumnName()` — so a level can never collapse
onto a reserved column; the conditional tokens (GROUP, ROW, MEAN, OBS)
resolve to the real base column, which the template carries leftmost,
and are left alone. Peker is asserted in `corpus/checkLoadsman.R` (label
read whole, no category column spells NUMBER, `validateData` accepts)
and on a synthetic page in the test file. The corpus session's other
findings of that batch (a cell set half a line above its row filed as
Unnamed; a median row pinned at its floor in every arm; MALE/FEMALE and
male/female both surviving the merge; a third header's N not read and
NA-N heuristic rows not deduped against the model's) are follow-up
issues, not this one.

---

## 34. The baseline block ran into the follow-up timepoints — and the page was the transpose of what the finding assumed

**Status: fixed on `fix/long-layout-issue-34`, 2026-09-24, from
`docs/audits/2026-09-24-repeated-measures-parse-finding-cowork.md`** — a
finding delivered by a Cowork session running IntegrityAnalysis over the
Fujii, Boldt and Reuben corpora. Of 168 Carlisle-2012 Fujii trials, 51
returned `parsed table failed validation`, **22 of 27 canine trials among
them** — the stratum Carlisle found most aberrant (21 of 24 inconsistent
with random sampling) and the stratum we were losing entirely.

### The diagnosis, and where it was backwards

The finding's test case is PMID 11375852 (Fujii et al., *Anesth Analg*
2001;92:1590–3, retracted), chosen because Table 1 of Carlisle, Dexter,
Pandit, Shafer & Yentis, *Anaesthesia* 2015;70:848–858 prints its complete
baseline table and the text gives the Monte Carlo result, p = 1.2 × 10⁻⁶.
The finding named three defects on it, in the right order of importance:
N absent (36 of 37 issues), arm detection collapsed to two unnamed arms,
and — the one that matters — the parse taking post-treatment values as
baseline data, so that supplying N alone would have turned a visible
failure into a confident p computed on rows that are not baseline
characteristics. All three were real.

**The finding's model of the page was the transpose of the truth.** It
assumed a wide table with follow-up columns appended and a 27-row target.
The page (`pdftools::pdf_data`, page 2) is a **long** table:

```
Variable     Group   Baseline    [after midazolam]
HR (bpm)       1     141 ± 15    142 ± 17
               2     143 ± 10    133 ± 10*†
               3     140 ± 12    123 ± 10*†‡
```

Arms are *rows* under a `Group` column; timepoints are *columns*. The
column engine took the two timepoint columns for two arms and each
variable's three group rows for three variables (`HR`, `Unnamed`,
`Unnamed 2`): 36 rows for 18 baseline values, every after-drug value
filed as baseline. That also explains Carlisle's ninth variable:
"RAP(2)" in the 2015 table is Table 1's *after-dose* RAP column, and the
two "Stimulation" rows are the baseline column of **Table 2** (Pdi),
a separate table beside it. So the correct single-table parse is
**6 variables × 3 arms = 18 rows**, not 27 — the 27 needs two tables and
one post-treatment row, and this engine reads one table (user guide,
*One table only*). The finding's "58 = 27 + 27 + noise" arithmetic was a
coincidence.

### What changed

- **`R/parseRepeatedMeasures.R`** — a repeated-measures reader that `.ppParseBlock()`
  tries first, after line classification and before column clustering.
  It fires only on an unambiguous layout (a header naming both `Group`
  and `Baseline`, group indices running 1..k beneath each variable, most
  of the block fitting) and returns `NULL` otherwise, so the column path
  is unchanged unless it fires. It reads the Baseline column **only**,
  one row per (variable, group), and names the arms from the stacked
  "(Group k)" legend.
- **`.ppGroupsOfN()` in `R/armNRecovery.R`** — "divided into three
  groups of eight each", the only way an animal study states its N.
  Neither existing text reader matched it ("n =", "randomised"). It
  returns the group *count* too, and the reader refuses the size when
  that count differs from the arms it read. It also handles the sentence
  cut at a line break with the other column's text interleaved between
  the halves — which is how poppler delivers this page: *"...into three
  groups of* stimulation did not change. Compared with Group 1, *eight
  each: ..."*. Exact at the line boundary, nothing looser.
  *On review (CodeRabbit, PR #330):* it returns **every** distinct such
  statement, not the first, and `.ppGroupNFor()` applies a size only
  when the statements for the table's arm count agree on one — a pilot
  of eight and a study of ten leave N missing rather than guessed.
- **Two more guards in the reader, on the same review.** A value is taken
  from the Baseline column only when `Baseline` is the *nearest* header
  centre to it, so a row whose Baseline cell is blank cannot take its
  after-drug value (50 pt to the right was inside the old tolerance).
  And a group row the reader cannot use — blank Baseline cell, a median
  row — is listed in `skipped` with the reason and the line's text
  (`reviewFlags()`: "table line(s) could not be used") instead of
  vanishing; it still counts as its group's row for the 1..k run check,
  because before that one blank cell broke the run and the whole table
  fell to the column engine, which filed the after-drug value as
  baseline. Documented in `docs/parsepdf-architecture.md` §05e.
- **`.ppParseScore()` no longer credits `Unnamed` rows as variables.**
  This is the change that let the fix win rather than merely exist. On
  this page the misread scored 24 (twelve `Unnamed` rows at +2 each, −1
  each in penalty) against 14 for a correct six-variable reading; Tables
  2 and 3 misread the same way scored 7 and 14. With the credit gone the
  corrected Table 1 reading (8 after its caption penalty) beats every
  other candidate. The penalty stays. A scorer change can move other
  files' candidate selection; it was measured, below.
  *Correction on review (CodeRabbit, PR #330):* the first version filtered
  the `Unnamed` rows out of the row set BEFORE counting the penalty, so
  the penalty was always zero — credit and penalty both gone. The penalty
  is now counted over the unfiltered row names, as intended. This was not
  visible on the motivating page (the misread loses either way) and is
  the reason the misparse measurement below was run twice.

Not changed, deliberately: `validateData` still requires N. The finding
was explicit that tolerating a missing N would clear 36 of 37 issues on
this paper and make the trial analysable on baseline and post-treatment
rows together, converting a visible failure into an invisible one.

### Results on the article (deterministic engine, `ai = "never"`)

| | before | after |
|---|---|---|
| rows | 36 | **18** |
| arms | `<NA>`, "No study drug" | **No study drug (Group 1); Sedative dose of midazolam (Group 2); Anesthetic dose of midazolam (Group 3)** |
| N | NA | **8, 8, 8** — flagged "recovered from the document text" |
| after-dose values in the output | 18 | **0** |
| `validateData` | FAIL (37 issues) | **passes** |
| trial p | — | **1.2 × 10⁻⁴** (six variables; Carlisle's 1.2 × 10⁻⁶ used nine) |

Hybrid (`ai = "fallback"`, which still consults the AI because a recovered
N is a flag): 24 rows — the 18 above plus Table 2's two *baseline*
Stimulation rows the AI found, **no after-dose value, every deterministic
row preserved**. Down from 58 contaminated rows.

### Tests committed (Steve's instruction: the fix must not regress)

1. `tests/testthat/test-fujii-11375852-engine.R` — Carlisle's 27 rows as
   printed against `P_Calc`: `<0.0001` at the 100,000-replicate ceiling
   on three seeds, and a perturbed copy that leaves the floor. Honest
   scope: the display floor is where 1.2 × 10⁻⁶ lives, so this is
   agreement at the app's resolution, not a reproduction of the value.
   Recorded in `docs/validation-ledger.md`.
2. `tests/testthat/test-repeated-measures-layout.R` — a synthetic repeated-measures page built with
   the `pdf()` device (the `test-real-layouts.R` convention), asserting
   each defect separately: the parse stops at the Baseline column (none of
   nine distinct after-dose pairs leaks), three arms named from the
   legend, N recovered from the Methods and refused when the stated group
   count disagrees, end-to-end validation, and — the guard — a wide table
   that merely says "Group" is left to the wide reader. Added on review:
   a page with one Baseline cell blank — its after-drug value (80 pt to
   the right) must not be read, the row must appear in `skipped` with
   the reason, the flag must say so, and the other eight rows must still
   be read (before the fix this page fell to the column engine: 17 rows,
   after-drug values included).
3. `tests/testthat/test-armn-recovery.R` — the sentence, the line-break
   split, and the sample-size sentence that must not match. Added on
   review: two statements for the same group count that disagree on the
   size (N refused), statements for a different group count (ignored),
   and the same sentence twice (one statement, not a disagreement).
4. `corpus/checkFujii11375852.R` — the real article, corpus tooling, skips
   when absent. Ten asserted checks on the deterministic result (all
   pass); the hybrid reported beside it, not asserted.

### Nothing else moves — measured, not assumed

- `testthat` suite, unmodified main@e16e185: 122 files, 3,989 passed,
  **1 failed**, 33 skipped. Modified tree: 124 files / 4,033 passed / **0 failed** / 33 skipped (two full runs, 4,008 and 4,033 passed, none failing). Unmodified `main` showed one failure that the silent reporter did not name; it did not reproduce on the branch across two runs, and I do not claim to have fixed it — it is a 1→0 change I cannot attribute.
- `corpus/runMassTest.R` over the 61 PDFs of `corpus/TEST`, main vs
  branch, each from its own installed snapshot library under
  `Rscript --vanilla`: **60 parsed / 1 failed on both**, the same file
  both times (`PMID_19104182.pdf`, "parsed table failed validation"),
  and **all 60 parsed files return byte-identical `ROW` vectors** —
  the parser's output on the test corpus did not change. Trial p differs
  in the third digit on 57 of 60 files (none crossing 0.01 or 0.05) and
  the per-row replicate count on 2 of 60: `runMassTest.R` seeds nothing,
  so that is the engine's unseeded Monte Carlo on identical input, not
  the parser. (A first pair of runs was discarded: `R_LIBS` had been
  silently overridden by renv's `.Rprofile`, and both had run against
  renv's installed copy — caught by printing `find.package()`.)
- `corpus/measureMisparse.R`, the finding's quantitative test of its own
  hypothesis (the "partial" bucket should shrink as tables shed their
  follow-up columns). Both sides re-established from snapshot libraries,
  because the output found on disk did not reproduce the 496/422/98 that
  issue 24 quotes (it recomputes to 380/387/221 over 988 files) and sat
  beside a folder named `contaminated`; it was set aside untouched.
  **BEFORE, main@e16e185** (`.NewCarlisle/misparse-before-e16e185/`):
  1,110 files scored, 1,017 parsed, 80 with no pairs; of the 937 with
  pairs, **416 fully corroborated (44.4%)**, 521 with ≥1 uncorroborated
  pair (55.6%); 12,923 pairs of ours, 7,269 corroborated (56.2%); 4,473
  of Carlisle's pairs missed (38.2%). **AFTER, this branch at `f0b1eca`**
  (`.NewCarlisle/misparse-after-issue34/`, same 1,110 files, same
  corpus, the branch's installed snapshot under `--vanilla`): 1,017
  parsed, 81 with no pairs; of the 936 with pairs, **417 fully
  corroborated (44.6%)**, 519 with ≥1 uncorroborated pair (55.4%); 12,820
  pairs of ours, 7,284 corroborated (56.8%); **4,458 of Carlisle's pairs
  missed (38.0%)**. `corpus/compareMisparse.R` (new) puts the two runs
  side by side: **1,013 of 1,017 files have an identical
  (ours, corroborated, uncorroborated) triple**, and the four that moved
  all moved the right way —
  `PMID_18292675` 56 pairs, none corroborated → 12 pairs, all
  corroborated, and all 12 of Carlisle's pairs now found (the
  repeated-measures layout, read as this fix intends);
  `PMID_16531446` 48 uncorroborated → 4 pairs, 2 corroborated;
  `PMID_15377579` 17 uncorroborated → no pairs at all (the misread no
  longer wins; nothing replaces it, which is the honest result);
  `PMID_21564041` 2 → 4 pairs, 1 → 2 corroborated. No file lost a
  corroborated pair. The finding's prediction — the partial bucket
  shrinks and the fully-corroborated bucket grows — holds, by one file
  each: this layout is rare in the Carlisle-2017 corpus, which is human
  RCTs, not the animal stratum where it failed.
  **AFTER, with the review fixes, `e41609c`**
  (`.NewCarlisle/misparse-after-issue34-e41609c/`; scorer penalty
  restored, Baseline column bounded by the next header, unmatched lines
  reported — each of which can move candidate selection; run from that
  commit's own installed snapshot after the merge, recorded here by
  this follow-up): 1,017 parsed, 81 with no pairs; of the 936 with
  pairs, **417 fully corroborated (44.6%)**, 519 with ≥1 uncorroborated
  pair; 12,795 pairs of ours, 7,285 corroborated (56.9%); **4,457 of
  Carlisle's pairs missed (38.0%)**. Against BEFORE: the same two files
  change bucket (`PMID_18292675` zero → full, `PMID_16531446` zero →
  partial), no regressions, 1,010 of 1,017 triples identical. Against
  the first AFTER run: **no file changes bucket**; 1,014 of 1,017
  triples identical, and the three that moved are the restored penalty
  doing its work — `PMID_15087630` 14 uncorroborated pairs → 2;
  `PMID_16189334` 24 pairs (17 uncorroborated) → 9 (2 uncorroborated),
  the 7 corroborated pairs kept; `PMID_16670112` 15 → 17 pairs, 2 → 3
  corroborated, one more of Carlisle's pairs found. The penalty's return
  removed 27 uncorroborated pairs and added one (net 26: 5,536 → 5,510)
  at the cost of no corroborated pair. So the scorer change
  as merged is: no credit for `Unnamed` rows, penalty as before — and
  measured on the corpus it moves three files of 1,017, all toward
  Carlisle's values.
- `corpus/validateCarlisle2017.R` cannot move: it reads Carlisle's
  hand-entered spreadsheet straight into `validateData` → `P_Calc` and
  contains no call to any parser (`grep -c "parseBaseline|ppParse"` = 0).
  The citable ledger row stands.

**Still open.** The 26 human Fujii failures were never captured (the batch
discarded failed parses at the time) and should be re-run; Boldt's 175
cardiac-surgery trials, many repeated-measures with this table shape and
no published ground truth, were held pending this and can now proceed —
with `checkFujii11375852.R`'s two-result discipline applied to the hybrid
route, since the AI merge adds rows by label and the deterministic engine
is the only part of the pipeline that cannot introduce a post-treatment
value.

---

## 32. A memory ceiling for the parse child (the render cap for scanned pages is closed)

**Status: open, filed 2026-09-02** from the security screen of the image
upload feature (`docs/security-screens/log.md`, F1 and its note); the
render-cap half closed 2026-09-06 (#194).

Every hostile document is decoded in a child process under a wall-clock
timeout (`parseBaselineTableFiles()`), and the image route now refuses
oversized headers before any decoder runs. What the child does NOT have
is a memory ceiling: a decoder that allocates faster than the timeout
fires is the container's out-of-memory, and on a single-threaded host
that is the worker. The image preflight narrows the window (20 MP cap,
10 TIFF pages, no GIF); it does not close it, and it does nothing for the
older routes.

**Fresh evidence, 2026-09-09.** Two HIGH findings in a single screen were
both allocation, not CPU: `.ppArmVectorCount()` reserved coefficients in
proportion to an arm N read off the page (1,074 MB for a header reading
`(n = 2000000000)`), and the candidate grid was `prod(width) x levels`
with only the product capped (840 MB at 300 levels). Both are fixed in
the R code — the counting is closed-form for two levels and bounded past
them, the grid is charged against a cell budget, and an arm above
`.iaMaxArmN` is refused before any of it — but both were found by a
reader rather than stopped by a limit, and the next one of this shape
will be too until the child has a ceiling. See the 2026-09-09-1532 rows
in `docs/security-screens/log.md`.

Two things, both belonging to the container rather than to R code, and
neither verifiable from the Windows development machine:

- **A memory limit on the parse child.** On Linux, `ulimit -v` around the
  `Rscript --vanilla` launch in `parseBaselineTableFiles()`, or a
  container-level limit in the App Runner service and the Docker image.
  Whichever is chosen, verify on a Linux node that a deliberately huge
  allocation in the child is killed and reported as a failed parse, not
  as a dead worker.
- ~~**A page-size cap on the scanned-PDF OCR render.**~~ **CLOSED
  2026-09-06** (#194, repeat screen F3): one gate, `.ppRenderablePages()`
  in `R/utils.R`, reads `pdftools::pdf_pagesize()` first and drops any
  page over 30 inches on a side or over 20 MP at the requested dpi; it
  fails closed (a document whose page sizes cannot be read renders
  nothing) and both rasterisers — the OCR rescue and the AI route's page
  renderer — go through it. `tools/securityCheck.R` pins that they do,
  and the deliberate-break test uses a 200 x 200 inch page.

Done looks like: the memory limit in place with the deliberate-break
test that shows it working, and the screen's F1 note closed. The repeat
screen's F4 (no total work budget for the public app — 100 median rows at
5,000 per arm pass validation) is recorded against this issue too:
accepted for now under Steve's standing decision not to reduce Monte
Carlo precision silently; a queue with cancellation or a preflight
refusal is the remedy when a shared-worker incident makes it worth its
cost.

---

## 33. The Table Transformer + tesseract seam: built; where it runs is the open question

**Status: built 2026-09-02 (PR #147, `R/parseTatr.R`)** at Steve's
direction, "Add tatr-tesseract to pdf parser workflow", after the
run-along (issue 20's neighbour, PR #137) showed the model locating a
griddable table in 84% of the text-layer articles the engine cannot grid
and on 97% of scanned pages with no text layer at all.

What is built: the model's XML (with `--write-empty`, so a scanned page
keeps its geometry) goes through the Word path's adapter into the same
block parser; on a page with no text layer, tesseract supplies the
characters and each word is assigned to the cell holding at least half
of its box. A rescue tier behind the text engine, ahead of the AI route
and of plain OCR; the model never chooses the table.

**Measured 2026-09-02** on an installed snapshot, through the subprocess
batcher. Run B (574 Carlisle articles with model geometry, text layer):
the engine alone parses 523; of the **51 it cannot, the seam recovers
25** (49%) - 8 of them with an N on every arm, 17 with continuous rows,
and a tail of thin one-to-two-variable readings that the value scoring
below would sort. The 26 still failing split between poppler timeouts
(the same files time out with or without the seam) and tables the model
found but the engine could not read as baseline data. Run C (the 300
accessions of the scanned-set run, 192 with model geometry, 84 of them
text-less tables kept by `--write-empty`): the engine alone parses
106; of the 86 it cannot, the seam recovers **19 through the text
layer** - the same mechanism as run B - but the **OCR pairing on real
scans yielded only fragments**: 18 results, none with an N on two arms,
one with a continuous row, mostly a single variable, and no better than
plain OCR on the five files both read. The seam now gates a pairing
result on arm identity exactly as the OCR rescue does, so those
fragments do not surface. **Standing conclusion, unchanged from issue
22: on a real scan the AI image route is the quality path; geometry
from the model helps the text-layer failures, not (yet) the scans.**

What is NOT decided, and is Steve's call:

- **Where the model runs in deployment.** It needs the pegged Python
  (`tools/tatrProvision.sh`), ~17 s per article on CPU, ~1 GB resident,
  and ~500 MB of weights on disk. Two hosts could carry it. The API's
  Docker image is the simpler one: we build it, so the Python, the
  weights and `INTEGRITY_TATR_PYTHON` go in directly. The shinyapps.io
  app (Steve's Professional plan, instances up to 8 GB) is the second:
  it runs Python through `reticulate` from a shipped `requirements.txt`,
  but the torch wheels and the pegged weights would have to travel in
  the app bundle or be fetched at every instance start, and each cold
  start would pay the model load. A third route joins the two (Steve,
  2026-09-02): the shinyapps.io app could call OUR OWN API for the
  geometry - a `POST /v1/geometry` endpoint on the Docker image, invoked
  only when the app's text engine fails, returning the model's XML for
  the app's own `parseBaselineTableTatr()`. One place runs the model,
  the app stays R-only; it costs a service token held as a shinyapps
  secret and one round trip per failure, and it changes the guide's
  "nothing leaves this server" sentence, which would then read "to a
  container we run, with the API's zero-retention guarantee". Neither
  deployment is a code change; the endpoint is a small one. All Steve's
  call, weighed against the memory ceiling of issue 32 and the measured
  payoff (text-layer failures, not scans).
- **Per-cell OCR, and a higher render for scans.** The pairing OCRs the
  whole page at 300 dpi and assigns words; on real scans that produced
  fragments (above). OCRing each cell's crop separately, with a
  digits-friendly configuration, and rendering scanned pages for the
  model at more than 150 dpi are the next steps - and need an image
  cropper that is not ImageMagick (screen F1, 2026-09-02; tesseract's own
  reader can take a rectangle, which is the route to try). Arm 2's 99
  real scans are the test set.
- **Value scoring - now run on the 25** (2026-09-02, late). Eleven of
  the 25 recovered articles map to a Carlisle trial with hand-entered
  values. Of the seam's 185 (mean, SD) pairs, **105 corroborate his
  (57%)** by the corroboration script's own rounding rule, and **91% of
  his pairs are recovered** (10 of 113 missed). Six articles are fully
  corroborated; five carry uncorroborated pairs, two of them badly
  (IA012208: 44 of 54; IA013851: 22 of 32 - extra rows he did not
  record, or a table read wrong). That is the same order as the engine's
  corpus-wide 44.8% fully-corroborated figure, so the recovered readings
  are ordinary parser output, not a new class of error - and the two bad
  ones are what the grid's flags exist for. The remaining 14 have no
  Carlisle mapping; the 147-article scoring on the node queue is the
  fuller answer.

**Measured 2026-09-03 on the WHOLE Carlisle corpus** (1,865 articles;
the model's geometry for all of them from a 3.7 h run on `i5`, the
comparison on `oldryzen` from the installed branch snapshot through the
batcher: `tatr = "never"` against `tatr = "always"`; files under
`C:/dev/Corpus/tatr/xml/runFull/always/`, scripts
`C:/dev/Corpus/tools/tatrAlwaysReport.R` and `valueCheckAlways.R`):

- The text engine parses 1,654 (88.7%); with the seam 1,768 (94.8%):
  **114 recovered, none lost** (78 through the text layer, 36 by the
  OCR pairing). The 51 articles the model found no table in parse the
  same either way.
- When both succeed (1,654), the model's reading wins by parse score in
  441 (26.7%): 63 with identical numbers, 378 with different ones - the
  model reads more (median 28 values against 19).
- **Judged by Carlisle's hand-entered numbers** (1,485 of the 1,865
  join to his One Sheet by PMID; each reading's values scored for
  recall of his numbers and precision against them): on the 321 joined
  articles where the model won with different numbers, recall rises
  from 0.41 to 0.59 and precision from 0.38 to 0.44; paired, the model
  reads more of his numbers in 150 articles and fewer in 59. Of the
  1,905 values the model added net, 58% are his - a better hit rate than
  the text engine's own 38% on those articles, so the additions are
  content, not noise, on balance. The 84 recovered articles with a
  Carlisle trial score recall 0.51 / precision 0.46, the same order as
  the text engine's 0.61 / 0.48 on articles it parses: ordinary parser
  output. Corpus-wide, recall 0.61 -> 0.65 and precision 0.48 -> 0.50.
  So `tatr = "always"` is a net gain by his numbers, not just by score.
- **The failure the score cannot see, 38 articles**: the model's reading
  won by parse score while its precision against Carlisle fell by more
  than 0.2 - in the worst (PMID 14725516) the text engine's 16 values
  were all his and the model's 16 were a different table with one.
  Parse score rewards content; it does not know which table is the
  baseline table, and a larger non-baseline table can outscore a
  correct smaller one. This does not touch the default `tatr = "auto"`
  (the seam runs only when the text engine fails: 114 recovered, none
  lost); it is a rule to add before `"always"` is used in earnest - the
  model's candidate should have to match the text engine's caption, or
  the caption score should weigh in the comparison. Listed in
  `always_valuecheck.csv`.

Done looks like: a deployment decision recorded here, and the "always"
comparison given a caption rule so the 38 cannot happen.

---

## 31. One corpus library, with an index that decides what may be shared

**Status: built 2026-08-31** (`corpus/buildCorpusLibrary.R`,
`corpus/fetchCorpusIdentity.R`, `corpus/extractShareable.R`,
`tools/ingestNodes.ps1`, `tools/backupCorpusZip.ps1`; the library itself
is `C:/dev/Corpus`, outside the repository). Recorded here because the
*rules* are the deliverable, and because issue 30 depends on it.

Steve, prompted by the prospect of collaborating with Adrian Barnett:
"The test and development corpora are currently scattered all over this
computer... we can't have this scattered set of files. Please coalesce
into a single corpora with a master index and a logical tree. Papers
should be assigned our own access numbers to preserve confidentiality."

**What was scattered.** Eleven collections across `C:/temp`, the repo's
hidden `.NewCarlisle`/`.Boldt`/`.Fujii`, and two Linux nodes — 36,842
files, 24.2 GB, in four incompatible naming schemes. The same paper
could be `Journals/Anaesthesia/2003/1.2.pdf`, `Journals/PMID_12492668.pdf`
and a PMC XML named by PMCID, with nothing linking them. **17,032 works**
after dedup on PMID > PMCID > DOI > SHA-256; **6,565 hold both a PDF and
an XML**, which is the set that makes XML usable as parser ground truth.

**The architecture is one sentence of Steve's**, given after the A&A
peer-review holdings were flagged: *"Put them in the master index, but
marked 'not sharable.' The master corpus itself is never shared. We
extract and share only what the master index permits."* So the library is
not a shareable artefact with sensitive parts carved out — it is a
complete private archive plus an index that **decides**. A file is
extracted if and only if `master.csv` says `FILE_SHAREABLE`. If a licence
is wrong, fix the index; never special-case the extraction, because the
index is what can be audited afterwards.

**Two booleans, because two different questions get asked.**
`FILE_SHAREABLE` (may the article go?) is true for 20,049 of 36,842
files. `DERIVED_SHAREABLE` (may a parsed table go?) is true for 30,514.
The gap is the point: a subscription PDF cannot be redistributed, but the
mean and SD printed in its Table 1 are *facts*, and facts are not
copyrightable — so restricted material can still carry a published
analysis. Confidential peer review is the one class where both are false,
because there the content *is* the confidence.

**The confidential tier.** `C:/temp/AA` held 6,328 PDFs of Anesthesia &
Analgesia submissions from Steve's editorship. Pseudonymising the index
does not make them shareable — the accession hides identity in a *table*
and does nothing about the authors and title printed inside the PDF. They
are in the archive (they are the only corpus showing what actually
arrives at a journal) and marked `confidential`: 6,328 files collapsing
to 3,149 works, since the same manuscript was held in several folders.

**Accessions are randomised, not sequential-by-scan.** `IA######`
assigned in shuffled order under a recorded seed. Scan order would leak
exactly what the pseudonym hides — `IA000001`–`IA001865` would obviously
be the Carlisle set. Same reasoning as `corpus/pseudonymize.R`.
`identity.csv` (accession → PMID, journal, volume, issue, pages, title,
authors) is excluded from every extraction tier unconditionally, with no
flag to override: turning an accession back into a named paper is a
decision Steve makes one paper at a time, so the author can be heard
first.

**`FIRST_SEEN` enables a temporal holdout.** Train on
`FIRST_SEEN <= X`, evaluate on what arrived after. That is clean in a way
`corpus/Holdout.csv` cannot claim — those articles had already been read
and their failures studied when it was drawn. Deliberately *not* inferred
from file mtimes: a 2025 download copied in 2026 has a timestamp that
says nothing about when the corpus gained it.

**Watch for**

- **`match()` on a missing key is a silent identity swap, and a positive
  control will not catch it.** `pmidToPmcid.csv` holds 11,428 rows with an
  empty PMCID; `match(NA, table)` in R returns the position of the first
  `NA` rather than missing, so on the first run *every* work without a
  PMCID — all 3,149 confidential A&A manuscripts among them — inherited
  one unrelated paper's PMID, and then that paper's title and authors.
  Coverage read `17,035 / 17,035`. The script already had positive
  controls on both NCBI endpoints and **they passed**: a healthy API
  answers a wrong question as cheerfully as a right one, so they proved
  the service worked and could not prove the keys were right. Fixed with
  `safeMatch()` (both scripts, ten joins) plus a **negative control that
  aborts before writing** — a work with no identifier at build time may
  not acquire one. Treat a coverage figure that jumps to 100% as a
  defect report, not a result.

  **Audited 2026-09-01: every join in `corpus/`** — 39 raw `match()`
  call sites (37 lookups plus the two hand-copied definitions of
  `safeMatch()` itself), the 12 joins already converted on 2026-08-31,
  and the 13 `merge()` calls, which have the same defect and were not
  covered by the original fix. Nothing
  was corrupt: every right-hand table in use today happens to be free of
  blank keys, so the seven unguarded joins found were latent, not live
  (checked, not assumed — `.NewCarlisle/manifest.csv`,
  `unpaywall.csv`, `licensed_manifest.csv` and `corpus/pmid_map.csv`
  all hold zero blank PMIDs, and the 20,025 accessions hold no
  degenerate work key). The audit's three findings worth keeping:
  **(1)** the failure needs a blank on the LEFT *and* a blank in the
  table, which is why filename- and literal-keyed joins are fine and
  did not need touching — 26 of the 37 lookups were cleared unchanged
  on that ground, and only 7 were genuinely exposed; **(2)** the worst
  site was
  `corpus/buildFraudDownloadList.R`, which *deliberately* stores an
  unresolved citation as `PMID = NA` and then joins on it, so a
  stranger's DOI, licence and download URL could have entered Steve's
  hand-worked queue; and **(3)** a second bug of the same family that
  `safeMatch()` does not address — the work key was built with
  `!is.na()`, so an empty-string identifier would have produced the
  key `"pmid:"` and an unhashable file the key `"sha:NA"`, collapsing
  every affected file into ONE work with ONE accession. That is the
  mirror image of the collision check already in the builder (one
  accession, two works) and invisible to it; both are now refused
  before anything is written. `safeMatch()` itself moved to
  `corpus/safeMatch.R` — one definition, sourced by seven scripts,
  because a third hand-transcription would have been the next defect.
  Pinned by `tests/testthat/test-safe-match.R`, which SKIPS under
  `R CMD check` (`corpus/` is `.Rbuildignore`d) and therefore runs
  only in a development tree.
- **The NCBI ID converter moved again.** `www.ncbi.nlm.nih.gov/pmc/utils/
  idconv/v1.0/` now 301s to `pmc.ncbi.nlm.nih.gov/tools/idconv/api/v1/
  articles/`, and `jsonlite::fromJSON` does not follow redirects — it
  parses the redirect HTML, finds no records, and reports success having
  resolved nothing. That is the **third** silent NCBI zero in this project
  (retired `oa.fcgi`, an unfollowed 301, a `pmcid:` prefix left in parsed
  values). Both fetchers now run a **positive control before the run** and
  `stop()` on failure. Add one to any new NCBI caller.
- Hard links, not copies: `master/` costs no extra disk, but robocopy and
  zip both expand them, so never back up `master/` *and* the source trees.
- The originals under `C:/temp` still exist and older `corpus/*.R` scripts
  still read them. They are hard links to the same bytes, so this is not
  duplication — but the paths must be repointed before anything is deleted.

---

## 30. A frozen regression corpus, and multi-source disagreement as a signal

Two requirements from Steve, 2026-08-30, which belong together because
the first produces the material the second freezes.

### 30a. More than one source per table is information, not a scorecard

"We are trying to learn how to parse input files to generate baseline
tables. When we have > 1 source, then that provides information from
which we can further refine input table parsing, regardless of the
source."

Today's PMC pass gives, for the same trial, up to three independent
renderings of one baseline table:

| source | reachable | what it is |
|---|---|---|
| PDF | ~7,000 | the typeset article |
| JATS XML | ~10,200 | the publisher's own table markup |
| the registry | 47,813 trials | values the sponsor typed into ClinicalTrials.gov |

(XML availability was measured, not assumed: 39 of 40 sampled OA
articles and 39 of 40 sampled author manuscripts carry an `xml_url`,
against 35 and 3 respectively for `pdf_url`. XML is not a fallback for
the awkward cases - it is the format that is actually there.)

**5,672 trials have all three.** A further 2,322 author manuscripts have
XML and the registry but no PDF.

The comparison isolates cleanly because BOTH input paths funnel into the
SAME `.ppParseBlock()`. The PDF path reconstructs a table from
coordinates; the XML path hands over real cells; after that the
interpretation code is byte-identical. So a PDF-vs-XML disagreement is
attributable to EXTRACTION alone, with interpretation held constant by
construction. That is a far sharper instrument than issue 24's
measurement, which could say "9.6% agree with the ground truth not at
all" but never why.

Three sources also break ties: a 2-versus-1 split usually names the odd
one out. And the PDF-and-XML-agree-but-registry-differs case is not a
parser finding at all - it is baseline reporting inconsistency between a
published paper and its registry entry, which is publishable on its own.

**The point is the feedback loop, not the score.** Each disagreement
localises a defect (a lost column, a misread decimal, the wrong table
chosen), that defect gets fixed, and the corpus re-run. What must NOT
happen is the loop of AGENTS.md's optimisation pass - fix against the
same files, re-measure on the same files - which is why 30b exists and
why `corpus/freezeHoldout.R` already splits development from holdout.

**Caveat to state before quoting any number**: XML is ground truth for
what the TABLE CONTAINS, not for what the PDF says. PMC XML is sometimes
re-keyed or converted from the publisher's deposit, and author-manuscript
XML is generated from the submitted Word file, so the two can legitimately
differ. A disagreement is a flag, not a verdict; the honest design
measures the rate and adjudicates a sample by eye.

### 30b. A frozen, multi-format regression corpus

"We should set aside a corpus of 'successfully parsed and validated'
files of all types (pdf, xlsx, docx, XML, etc) that we can use in the
future to be certain that new parsing programs don't significantly
degrade the parser."

**The gap this closes.** Every fixture in the suite today is
SYNTHESISED at test time - `helper-syntheticPdf.R`,
`helper-syntheticDocx.R`, `helper-syntheticJats.R` - and the only
committed real files are `Example.xlsx` and `Template.xlsx`. That was
forced: the Carlisle and A&A corpora are copyrighted PDFs, gitignored,
local-only. So the suite catches logic regressions but CANNOT catch a
regression on real-world layout variety, which is exactly where the
parser fails.

**What makes this newly possible.** Of the registry-linked PMC articles
measured 2026-08-30: 3,673 are CC BY and 47 are CC0. Those are
redistributable with attribution, so a `<table-wrap>` fragment plus its
expected output can be COMMITTED and run in GitHub Actions on every PR.
CC BY-NC (1,625) and CC BY-NC-ND (1,567) are usable locally but awkward
to redistribute in a repository others may use commercially; TDM (3,087)
permits mining, not redistribution. **Only CC BY and CC0 go in the
repo**, and each case records its licence and citation.

**Two tiers, mirroring the existing local/public split:**

- **Tier 1, committed, runs in the automated checks.** CC BY / CC0 JATS table fragments,
  plus the synthesised PDF/.docx/.xlsx fixtures already in use. Public,
  legally clean, fast.
- **Tier 2, local only.** Real PDFs from the Carlisle, A&A and medRxiv
  corpora. Run on the compute nodes, never committed.

**What "successfully parsed and validated" must mean**, or the corpus
freezes our mistakes: the file parses, `validateData()` passes, AND the
values were checked against a second source (XML, the registry, or by
hand) rather than merely looking plausible. A case admitted on "it
parsed without error" would pin whatever the parser did that day,
including a wrong-table selection - the precise failure of issue 24.

**Done looks like:** a `corpus/regression/` manifest of cases (input,
expected validated frame, source, licence, citation, how it was
verified); a test that parses every tier-1 case and diffs against the
frozen frame; a corpus script that runs tier 2 locally and reports
drift; and a documented rule that a case is added only WITH its
verification evidence.

**Deliberately not automated:** admitting a case requires a human
judgement that the values are right. The manifest records who verified
it and how.

---

## 24. Silent misparse: the parser sometimes returns the WRONG TABLE

**The measurement Steve asked for** (2026-08-26, from the "unknown
unknowns" review): we measure the parse RATE, and the Monte Carlo is
validated - but nobody had measured how often a parse SUCCEEDS WITH
WRONG VALUES. A failed parse is safe: the editor sees red cells. A
plausible misparse is the dangerous case, because an editor acts on it.

`corpus/measureMisparse.R` scores every corpus PDF that maps to one of
Carlisle's hand-entered trials. Each (MEAN, SD) pair we extract either
matches one of his pairs for that trial within printed rounding
("corroborated") or does not. Values, not labels: his row naming is his
own, and a label join would manufacture disagreement.

**RESULT - full run, 1,110 files mapped, 1,016 parsed (2026-08-26):**

| | files | share |
|---|---|---|
| fully corroborated (every pair matches) | 496 | 48.8% |
| partial (some match, some not) | 422 | 41.5% |
| **ZERO corroboration** | **98** | **9.6%** |

Also: 47.1% of parsed files have >= 80% of their pairs corroborated;
67.8% have >= 50%; the median file has 75% of its pairs corroborated;
and on the 767 files with >= 3 matches we recover 75.0% of Carlisle's
pairs.

**DO NOT quote the raw 43.7% uncorroborated as a misparse rate.**
Carlisle recorded only the variables he chose to analyze; the parser
extracts everything it finds, so most uncorroborated pairs are simply
variables he never entered. The honest headline is the two ends:
**about half of parsed files agree with the ground truth completely,
and about one in ten agrees with it not at all.**

**What the zero bucket actually is - the finding that matters.**
Inspected by hand, those files are not misread digits. **The parser
selected the wrong table.** Examples:

- `PMID_11927472.pdf`: rows labelled "Staph epidermidis",
  "Spore-bearing bacilli" - a microbiology RESULTS table. Carlisle's
  baseline values (633.3 +/- 25.8, ...) appear nowhere in our output.
- `PMID_11823394.pdf`: every row labelled "Group C", values 0/15/9/25 -
  an adverse-event or outcomes table, not baseline characteristics.

A wrong-table parse yields a confident p-value computed on data that
are not baseline characteristics, with nothing flagged. That is
precisely the failure this measurement existed to find.

**Why it is tractable**: this is a SELECTION failure, not a reading
failure, and selection can be gated on evidence. In order of expected
value:

1. **Refuse a winning candidate whose ROW LABELS do not look like
   baseline characteristics.** A demographic table says age / sex /
   weight / height / ASA / BMI; a microbiology table says Staph
   epidermidis. A vocabulary test over the winner's row labels - not
   the caption, which these files often lack - would refuse both
   examples above.
2. **Require positive baseline evidence to return anything at all.**
   Today an unlabelled table can win on parse score alone. Returning
   NOTHING is strictly better than returning the wrong table: the app
   handles "no table found" gracefully, and the API's round-trip
   payload covers it.
3. **Flag low-confidence selections** (no caption, no baseline
   vocabulary) so a human sees a warning rather than a silent verdict.
   Cheap, and useful even after 1 and 2.

**REMAINING**: classify the 98 zero-corroboration files properly
(wrong table vs. trial-mapping error vs. genuine digit misreads - the
three inspected were all wrong-table, but three is not a sample), then
implement the gate. Data: `.NewCarlisle/misparse/` (misparse_rows.csv,
misparse_files.csv sorted worst-first, run.log).

**Expect the headline parse rate to FALL when this is fixed** - from
84.9% toward something lower and truer, because some of today's
"successes" are wrong-table parses. For a fraud screen that is the
right trade, and it should be stated plainly when the number moves.

## 23. Layout repairs from the wild: statistic columns and superscript orphans

10.1101/19007542 (medRxiv, first harvest night): the deterministic
engine finds the right page and the right caption - "Table 1. Sample
characteristics.", sitting BELOW the table - then rejects every row
("no usable rows"). Four stacked hostilities, two of them worth
engine work because they are common in real journals:

- **Trailing test-statistic columns** (here t and p; elsewhere chi2,
  F). The arm columns carry "(N = 22)" headers; the statistic columns
  carry none. Detectable and droppable: a rightmost column block whose
  header matches `(?i)^(t|z|F|p|chi.?2?|x2)$` (or is empty) and whose
  cells are bare decimals with no N anywhere. The AI schema already
  excludes these by instruction; the deterministic engine should too.
- **Superscript orphans.** Footnote markers set as separate words ("A",
  "B", "&") land between cells and split them across visual lines
  ("0.02 &" on one line, its neighbor "0.89" alone on the next). Kin
  to the rotated-rail filter (.ppStripRotatedText): single-glyph words
  vertically offset from their line's baseline can be dropped before
  clustering.

The other two hostilities - row labels wrapped across lines with huge
vertical whitespace, and the stat tag buried mid-label ("Age (s.d.) in
years") - are the hard general case; diminishing returns, and exactly
what the AI assist is for (the model reads this page trivially).

---

## 22. Scanned tables (both tiers IMPLEMENTED 2026-08-26; one pin open)

Born from the medRxiv harvest's first night: 10.1101/19007195 is a
text manuscript whose Table 1 page alone is a scanned picture — the
kind of document curated submission corpora can never surface (A&A's
submission rules precluded scanned tables; a curated corpus measures
the gate, not the wild).

As shipped (PRs #73, #75; design details in git history and the PR
bodies): **tier 1** — pages with no text layer travel to the AI assist
as rendered 150-dpi page images (the only route that can reach a
scanned table; consent language covers content, text or image).
**tier 2** — with no key, the deterministic engine retries image-only
pages on tesseract word boxes; an OCR-read table shades whole-table
pale cyan with a verify-every-cell warning, and a quality gate rejects
arm-less OCR noise. Validation verdict (the AI validating tesseract,
Steve's design): on a clean render OCR reproduces the text-layer parse
EXACTLY; on the real degraded scan the AI read correctly and OCR was
rightly gated. Standing conclusion: OCR is the no-key fallback for
clean scans; the AI image route is the quality path for real ones.

**REMAINING**: a harvested scan clean enough for OCR, to pin the
end-to-end cyan path in the app against a real file (the registry and
renderer logic are unit-pinned; the full-pipeline assertion awaits a
usable specimen from the nightly harvest).

---

## 29. JATS/XML input — the format publishers already have

Accept JATS XML as a fourth input type, alongside PDF, .docx and the
spreadsheet formats.

**Why, and the first reason is a measurement rather than an argument.**
Of the 13,113 registry-linked papers that exist in PubMed Central
(measured 2026-08-30 against the PMC Cloud Service metadata objects):

| | n | with a PDF |
|---|---|---|
| Open Access subset | 7,277 | 6,863 (94%) |
| **author manuscripts** | **3,208** | **160 (5%)** |
| absent from the bucket | 2,788 | — |

**Author manuscripts are XML-only.** Without XML support those 3,208
papers are unreachable, and they are the ones worth reaching: an author
manuscript carries the baseline table as submitted, and the registry
holds the sponsor's own structured values for the same trial. That is
ground truth by construction for the parser itself — parse the table,
compare against what was typed into ClinicalTrials.gov. The protocol
PDFs measured in the false-positive work had no ground truth at all.

**Second, the API.** Steve's point, 2026-08-30: a publisher integrating
with the API already has JATS, because that is what their production
system emits. Asking them to render a PDF so that we can reconstruct
the table geometry we just destroyed is backwards. Manuscript systems
hold structured text; the API should accept it.

**Third, XML is simply better input.** No column clustering, no caption
scoring, no OCR, no decimal recovered from a glyph. The entire class of
defect that issues 24, 23 and 22 exist to chase does not arise: a JATS
table is real `<tr>`/`<td>`, and the only interpretation left is the one
we actually want to test — what the numbers mean.

### What it costs, which is less than it looks

The .docx work already built the seam. `R/parseDocx.R` has

```r
.ppDocxLines(mat, caption = NULL, footnotes = character(0))
```

which turns a cell matrix into the synthetic coordinates `.ppParseBlock()`
expects, so every existing behaviour — mean±SD, n (%), footnote-driven
SD-vs-SE disambiguation, arm-N recovery, skip reasons — works unchanged.
A JATS `<table-wrap>` is the same shape. `xml2` is already in
`DESCRIPTION`. The work is extraction and plumbing, not a new engine.

### Scope

- `R/parseJats.R`: `.ppJatsData()` (locate `<table-wrap>`, read with SAFE
  parser options), a cell matrix builder that expands `colspan`/`rowspan`,
  caption from `<label>`/`<caption>`, footnotes from `<table-wrap-foot>`;
  then hand all of it to `.ppDocxLines()`.
- Candidate loop over every table in the document, scored by
  `.ppParseScore()` + caption score, exactly as the .docx path does.
- Dispatch on `[.]xml$` inside `parseBaselineTableHeuristics()`; keep the
  `pdfFile` parameter name for API stability.
- **Route through `parseBaselineTableFiles()`** — the per-file subprocess
  with an OS timeout. This matters more for XML than it did for .docx;
  see security below.
- Extension plumbing: `app_server.R` allowlist and the non-PDF branch,
  `app_ui.R` accept list and blurb, `zipUpload.R`; `DESCRIPTION` Collate.

### Security — not optional, and the reason for the subprocess

XML carries two attacks a PDF does not:

- **Billion laughs**: nested entity definitions that expand a sub-kilobyte
  file into gigabytes. Resource exhaustion, not theft.
- **XXE**: `<!ENTITY x SYSTEM "file:///etc/passwd">` makes the parser read
  local files, or `SYSTEM "http://…"` turns the server into a request
  forwarder.

libxml2 defends against both **by default**. The danger is entirely in
options that switch the defence off — `NOENT`, `DTDLOAD` and above all
`HUGE`, which is the one someone adds at 2am to get past a "document too
large" complaint. So: read with defaults, never `HUGE`, and pin it in
`tools/securityCheck.R` as a tripwire rather than a convention. The
per-file subprocess contains what is left: a memory bomb kills the child,
not the app.

### Done looks like

- Synthetic JATS fixtures (mirroring `helper-syntheticDocx.R`): mean±SD,
  n (%) with complement columns, median [Q1, Q3], merged header cells,
  a decoy results table out-scored by the real Table 1, no caption.
- A **real PMC author manuscript** parses end to end.
- A billion-laughs fixture and an XXE fixture are both refused without
  reading a file or exhausting memory, asserted in tests.
- `tools/securityCheck.R` fails if `HUGE`/`NOENT`/`DTDLOAD` appear.
- **The ground-truth test**: for a sample of author manuscripts, the
  parsed table matches the registry's own baseline values. This is the
  point of the issue, not a bonus.

### Punts, recorded so they are not rediscovered

Multi-part tables split across sibling `<table-wrap>` elements are not
stitched. Tables supplied only as `<graphic>` fall to the existing OCR
path (issue 22), not here. Publisher DTDs that are not JATS are out of
scope; JATS covers PMC, Europe PMC and MECA, which is the whole corpus.

---

## 28. Report the build commit, so an unauthorized deploy is visible

**Status: implemented 2026-08-27** (PR #97 — `R/buildInfo.R`,
`tools/checkDeployedBuild.ps1`, scheduled task "IntegrityAnalysis
deployed-build check", daily 21:30).

From Steve's question: "do we have checks so that shinyapps.io itself
doesn't become malware?" Every control protected the *pipeline* — deploys
install only from GitHub, `securityCheck.R` gates
`deploy-production.yaml`, forks get no secrets, the tripwire bans
code-execution primitives — and **nothing attested the artifact**.

**How.** The deploy installs with `remotes::install_github()`, which
records the resolved commit as `RemoteSha` in the installed DESCRIPTION,
so the app already knew its commit and nothing had to be injected at
build time. Exposed as a `<meta name="integrity-build">` tag in the
initial HTML and a `commit` field on `GET /health`;
`checkDeployedBuild.ps1` compares both to `origin/main`.

**Not attestation.** Anyone able to deploy arbitrary code can report an
arbitrary commit. It catches the wrong branch, the stale deploy, the
rollback that never rolled forward, the hand-applied fix, and tampering
by anyone who did not think about it. The report distinguishes "behind
main" (ordinary) from "not a commit in this repository" (alarming),
because a check that cried wolf every time main moved would be ignored
within a week — and then the alarming case would be ignored too.

**What actually happened (2026-09-03).** Six production deploys after
this shipped, the live app still said "unknown", and the nightly check
flagged it every night from 2026-08-31. The deploy bundles only `app.R`;
the shinyapps.io builder installs the package itself, and the DESCRIPTION
it writes carries neither `RemoteSha` (PR #97's assumption) nor
`GithubSHA1` (PR #149's second guess - verified by the deploy after it,
still "unknown"). So the third route is the one that works: the deploy
job writes the commit it deployed to `build-sha.txt` beside `app.R`, and
the shim hands it to `buildCommit()` as `INTEGRITY_BUILD_SHA` after
checking it looks like a commit. The value is only as trustworthy as the
deploy job that wrote it - which is the "not attestation" caveat above,
unchanged. Confirmed by `tools/checkDeployedBuild.ps1` after the deploy
that carries this.

---

## 27. renv.lock pins versions but not contents

**Status: open.** Found 2026-08-27 while answering Steve's question
about malware in returned files.

All 125 package entries in `renv.lock` carry `Package`, `Version` and
`Source` — and **no `Hash` field**. So a restore is reproducible only as
far as the registry is honest: a hijacked re-release at the same version
number, or a compromised mirror, installs silently and every guarantee
built on package behaviour goes with it. The workbook-safety test
(`test-workbook-safety.R`) states this limit explicitly, because
"openxlsx writes strings, not formulas" is only as good as openxlsx
being openxlsx.

This matters more than it would in an ordinary app. The renv section of
AGENTS.md justifies pinning on the grounds that "an integrity finding
may be challenged, and the exact computational environment is on record
is part of the defense." A version number without a hash is a weaker
record than that sentence promises.

**Done looks like:** `renv.lock` carries a `Hash` per package and
`renv::restore()` verifies it, or the reason it cannot is written down
where the reproducibility claim is made.

---

## 26. An asynchronous API, for trials the synchronous one must refuse

**Status: open.** Surfaced 2026-08-27 when Steve asked whether capping
N at 10,000 would solve the compute-product problem.

The `/analyze` compute budget bounds the WORST case — every row
escalating to 100,000 replicates. The typical case is about 100x
cheaper, because rows stop at the first stage:

| 25 variables, N = 10,000/arm | |
|---|---|
| typical (rows stop at 1,000) | ~5 seconds |
| worst case (all rows escalate) | ~495 seconds |

The bind: **the rows that escalate are the suspicious ones.** So the
worst case is a fraudulent-looking mega-trial — precisely the
submission most worth analyzing. No synchronous budget both admits that
and bounds request time, which means the current design refuses its
most interesting inputs.

Steve's decision that a coarser p-value is worse than a refusal (issue
25's log, 2026-08-27) closes off the easy escape of quietly reducing
replicates. The remaining answer is to stop requiring an answer within
one request: `POST /analyze` returns a job id, the caller polls, and
the Monte Carlo runs to full precision however long it takes.

**Done looks like:** a publisher can submit any trial the app can
handle and get the same p-value the app would give, with no limit
imposed by HTTP. Until then the refusal message routes large single
trials to the web app, which has no request timeout.

---

## 25. Standing security screen: change-gated, adjudicated, not looped

**Status: implemented 2026-08-27** (`tools/securityScreen.ps1`, nightly
scheduled task "IntegrityAnalysis security screen", 21:00). Recorded
here because the *discipline* is the deliverable, not the script.

Steve asked whether to schedule a security screen when the API or UI
changes, and whether to re-run it after each patch "until it shows up
with zero issues" — the treat-to-target loop a physician runs on a
blood pressure. Both halves needed a qualified answer; AGENTS.md
"Two instruments, two stopping rules" carries the full reasoning.

**Scheduled, but change-gated.** Nightly at 21:00, doing nothing unless
the watched surface moved since the last screened commit (a ledger in
`tools/securityScreen.ledger`). A screen of an unchanged tree costs
tokens and produces noise. The ledger advances only after a report is
written, so a screen that dies leaves its range for the next run.

**Re-run after patches — but "zero issues" is the wrong endpoint.** The
tripwire (`securityCheck.R`) is a lab value: objective, defined normal,
free to repeat, and "repeat until normal" is exactly right. The screen
is a radiologist's read: it samples an *opinion*, so re-running always
yields new speculative findings and never converges to empty. Chasing
empty means patching what was never wrong — and **two of this project's
worst defects were introduced by security patches** (the CSV sanitizer
that broke issue 1's round-trip contract; the tripwire assertion that
matched a commented-out line and so passed on a deliberate break). The
endpoint is **every finding adjudicated** — fixed, or accepted with a
written reason — with each fix carrying an assertion verified to fail
on a deliberate break.

**"Are the API and UI the only entry points?" No.** They are the only
network-facing ones. The watched list also covers the parsers (a
manuscript is written by the adversary), `zipUpload.R`,
`outputComments.R`, and two that are easy to miss: `aiFallback.R`,
because a hostile document steers model output that becomes row labels
and CSV cells, and `.github/workflows/` + `renv.lock`, because
compromising the pipeline or a dependency beats any application bug.

**Found while writing this:** the standing conclusion in AGENTS.md that
"the AI fallback is off in deployment, so manuscript text never reaches
an LLM" had been false since the bring-your-own-key assist landed
(issue 8, PR #67). The code was reviewed when it merged; the *documented
conclusions it invalidated* were not. That drift is precisely what the
standing screen exists to catch, and it is the best argument for having
one.

**Done looks like:** each report in `docs/security-screens/` ending with
every finding marked fixed or accepted-with-reason before the next
merge touching the watched surface.

---

## 21. A medRxiv preprint stress-test corpus (no ground truth, by design)

Steve's idea (2026-08-25): harvest randomized-controlled-trial
preprints as a stress corpus. No ground truth for values — what it
buys is the opposite of validation: a firehose of AUTHOR-typeset PDFs
(Word exports, LaTeX, every table habit in the wild, no copyeditor),
which is exactly where parser crashes, hangs, and blind spots hide.
It earned its keep on night one (issues 22 and 23 both came from the
first five files).

**The route is S3 (2026-08-26, PR #80)**: the first night's HTTPS
fetches hit 403 on 67 of 72 (medRxiv bot protection, which we do not
evade); the replacement is the channel medRxiv built FOR bulk mining —
the requester-pays bucket s3://medrxiv-src-monthly, billed to Steve's
AWS account (verified: 100 packages, 842 MB, ~7 cents).
`corpus/harvestMedrxivS3.R` runs nightly (100 packages / 2 GB): lists
current+previous month, unpacks each .meca, reads DOI/title/abstract
from the JATS XML, applies the SHARED RCT filter
(corpus/rctFilterPatterns.R — the PR #74 rules, on real abstracts),
keeps RCT PDFs by DOI with license recorded in s3Manifest.csv, deletes
the rest. medRxiv's conditions honored by construction: TDM use, link
back, no re-hosting — corpus under C:/temp, never committed.
`downloadPreprintRCTs.R` remains for API metadata scans.

**OPEN**: fold parsing of freshly harvested PDFs into the nightly job
(snapshot-installed library, never load_all of the live tree — the
2026-08-25 contamination lesson), so each night's catch is
stress-tested by morning. Known residual filter leak: a paper whose
TITLE cites RCTs referentially (10.1101/19007195) passes; harmless.

---

## 20. Docling cross-check harness and PubTables-1M fixture mining

Filed 2026-08-25 (Steve's request, after surveying the document-parsing
landscape). Two additions to the parser optimization loop (AGENTS.md),
both LOCAL CORPUS TOOLING ONLY — nothing here ships in the deployed
app, which stays deterministic, offline, and R-only.

**Why the survey did not change the architecture.** The 2026 academic
benchmark of nine table extractors (arxiv 2511.16134, ~44k scientific
tables) puts the field's best — IBM Docling's detection + TableFormer
models — at ~0.99 table detection but only ~0.86 end-to-end
cell-structure accuracy on clean biomedical tables, with VLM-mode
hallucination reports; our engine's failure mode (refuse and say why)
is the right one for a fraud screen, and its structural accuracy on
what it accepts is the thing to measure and improve — hence the mining.

**PubTables-1M status (2026-08-26)**: annotation/word archives
downloaded (8.0 GB; the ~100 GB of page images deliberately skipped —
the engine consumes word boxes, which the dataset ships separately);
test split extracted (93,834 tables with structure XML + word-box
JSON). Mining runs in worktree C:/Temp/ia-pubtables against snapshot
library C:/Temp/ia-pubtables-lib via `corpus/minePubTables.R`
(chunked/resumable; engine commit recorded per row; word boxes feed
.ppParseBlock through the same seam as the docx adapter — no PDF, no
rendering, 0.05 s/table).

**Pilot (500 tables)**: 19.6% baseline-shaped (caption/±/n(%) signals)
→ ~18,400 ground-truthed baseline-style tables in the test split;
parse rate 62.2% within the shaped stratum vs 22.9% generic (the
semantic layer rightly refuses generic tables — never cite an
unstratified "parse rate" from this corpus); 37 shaped-but-unparsed
tables per 500 are the improvement queue (~7k extrapolated); shaped
tables carry more spanning cells (2.8 vs 1.9) — multi-level headers
are the likely wall.

**OPEN**: (a) full test-split run + report (in flight); (b) v2 scoring
— the v1 row/column agreement numbers are metric artifacts (template
variables ≠ printed rows; deliberately-dropped statistic columns count
against us) and need proper alignment before they mean anything;
(c) mine the shaped-but-unparsed bucket into ranked failure classes
and fixtures; (d) the Docling cross-check harness itself (run Docling
over the same word-box tables; disagreement = review queue).

---

## 12. Median/IQR rows (IMPLEMENTED 2026-08-17; validation approach open)

As shipped: Q1/Q3 columns; MEAN read as the median when both present;
metalog (3-term) null reconstructing the pooled population, exact
m/Q1/Q3 match including skew, |a3/a2| > 1.667 refused rather than
mis-simulated; simulated medians rounded as printed. Full design in
git history and R/ comments; parse-side extraction (engine + docx +
wide) landed 2026-08-21 with the text-evidence gate (IQR must be
STATED; ranges and unlabeled intervals are refused).

**REMAINING — the validation approach**: no Carlisle-style ground
truth exists for median rows. In place: a calibration property test
(honest lognormal trials → p roughly uniform) and direction tests.
Worth doing: a larger calibration study across N, skew, and rounding
regimes, and sensitivity of the metalog null against other plausible
shapes.

---

## 11. Live UI feedback while the Monte Carlo runs

Steve's request (2026-08-16). The p-value calculation can take a very
long time, and Shiny's single-threaded server locks the UI while
`P_Calc()` computes — no reactive flush, no log refresh, no button
response. What exists: `shiny::Progress` ticks once per TRIAL (its
`$set()` bypasses the flush) and `bslib::input_task_button` shows a
busy state — but within one long trial nothing moves and nothing can
be cancelled.

The real fix is to take the computation off the main thread:
`shiny::ExtendedTask` (+ promises/future) with the existing
input_task_button as its intended companion — UI stays live, per-trial
results stream into the log, Cancel becomes possible; a callr/future
worker polled via invalidateLater is the portable fallback; P_Calc's
row loop can then report per-ROW progress via callback.

**Do together with issue 5**: trial-level parallelism and off-thread
computation are the same plumbing. Test cancellation and
two-users-at-once on shinyapps.io, where workers are billed compute.

---

## 8. AI parsing in deployment — BYOK (app side and service side IMPLEMENTED; landing-page copy open)

The app side shipped 2026-08-25/26 (PRs #67, #70, #73, #77, #79 — the
masked key field with live validation, deterministic-first merge, green
provenance rows, per-session cap, page-image route for scans,
automatic re-read of failed uploads on key entry). Third-party
deployments enable it permanently with INTEGRITY_AI_ALWAYS=true and
their own ANTHROPIC_API_KEY — the gate is a policy, not a fork. The
guide carries consent language, the no-training/confidentiality
guarantees (Anthropic's Commercial Terms; ~30-day deletion), and the
measured rescue rates (91%/81%).

The service side shipped with issue 1 (2026-08-26): an `X-Anthropic-Key`
header on `POST /parse` or `POST /analyze` turns the assist on for that
request under the caller's key, live-verified end to end with an AI
rescue of a scanned table through the deployed service; the API User's
Guide (#163) documents it, and `docs/data-handling.md` states exactly
what is sent.

**REMAINING**: landing-page copy at integrityanalysis.io describing the
assist. The governing rationale (kept): the point is publication, not
concealment — the prompts and JSON schema ARE the algorithm, written
to be read; the gate is on the spending, never the method.

---

## 7. Survey other open-source research-integrity screens

Look for additional published, open screens that could be applied to
the same submissions and reported alongside the baseline analysis.

**Already tried and rejected — do not repeat without a reason:**
Benford's law and repeating-digit tests, both worthless here: a
baseline table supplies far too few numbers for digit-distribution
methods to have power. Judge any candidate first on whether it works
on tens of numbers.

Worth considering instead — screens that use *structure*: internal
consistency of means against totals, SDs impossible for the stated N
and range, granularity tests (GRIM/GRIMMER), terminal-digit balance
across arms.

**Candidates raised by Steve, 2026-08-17:**

- **SPRITE** (Heathers et al., https://shiny.ieis.tue.nl/sprite/):
  reconstructs possible samples behind a reported mean/SD of a bounded
  integer scale. Works on a single pair, so it passes the
  too-few-numbers test. Complementary: it catches impossible mean/SD
  pairs within one row where Carlisle–Shafer catches improbable
  agreement across arms. Natural fit as a per-row plausibility flag
  (with GRIM/GRIMMER) in validation — cheap, deterministic.
- **Barnett's Bayesian baseline method**
  (https://f1000research.com/articles/11-783): **IMPLEMENTED
  2026-08-30** — `barnettTStats()` and `barnettDispersion()` in
  `R/dispersionTest.R`.

  The characterisation recorded here on 2026-08-17 was wrong, and the
  correction is the reason the method is worth having. It is not "a
  Bayesian re-formulation of the Carlisle approach — same evidence,
  different inferential wrapper". It uses **different evidence** (a
  two-sample t-statistic per row per *pair* of arms, categorical rows
  included, where ours uses continuous rows only) and it tests a
  **different quantity**: ours tests the shape of a whole distribution,
  his tests one moment of it — the variance of the t-statistics.

  That distinction is the whole value. Barnett's own simulation study
  found that a distribution-shape test — his "uniform test", the family
  ours belongs to — fires on skew, on categorical data and on rounding,
  none of which is fraud, while a variance test does not. So the two
  disagreeing on the same table is diagnostic rather than embarrassing:
  it localises the anomaly to the shape of the distribution rather than
  to the spread of the data.

  Implemented by exact quadrature rather than MCMC. For a single trial
  his model has one binary switch and one continuous parameter, so the
  posterior is a one-dimensional integral; evaluating it directly is
  deterministic, dependency-free, and more accurate than the reference
  app's 1,000 kept draws (whose Monte Carlo error near his 0.95 flag
  threshold is about 0.007). `tests/testthat/test-dispersion.R` pins
  the agreement against nimble running his own model file.

Evaluation plan when picked up: run Carlisle–Shafer, Barnett, and
SPRITE/GRIM flags over corpus/TEST; compare per-trial calls; adopt
what adds discrimination, report what merely agrees as corroboration.
`corpus/barnettCorpus.R` does the first two over the 47,813-trial
ClinicalTrials.gov registry corpus, where the numbers are typed by
sponsors rather than parsed from PDFs and our parser is therefore out
of the loop entirely.

---

## 5. Optimise the Monte Carlo

The adaptive staged scheme (1,000 → 10,000 → 100,000 replicates,
escalating only while a row alarms) shipped 2026-08-17 and is the big
practical win; chunked simulation bounds memory; dqrng supplies fast
draws. **Remaining**: profiling, vectorisation of what is left, and
trial-level parallelism — which is the same plumbing as issue 11 and
should be designed with it. Profile before changing anything, and keep
issue 3's validation green throughout. Trials are independent, so
trial-level parallelism is the easiest large win for whole-corpus runs.

### First optimisation attempt found nothing worth taking (2026-08-28)

Profiled and measured at Steve's suggestion, using his method: a fixed
seed makes candidate rewrites verifiable, since identical draws must
give identical results. **No meaningful speed improvement was found.**
The loop is already close to what base R can do.

Where the time goes, for one chunk of 20,000 replicates x 2 arms x
N = 500:

| component | time | share |
|---|---|---|
| `rnorm` with the `rep()` mean | 0.894 s | 65% |
| `round(M, ROUND_OBSERVATION)` on the full matrix | 0.387 s | 28% |
| everything else | ~0.02 s | 2% |

`Nmat` / `rowsums` — the parts that look expensive — are about 1%.
Replacing them with a matrix-vector product measured *slower*.

Four rewrites were tried. All are **bit-identical**, which validates the
method; none is faster:

| rewrite | identical | speed |
|---|---|---|
| `rnorm(n)*sd + mu` instead of a vectorised mean | yes, max diff 0 | 1.00x |
| column recycling instead of `rep(meansim, N)` | yes | 0.91x |
| `round(M*10^d)/10^d` instead of `round(M, d)` | yes | 0.57x |
| `MCMean %*% N` instead of `Nmat` + `rowsums` | yes | slower |

**What would be faster, and what it costs.** `dqrnorm` draws ~3x faster
than base `rnorm`, but requires a SCALAR mean - which is exactly why the
code uses `rnorm` here. Rewriting as
`matrix(dqrnorm(N*ch), ch) * sd + meansim` (scale-and-add, column
recycling) measures **1.82x** on the full loop body. It is not
bit-identical: a different RNG stream moves every pinned Monte Carlo
value, so it would require re-baselining the known-answer fixtures and
re-running issue 3's validation.

**C was prototyped and is NOT faster.** A fused C kernel using R's own
`norm_rand()` - draw, round and accumulate in one pass, never
materialising the ch x N matrix - measured **0.94x**, slightly slower.
There is no interpreter overhead to remove: the loop is already three C
calls over ten-million-element vectors, and R's internals are better
optimised than a naive hand-written loop.

C also cannot be bit-identical here, for a reason worth recording.
`Rfast::rowmeans` does not sum in sequential order (pairwise or SIMD):

```
Rfast::rowmeans == base rowSums/n : FALSE, max|diff| 4.3e-14
after round(, 1): 8 of 1000 rows differ
```

A difference in the fourteenth decimal is arithmetically nothing, but
the code ROUNDS immediately afterwards, so it flips a value across a
`.05` boundary in about 1% of rows. Any fused implementation would have
to replicate Rfast's exact summation order to preserve pinned values.

**The one thing C buys unambiguously is memory**: 0.16 MB instead of
80 MB for that chunk, because nothing materialises the matrix. At the
current `1e8` chunk target the per-arm matrix is ~400 MB. That matters
for the OOM work in the 2026-08-28 screen, but it is a different goal
from speed and costs the package its first compiled dependency - and
`P_Calc.R` is the artifact the user guide now points investigators to,
so readable R has value beyond convenience.

Chunk size is also NOT a free parameter: with more than one arm the
per-arm `rnorm` calls interleave differently across chunks, so changing
`1e8` changes results. Verified on the real computation.

**Conclusion: leave it alone** (Steve, 2026-08-28). If the Monte Carlo
ever becomes the practical bottleneck, issue 26's async API buys more
than 1.82x by removing the request timeout altogether. Trial-level
parallelism remains the largest untried win and does not touch the
draws at all.

**Provenance worth recording**: this loop was written and optimised by
Steve in 2025. Four independent attempts to improve it produced nothing
faster, which is the useful measure of how well it was done.

---

## 3. Validate against Carlisle 2017 (COMPLETE; outlier adjudication open)

**The shipped engine reproduces Carlisle 2017** (full run 2026-08-21,
57.8 min, all 5,080 trials joined, zero refused): r = 0.9930, median
|diff| 0.0127, 90.3% within 0.05, alarm concordance 99.0%; 39 his-p=1
z=+∞ artifact trials reported separately. The validation is a
committed, reproducible artifact: `corpus/validateCarlisle2017.R`
(pilot and full modes, resumable via
.NewCarlisle/validation2017/results.csv). Method notes that still
matter: Carlisle's stored p.values are folded (< 0.5) and effectively
mid-p — the app's convention since PR #8; the One Sheet's A&A
numbering drifts by one above trial ~1234 (apply the offset before
using it as ground truth again).

**REMAINING**: adjudicate the 121 outliers (|diff| > 0.10; 50 disagree
on the p < 0.05 alarm) — per-trial values in results.csv; the worst
five are recorded there (e.g. NEJM 670: ours 0.129 vs his 0.634).

---

## 1. Build the API (BUILT and DEPLOYED 2026-08-26; hardening follow-ups open)

**Shipped**: `POST /parse` and `POST /analyze` behind bearer-token auth,
running on AWS App Runner from a container CodeBuild builds out of this
repository. The contract below is honored, including the round-trip
failure payload and confirmed deletion, and the per-request BYOK header.
Live-verified end to end, including an AI rescue of a scanned table
through the deployed service. Issuance is `tools/issueApiToken.R` (a
256-bit token shown once; only its SHA-256 is recorded, in a private
registry repository). Decisions and their reasoning:
`docs/api-spec.md`.

**OPEN follow-ups, in priority order** (from the 2026-08-26 security
review and its independent re-review):

1. **A real body cap in front of the service.** LARGELY SUPERSEDED
   2026-09-06 (#194, repeat screen F1): `runApiService()` now sets
   `options(plumber.maxRequestSize)` to the filter's 25 MiB before the
   router is built, so httpuv refuses an oversized declared
   Content-Length with a 413 before any of the body is buffered —
   verified on a local service. What remains open is the request with
   no Content-Length: a chunked body is still buffered by httpuv before
   the `sizelimit` filter refuses it, so the proxy/WAF cap ahead of App
   Runner is still wanted as the belt for the braces. H1 is closed for
   Content-Length requests and mitigated for chunked ones.
2. **Per-token quotas.** Request size and compute are bounded per
   request; nothing yet bounds how MANY requests one token may make.
   Worth having before the token list grows beyond people Steve knows
   by name.
3. **Self-service issuance** (Cognito + WAF) if demand justifies it -
   deliberately deferred; the design is in `docs/api-spec.md`.
4. **Version in `/health`**: the deployed image predates the 0.2.0
   bump, so `/health` still reports 0.1.0 until the next image build.

## 1a. The API contract (as built)

Expose the analysis so other programs can call it — the target is
editorial systems such as Editorial Manager linking to it automatically
and silently for fraud screening during peer review.

**Contract**

| | |
|---|---|
| Input | a single PDF, a Word manuscript (docx), a JATS XML article (xml), a picture of a table (jpg/jpeg/png/tif) **or** a spreadsheet (xlsx/csv — `.xls` is refused everywhere since #187, 2026-09-06) |
| On pass | run the Monte Carlo; return a CSV of the analysis, plus confirmation the PDF was deleted |
| On fail | return **the partial table**, carrying as much extracted data as possible, plus what is wrong with it |
| Retention | none — the PDF is deleted and the caller is told so |

**Decisions already made**

- **A failure is not a bare error.** It returns the failed table so an
  editor or reviewer can fill the gaps and call the API again, this
  time with a spreadsheet instead of the PDF. A failed scan is a round
  trip, not a dead end — which means *the failure payload must itself
  be valid input to the next call*. `writeIntegrityTemplate()` already
  emits exactly that layout.
- **No arm N, no analysis.** Without a hard-coded N the service
  returns a fail rather than running the Monte Carlo. About 58% of
  rows extracted from real articles carry no arm N.
- **No AI in the deployed path by default** — but see issue 8: the
  service side of BYOK (per-request key = per-request consent and
  billing) is the sanctioned way in.

**Watch for**

- Annotation must stay out of the data columns (a numeric flag would
  be swallowed as a category); use a text column or a separate sheet.
- Return `$skipped` (each unusable row and why), not a count.
- A folder of PDFs must go through `parseBaselineTableFiles()`, never
  a loop — ~2% of real PDFs hang poppler and R cannot interrupt it.
- Realistic expectation: fed a single PDF, the deterministic path
  yields a fully analysable trial 84.9% of the time on curated journal
  PDFs (recertified 2026-08-25), far less on raw submissions; the
  spreadsheet path is the reliable one.
