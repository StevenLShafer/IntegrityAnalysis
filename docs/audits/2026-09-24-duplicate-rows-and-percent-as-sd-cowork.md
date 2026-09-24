# Finding: duplicated variables, percentages read as SD, and page
# furniture read as a row label

**Source:** a Cowork session running `author_batch.R` over a 52-paper
corpus of randomised trials supplied by John Loadsman (editor,
*Anaesthesia and Intensive Care*) — anaesthesia trials from Diskapi
Yildirim Beyazit TRH, Ankara, and obstetric trials from Menoufia
University, Egypt. Corpus and per-paper triage:
`C:\dev\Fujii Boldt Reuben\Loadsman\`, checkpoints in
`_batch\Loadsman_RCT\`.

**Status: OPEN.** Three defects, independent of issue 34 (which is
fixed, and whose fix is verified on PMID 11375852). All three produce a
table that `validateData` accepts and `P_Calc` scores. The resulting p
is wrong, and nothing in the output says so.

**These defects were found only because the checkpoints now store the
validated table.** They are invisible in a workbook of p-values.

---

## 1. The same variable is emitted twice, under a truncated label and a
##    full one

`Polat 2015 DA Retracted.rds`, 21 rows, engine = hybrid. Six of the
rows are exact duplicates of six others:

```
ROW                                N     MEAN      SD
Amount of intraoperative           30   561.67  164.36
Amount of intraoperative           30   562.00  200.37
Amount of intraoperative           30   556.67  175.55
Amount of intraoperative fluid     30   561.67  164.36   <- same three
Amount of intraoperative fluid     30   562.00  200.37      values again
Amount of intraoperative fluid     30   556.67  175.55
Infusion duration of study         30    78.57   32.19
Infusion duration of study         30    79.67   28.09
Infusion duration of study         30    79.63   30.47
Infusion duration of study drug    30    78.57   32.19   <- and again
Infusion duration of study drug    30    79.67   28.09
Infusion duration of study drug    30    79.63   30.47
```

The real table has three continuous variables across three arms of 30.
The parse has five, two of them counted twice.

**Why this matters more here than in most parsers.** The method tests
whether baseline data are too homogeneous to have arisen by chance. A
duplicated row is perfectly consistent with its twin. Duplication does
not add noise; it adds fabricated agreement. This paper scored
P_CONT = 4.857e-06 and was reported to the user as the corpus's
strongest signal, on a corpus where it is one of three known-retracted
papers. That reading is not supportable while the duplication stands.

Note the effect is not one-directional: a duplicated variable doubles
its own contribution in whichever direction it pointed, so affected
papers at p = 0.97 are equally wrong.

**Scale.** 18 of the papers that produced a table are affected. The
label pairs are diagnostic of a prefix/truncation match:

| paper | rows | duplicated | reported p (FULL / CONT) |
|---|---|---|---|
| `PIIS1089947224000376` | 160 | 104 | 0.1559 / 0.1722 |
| `10.36516-jocass.1544053-4192834` | 192 | 98 | (no values) |
| `Akkaya 2015 EJA` | 48 | 36 | 0.002942 / 0.002203 |
| `2018RezkJMIG` | 36 | 18 | 0.9137 / 0.9174 |
| `2016RezkGE` | 32 | 12 | 0.006038 / 0.01603 |
| `s00266-023-03315-0` | 40 | 10 | (no values) |
| `Polat 2015 DA Retracted` | 15 | 6 | 0.0001611 / 4.857e-06 |
| `Polat 2021 JARSS` | 15 | 6 | 0.966 / 0.9757 |
| `Akkaya TN 2016` | 12 | 6 | 0.9711 / 0.9987 |
| `Ergil 2015 TJMS` | 12 | 6 | 0.8421 / 0.9446 |
| `10.36516-jocass.1537759-4165162` | 24 | 6 | 0.9297 / 0.9397 |
| `Akelma 2020 TJMS` | 15 | 3 | 0.01992 / 0.1129 |
| `Caparlar 2022 JNCP` | 12 | 3 | 0.1911 / 0.6487 |
| `Ergil 2012 IJPO` | 6 | 3 | 0.05761 / 0.1271 |
| `2018aRezkGE` | 12 | 2 | 0.5516 / 0.6855 |
| `RezkCEOG2015` | 12 | 2 | 0.1272 / 0.1055 |
| `Altinsoy 2022 TJMS` | 16 | 4 | (no values) |
| `10.17826-cumj.1221051-2839894` | 24 | 5 | (no values) |

Example label pairs, all from real output:

```
Age                          / Age, years +/- SD
Age                          / Age (years)
BMI                          / BMI [kg m
Height                       / Height, cm
Body mass index              / Body mass index (kg/m
AMH                          / AMH (ng/ml)
Antral follicle count, number/ Antral follicle count, number +/- SD
```

**The sharp edge.** Two pairs are not duplicates at all but *distinct
categories collided by a prefix match*:

```
I      / II
ASA I  / ASA II
```

Whatever rule produces the duplication must not merge these, and a fix
that deduplicates on label prefix would corrupt them. Deduplicate on
the (label, N, MEAN, SD) tuple, or fix the truncation at source — do
not fuzzy-match labels.

---

## 2. "n (%)" is read as MEAN and SD

`Akkaya 2015 EJA.rds`, 48 rows, engine = heuristic. **31 of the 48 rows
have SD > MEAN.** The table being read is a count-and-percentage table:

```
ROW                N    MEAN    SD
Catheter-related   20   18.0    90.0     <- 18 patients of 20, i.e. 90%
Catheter-related   20    2.0    10.0     <-  2 patients of 20, i.e. 10%
Moderate           20    4.0    20.0
Moderate           20    0.0     0.0
```

`MEAN` holds the count and `SD` holds the percentage. The checkpoint
carries **no category columns at all** (`cols` = TRIAL, ROW, N, MEAN,
SD, ROUND_*, SE), so the category machinery never engaged: `P_Calc`
scored these as continuous variables with a standard deviation. A
percentage is not a dispersion. The reported p = 0.0029 is meaningless,
and it was the corpus's second-strongest result.

Contrast `10.17826-cumj.1221051-2839894.rds`, where the same input
shape DID produce category columns (`MALE`, `FEMALE`, `ASA I`,
`ASA II`, `L2-3`, ...) — so the machinery exists and the question is
why it did not fire on Akkaya. Note that paper still shows 14 of 30
rows with SD > MEAN.

**A cheap and general invariant:** for a row scored as continuous, SD
greater than MEAN on a strictly positive quantity (age, weight, height,
duration, a count) is almost always a misparse. It should at minimum
raise an issue rather than pass silently.

---

## 3. Page furniture becomes a row label

Same paper, `Akkaya 2015 EJA`:

```
ROW = "Downloaded Mild"
```

"Mild" is the table's category. "Downloaded" is from the Wolters Kluwer
download banner stamped down the side of the PDF ("Downloaded from
http://journals.lww.com/... by ... on 07/23/2023"), which the text layer
interleaves with the table. The scored output literally contains a row
named `Downloaded Mild`. Any row label that begins with a token from the
page's download/copyright furniture is a misread.

---

## How to replicate

```
cd "C:\dev\Fujii Boldt Reuben"
"C:\Program Files\R\R-4.5.3\bin\Rscript.exe" author_batch.R Loadsman/RCT
```

then read the checkpoints (R, or `rdata` in Python):

```r
d <- readRDS("_batch/Loadsman_RCT/Polat 2015 DA Retracted.rds")
d$DATA[, c("ROW","N","MEAN","SD")]          # defect 1
d <- readRDS("_batch/Loadsman_RCT/Akkaya 2015 EJA.rds")
sum(d$DATA$SD > d$DATA$MEAN, na.rm = TRUE)  # defect 2: 31 of 48
unique(d$DATA$ROW)                          # defect 3: "Downloaded Mild"
```

Source PDFs are in `Loadsman\RCT\`.

## How to know it is fixed

1. `Polat 2015 DA Retracted` returns **9 continuous rows** (3 variables
   x 3 arms of 30), not 15, with no label appearing in both a truncated
   and a full form, and its p recomputed and reported as such.
2. `Akkaya 2015 EJA` either returns its counts as categories with their
   complements, or refuses the table. It must not return 48 continuous
   rows, and no row may be named `Downloaded Mild`.
3. `ASA I` and `ASA II` remain two distinct categories in
   `10.17826-cumj.1221051-2839894`. This is the regression that a
   careless fix to (1) will cause.
4. A scored continuous row with SD > MEAN raises an issue.
5. Nothing else moves: the `testthat` suite passes; the 2017 ledger row
   (currently 2026-09-24, 5,080 trials, r = 0.9903, 90.2% within 0.05,
   99.0% alarm concordance) does not move without a new row and a
   stated reason.

## Tests that must be committed, not just run

- A fixture built from `Polat 2015 DA Retracted`'s real Table 1
  asserting 9 continuous rows and no duplicate (ROW, N, MEAN, SD) tuple.
- A fixture asserting `ASA I` and `ASA II` survive as separate rows.
- A synthetic page whose table caption and a download banner share a
  line, asserting no row label contains a banner token.
- An invariant test over the corpus: no scored continuous row has
  SD > MEAN without an accompanying issue.

## The Fujii / Carlisle-2012 run carries the same signature

**Updated later the same day**, once `C:\Temp` was made visible to the
session. `carlisle168_batch.R` stores no table, but its stored `result`
frame carries one row per VARIABLE, with the variable's label. The
duplication of defect 1 is a label-pair phenomenon, so it is visible
there even without the data.

**23 of the 106 analysed trials (22%) carry prefix-pair labels**, and
the pairs are the same kind seen in the Loadsman corpus:

```
PMID_10411769   Age                      / Age (years)
                Height                   / Height (cm)
                Weight                   / Weight (kg)
PMID_10853207   Duration of anaesthesia  / Duration of anaesthesia (min)
                Duration of surgery      / Duration of surgery (min)
PMID_10649150   Age                      / Age (y, mean +/- SD)
PMID_10718795   Age (years)              / Age (years)*
PMID_10618943   Weight                   / Weight (kg)
```

**Six trials have an identical p on both members of a pair** —
PMID_10434165, PMID_10390665, PMID_10758447, PMID_17163298,
PMID_19358990 and one other — which is what an exact duplicate row
produces and is hard to explain otherwise.

Two further patterns appear here that the Loadsman corpus did not show,
and both are worse than duplication because they are not variables at
all:

```
PMID_16982288   Mean / Mean 2 / Mean 3 / Mean 4       (16 "variables", 65 rows)
PMID_19446145   Mean / Mean 2 / Mean 3 / Mean 4       (59 rows)
PMID_17697904   Mean / Mean 2 / Mean 3 / Mean 4       (45 rows)
PMID_24944401   Mean / Mean 2 / Mean 3
PMID_11240988   Unnamed / Unnamed 2
PMID_8669653    Unnamed / Unnamed (row 2, likely age, yr)
PMID_12182258   Mean +/- SD / Mean +/- SD 2           (67 rows, p = 1.6e-06)
```

A column header (`Mean`, `Mean ± SD`) is being scored as a baseline
variable, disambiguated with a numeric suffix. `PMID_12182258` is the
largest table in the set and scored **p = 1.633e-06** - the second most
extreme result in the whole Fujii comparison - with `Mean ± SD` among
its variables.

**Consequence.** Part of the divergence between our Fujii results and
Carlisle 2015, currently attributed to method (Monte Carlo vs normal
theory; one baseline table vs several), has a parser cause. That
comparison should not be published until this run is repeated on a
fixed parser. Do not treat the prefix-pair count as a measurement of
harm - without the tables it is a signature, not proof, except for the
six with matching p.

## What still cannot be checked from the stored output

### (original note)



Whether the Fujii / Carlisle-2012 run of 2026-09-24
(`Carlisle168_results_2026-09-24.xlsx`, 106 analysed) carries the same
contamination **cannot be determined from what was stored**.
`carlisle168_batch.R` saves only the `P_Calc` result, not the table, and
its checkpoints went to `C:/temp`. The workbook's `N_ROWS` is
suggestive but not diagnostic: median 30, but 67, 66, 65, 59 and 57 rows
on single trials, and the largest table in the set
(`PMID_12182258`, 67 rows, 43 continuous) scored p = 1.6e-06.

That run must be repeated with a script that keeps the validated table
before any comparison against Carlisle is published. `carlisle168_batch.R`
was patched on 2026-09-24 to store `v$DATA` and `provenance`, to default its
checkpoints to `<PROJ>/_batch/Carlisle168` instead of `C:/temp`, and to set a
seed. If duplication is
present there, some part of the gap against Carlisle 2015 currently
attributed to method (Monte Carlo vs normal theory, one-table vs
several) has a different cause.

`author_batch.R` was patched on 2026-09-24 to store the table on every
branch, including both failure paths, and to store `provenance`. That is
why this corpus could be diagnosed and the Fujii one cannot.


## Ground truth is available — use it to pin the fix

`C:\dev\Corpus\registry\carlisle-tables\One Sheet Carlisle Data.xlsx`
is John Carlisle's **hand-entered** baseline data for the 2017 corpus:
5,075 PMIDs, 72,141 variable-arm rows, one row per (variable, arm).
Columns, by spreadsheet letter (there is no header row, and column A is
empty): **B** variable index, **C** arm index, **D** N, **E** mean,
**F** SD, **G**/**H** rounding flags, **I** PMID. Continuous variables
only; no labels and no categories, so it tests counts and values, not
row names.

It was entered by hand by the method's author. For the defects in this
document it is as close to ground truth as this field gets, and it makes
the duplication test decisive rather than inferential: **if our parse
returns two rows with identical (N, mean, SD) where Carlisle entered
one, that is proof, not a signature.**

Overlap with the three fraud corpora, extracted to
`C:\dev\Fujii Boldt Reuben\Carlisle_handentry_ground_truth_2026-09-24.csv`
(1,365 rows):

| corpus | papers with hand entry | variable-arm rows |
|---|---|---|
| Boldt | 39 | 806 |
| Fujii | 20 | 429 |
| Reuben | 12 | 130 |

**Boldt is the valuable one.** Those 39 papers have never been run
through the parser, so they are a genuine held-out test: fix the
parser, run Boldt, compare against Carlisle's hand entry per
variable-arm. Fujii's 20 are not held out.

Only 5 of the 106 analysed Carlisle-2012 trials overlap the hand entry
(the 2012 and 2017 corpora are largely disjoint). On those 5, ours
matches Carlisle's variable and row counts exactly on 2, and returns
more variables on 3:

```
PMID       ourVars ourRows  JCvars JCrows JCarms
10648342         7      28       4     16      4   ours +3 vars
15574561         4       8       3      6      2   ours +1 var
15872124         4      12       4     12      3   match
10958102        11      33       8     24      3   ours +3 vars
12374721         8      24       8     24      3   match
```

Three of five returning more variables than the method's author entered
by hand is consistent with defect 1, but five trials is not a
measurement, and Carlisle may have excluded variables for reasons of
his own. Treat it as a pointer to the Boldt test, not as a result.

## Also open, unrelated to the three defects above

`author_batch.R` and `carlisle168_batch.R` **set no random seed.**
`P_Calc` is a Monte Carlo simulation; every published figure from those
scripts is unreproducible, including the Carlisle-168 comparison.
`corpus/checkFujii11375852.R` does it correctly:
`set.seed(42); dqrng::dqset.seed(42)`. Both batch scripts need the same,
and the affected runs need repeating.
