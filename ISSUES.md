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

## 40. The "first table" caption bonus never fires (open)

**Status: open, 2026-09-25.** `.ppCaptionScore()` adds 2 for a caption
that begins "Table 1" or "Table I", the reasoning being that baseline
data is nearly always the first table. The pattern is case-sensitive,
so it matches only a lower-case "table 1" — which no journal prints —
and every printed caption has scored without it since the rule was
written. Enabling it changes candidate scores across the corpus; it
needs a before/after misparse run (`corpus/measureMisparse.R`) before
it is switched on, and may need a smaller weight.

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
