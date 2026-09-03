<!--
  user-guide.md - THE user documentation for IntegrityAnalysis.

  PROVENANCE: rewritten as Markdown by Claude Code (model Claude Fable 5),
  2026-08-19, at Steve Shafer's request (ISSUES.md issue 14), from Steve's
  Word/PDF original (G:\Projects\Fraud\2025\Old Files\IntegrityAnalysis.docx,
  last edited 2025-09-01). The background narrative is Steve's text, lightly
  edited; every section describing the app was updated to the 2026-08 state:
  one-sided p toward homogeneity, adaptive replicates, the editable grid,
  color-coded cells, median/IQR rows, PDF parsing, multi-file upload, the
  purge guarantee, and the journal-style baseline table download.
  Zipped multi-file upload added 2026-08-20; journal-style wide tables
  as INPUT (issue 17) added 2026-08-21.

  TO REGENERATE THE SERVED HTML after editing this file:
    "C:\Program Files\Quarto\bin\tools\pandoc.exe" docs/user-guide.md
      -s --embed-resources --toc --metadata title="IntegrityAnalysis"
      -c docs/user-guide.css -o inst/extdata/IntegrityAnalysis.html
  (one line; see AGENTS.md). The same file is published by
  .github/workflows/pages.yaml as https://integrityanalysis.io/guide.html,
  which the app's sidebar "View Documentation" link opens.
-->

**A Shiny implementation of the Carlisle–Shafer Monte Carlo analysis of
RCT baseline data.**

The application runs at
<https://steveshafer.shinyapps.io/IntegrityAnalysis/>. The code is open
source at <https://github.com/StevenLShafer/IntegrityAnalysis>.

**Privacy: nothing you upload or enter is retained on this server, and
nothing leaves it unless you supply an AI key.** The uploaded PDF or
spreadsheet, any data typed into the table, and the analysis results are
all purged when the session closes. No record of the analysis is kept
here.
Manuscripts under review are confidential, and the app is built around
that: uploaded files are deleted from disk when the session ends,
downloads are generated straight into your browser, and nothing is
logged. The deployed analysis is fully deterministic and offline — no
document content is ever sent to any third-party service — with one
opt-in exception under your sole control: the **AI assist** (see below)
engages only when you enter your own Anthropic API key, and entering it
is your explicit consent to send your uploaded documents' content to that
service for the session. Even then confidentiality holds: Anthropic's
commercial terms bar it from training models on API submissions, and
API data is deleted within about 30 days (see the AI-assist section for
the specifics). Without a key, nothing you upload ever leaves this
server.

**Usage counting:** I tabulate the number of times IntegrityAnalysis is
opened and the number of analyses run — simple counts, and nothing
else. Not even your IP address reaches the counter, because the count
is sent by the server, not by your browser. I want to know whether the
program is being used: there is no point maintaining a program that
nobody uses. — *Steve Shafer*

# Background

For about 15 years, papers published by Yoshitaka Fujii had been
considered sketchy. In 2000, Kranke and colleagues wrote a letter to
Ronald Miller, Editor-in-Chief of *Anesthesia & Analgesia*, with the
snarky title: "Reported data on granisetron and postoperative nausea and
vomiting by Fujii et al. are incredibly nice!" The authors pointed out
the impossibility of nearly every group in every randomized controlled
trial published by Fujii having one headache as an adverse event. Dr.
Fujii's response was "the data are the data." Nothing more was done.

In 2012, John Carlisle published a landmark paper, "The analysis of 168
randomised controlled trials to test data integrity" [1]. Carlisle's
insight was that baseline data in a randomized controlled trial are
samples of the same pre-treatment population. The differences between
sample means reflect the standard deviations within the underlying study
population. One can test whether the means of two groups (say, a control
arm and a treatment arm) are "too close."

For example, say the mean weight of a control group of 6 subjects is
77 ± 30 kg and the mean weight of a treatment group of 6 subjects is
78 ± 30 kg. With a standard deviation of 30, the standard error of each
mean is about 12 (30/√6). Each group mean is just 0.5 kg from the grand
mean of 77.5. A two-tailed t test yields p = 0.96: 96% of the time, the
means would be this far apart *or further*. They are certainly not far
enough apart to suggest different populations.

It is a different question whether they are **too close**. If random
chance says that 96% of the time the means would be further apart, then
only 4% of the time would they be this close. Seen once, that is no big
deal — it is expected in 4% of random samples. Seen again and again, in
variable after variable and trial after trial, something is definitely
amiss.

Reviewing 168 papers by Fujii, Carlisle found far too many baseline
means that were too close. The joint p value across the Fujii trials was
about 10⁻³³. Carlisle's analysis unmasked years of data fabrication and,
at last count, the retraction of 172 papers [2].

There were two technical problems. First, the conventional standard
deviation — the square root of the unbiased variance — is itself a
biased estimate of the population standard deviation. The bias is modest
[3] and did not affect Carlisle's conclusions; this app corrects for it
(see *Statistical details* below). The more significant problem is
**rounding**. Suppose both groups report a mean weight of 77. The
difference between the groups is 0, and under normal statistical theory
a difference of exactly 0 between two random samples is impossible — the
p value degenerates. In the real world it happens all the time, because
published data are rounded.

The way out is to abandon normal theory and instead **replicate the
study by Monte Carlo simulation**, rounding the simulated data exactly
as the published table was rounded. John Carlisle and Steve Shafer spent
several years developing this method and in 2015 published a re-analysis
of the Fujii data [4]: same verdicts, and in simulation the Monte Carlo
approach proved more robust than normal theory. In 2017, Carlisle
applied the approach to 5,087 randomized controlled trials from eight
journals [6]. This app is the current implementation of that method, and
its engine has been validated line by line against Carlisle's 2017
results (see *Validation* below).

# Quick start

1. Open <https://steveshafer.shinyapps.io/IntegrityAnalysis/>.
2. Get your baseline table into the app by any of the routes below —
   for most users that simply means uploading the article PDF or Word
   manuscript; spreadsheets, multi-file batches, and typing into an
   empty table are also supported.
3. Review the table in the editable grid. Fix anything colored (see
   *The data grid* below), then click **Apply Edits & Revalidate**.
4. When the table validates, click **Analyze**. Each trial's p value
   appears as it completes.
5. Download the results, the current table (a valid input file for a
   later session), and the reconstructed baseline table (the
   journal-style view, for comparison against the manuscript).

## The ways in

The app reads nine kinds of input, and every one of them lands in the
same editable grid: a **template spreadsheet**, a **journal-style
baseline table** in a spreadsheet, an **article PDF**, a **picture of a
table**, a **Word manuscript**, a **JATS XML** article, **several files
at once**, a **zip archive** of many, and an **empty table** you type
into. Each is described below.

*However a file arrives — the Browse button, **dropped anywhere on the
page** (one file or several, any of the types below, and a zip of
them), or **pasted** (a screenshot of a table sits in the clipboard as
a PNG on Windows, macOS, Linux, iOS and Android; Ctrl+V or Cmd+V on the
page uploads it as a picture of a table) — it takes exactly the same
path through the app. The message box names every file as it arrives
and by which door. A dropped file of a type the app does not read is
refused with a note; nothing is opened by the browser. A paste that
carries text, or a paste into a text field or the grid, is left to do
what it always did. On a phone, whether a page-level paste of a picture
reaches the app depends on the browser; the picker and the drop always
work.*

**A template spreadsheet.** A spreadsheet in the app's own long format
(Excel `.xlsx`/`.xls` or `.csv`) uploads directly. The column layout is
described in *Preparing your data* below — but few users should ever
need to build one by hand: upload the article itself, or use the
journal-style route next, and note that the app's own table downloads
are all valid input files. (The sidebar's Template and Example
downloads were retired in August 2026 for the same reason.)

**A journal-style baseline table.** A spreadsheet laid out the way
journals print Table 1 — variables as rows, arms as columns with their
sizes in the headers ("Control (n = 50)"), cells like "45.3 (12.1)" —
uploads directly; the app recognizes the layout and converts it into
template rows itself. **Any spreadsheet format works here — Excel
`.xlsx` and `.xls`, and plain `.csv`** — so a table pasted out of a
manuscript into a CSV is as good an input as a workbook. The app's own **Editor's View** download is
exactly this format, so a table downloaded from one session (or received
from a colleague) is valid input to the next. What the cells may hold:
"mean (SD)" and "mean ± SD"; "median [Q1, Q3]" **when the row label says
the interval is an IQR** (a median with a min–max range, or with an
unlabeled interval, is flagged for hand entry instead — the analysis
needs quartiles, and the app will not guess); "n (%)" counts, which
become a category with its complement; and bare counts indented under a
category header ("Sex, n"). A row the app cannot read arrives as a
red-flagged grid row with the reason on hover, exactly like an
imperfect PDF extraction. Mean and SD in *separate columns* is the
template format above, not this one.

**An article PDF.** Upload the article; the app finds the baseline
table ("Table 1") in the text layer and extracts it into the grid. The
extraction is deterministic — the same PDF always yields the same table
— and entirely local. Median rows are extracted too, **when the table
says the bracketed interval is an IQR** (in the row label, caption, or
footnote); a median with a min–max range, or with an unlabeled
interval, is flagged for hand entry instead — the analysis needs
quartiles, and the app will not guess. Extraction is imperfect by
nature: table lines the reader could not use appear as red-flagged rows
in the grid (fill them in from the paper, or delete them). A scanned
page with no text layer is beyond the deterministic reader — but with
an API key entered, the AI assist reads the rendered page image
directly (see the AI assist section). Without a key, the app tries
local **optical character recognition** (tesseract) on the scanned
page: when OCR reads the table usably, the whole extracted table is
shaded **pale cyan** with a warning, because OCR can misread digits
(3 vs 8, 1 vs 7) — carefully verify every cyan value against the
manuscript before analyzing. A scan too degraded for OCR fails cleanly
with a message; the AI assist reads such pages far more reliably, and
everything OCR does happens on this server — nothing leaves it.
Whatever was extracted can be reviewed, corrected, and analyzed
without leaving the app.

**A picture of a table (jpg, png, tif) — uploaded, dropped, or
pasted.** A screenshot or scan of Table 1 uploads like a PDF, and a
screenshot can simply be pasted onto the page: the app reads it with
local optical character recognition (tesseract) and extracts the table
into the grid, shaded **pale cyan** with the same verify-every-value
warning as a scanned page — OCR can misread digits. The picture is
taken to *be* the table: it is read whole, from its first line, with no
search for a "Table 1" caption (one may be present or not) and no
attempt to split it into page columns, so a screenshot of just the
table is the ideal input. It works best on a clean picture at 200–300
dpi; at screen resolution (96 dpi) small type is at the edge of what
OCR reads reliably, so check the cyan values with particular care. The
picture is decoded by the app's own OCR reader, never by ImageMagick,
and its declared dimensions are checked from the file header before any
decoder runs — an oversized or malformed image is refused with a
message. (GIF is deliberately not accepted: its header cannot bound
what its decoder allocates.) With an API key entered, a jpg or png is
sent to the AI assist as an image (a tif is read by OCR only; the model
does not accept it).

**A Word manuscript (.docx).** A submission in Word format uploads the
same way as a PDF: the app examines every table in the document —
submissions put them at the end, with the caption just above — picks
the baseline table by its caption and content, and extracts it into the
grid. Because a Word table is a real table rather than a picture of
one, extraction is typically cleaner than from a PDF. The same
safeguards apply: deterministic, entirely local, unusable lines
red-flagged in the grid, and when no printed arm sizes exist the app
looks for "(n = …)" statements in the Methods text (flagged for
checking against the CONSORT diagram). The table must be a genuine Word
table — a picture of a table pasted into the document has no text to
read there. Paste the picture itself onto this page instead, and it is
read as a picture of a table (above).

**A JATS XML article.** The XML that PubMed Central, Europe PMC and
publishers' production systems emit for an article (`.xml`, the JATS
tag set) uploads like a PDF. A JATS table is a real table — rows and
cells, not positions on a page — so extraction is the cleanest of all
the document routes: the caption and the footnotes travel with the
table, and the only interpretation left is what the numbers mean, which
is the same for every route. Vertically merged cells (a category name
spanning its rows) are unfolded the way the printed table reads. This
is the route intended for editorial systems, which hold the manuscript
as XML long before a PDF exists.

**Several files at once — or one after another.** Any mix of
spreadsheets, PDFs, Word manuscripts, JATS XML files and pictures in
one selection, and any
number of uploads in sequence: **each upload appends to the table
already in the grid**
(including edits you have typed but not yet revalidated). Every file
becomes rows in the combined table, distinguished by the TRIAL column; a
file without trial identifiers gets its file name as the trial. If a new
file uses trial labels already in the table, its labels are prefixed
with its file name so nothing silently merges. To start over, click
**Start With an Empty Table**.

**A zip archive of a whole analysis.** Zip any number of spreadsheets,
article PDFs, Word manuscripts, JATS XML files and pictures of tables
into one `.zip` and upload just that. This is built
for reproducing a multi-trial investigation — the pattern of Carlisle's
2012 review of Fujii's 168 trials
([PMID 22404311](https://pubmed.ncbi.nlm.nih.gov/22404311/)): put one
file per trial in the archive and every entry becomes its own trial in
the combined table, named after its file. Folders inside the archive
are fine (only the file names are used); files that are not
csv/xls/xlsx/pdf/docx/xml/jpg/png/tif are skipped with a note, an
archive inside the archive is not expanded, and a corrupt archive is
reported rather than analyzed.

The limits, and what they mean in practice:

- **The zip file itself may be up to 50 MB** — the binding constraint
  in practice. Journal PDFs run about 0.5–2 MB, so one archive holds
  roughly 25–100 typical articles.
- **Inside the archive: at most 300 files and 300 MB uncompressed**,
  checked before anything is parsed.
- **Each PDF gets 60 seconds to parse** (5 minutes when the AI assist
  is on), so one pathological file can never stall the batch — it is
  reported as failed and the rest continue.
- **Uploads accumulate**: a collection larger than one zip goes up as
  several zips in succession, and everything lands in the same
  combined table, analyzed trial by trial. Expect a few minutes per
  ~50 PDFs, with the progress bar ticking file by file.

**An empty table.** Click **Start With an Empty Table** and type the
data straight into the grid — eight empty rows and placeholder category
columns (CAT1–CAT3) to start. Add rows with the right-click menu or the
**Add 5 Rows** button; add a named column with **Add Column**.

## The AI assist (optional — bring your own key)

The deterministic reader is deliberate about refusing what it cannot
verify, and fed a single article PDF it yields a fully analyzable trial
roughly a third of the time. For the rest, an optional **AI assist**
exists: enter your own Anthropic API key in the field above the upload
box, and pages the deterministic reader cannot fully parse are sent to
the Anthropic API — under *your* account, at roughly $0.06–0.11 per
article. Pages with no text layer at all — scanned pages, or tables
pasted into an otherwise digital manuscript as pictures — are sent as
rendered page images, which the model reads directly, and an uploaded
jpg or png of a table goes the same way; this is the only route in the
app that can reach a degraded scan. When even no table
can be found, the assist also asks for baseline data stated in the
article's running text (some trials report age, weight, and sex in a
Methods sentence rather than a table).
Measured against Carlisle's hand-extracted values, the assist recovers
about 91% of known values on articles with no parseable table and 81%
where the deterministic reader misread the table.

The key is **checked the moment you enter it** — a green "Key
validated" confirms this session is armed (the check is free: it
authenticates without spending tokens); an invalid key is refused in
red and the field cleared, so a typo can never sit there looking
accepted. Each browser tab is its own session, and the green check
tells you which tab holds the live key.

The ground rules, each deliberate:

- **Your key is your consent.** Without a key, no document content ever
  leaves the server; entering one authorizes sending your uploads'
  content — the text of unparseable pages, or, for pages with no text
  layer (scanned tables, tables pasted in as pictures), the rendered
  page image — to the Anthropic API for this session — appropriate only
  when you have the right to share the document.
- **The handoff stays confidential and is never used for model
  training.** This is not something the app has to request on each
  call — no such per-request instruction exists, and none is needed,
  because it is the contractual default for every Anthropic API key:
  under Anthropic's [Commercial Terms of
  Service](https://www.anthropic.com/legal/commercial-terms), everything
  sent through the API is the key holder's confidential information,
  and "Anthropic may not train models on Customer Content." Anthropic
  [automatically deletes API inputs and
  outputs](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
  within about 30 days (held longer only under legal requirements or a
  trust-and-safety flag). A manuscript sent to the assist therefore
  never enters any future model, and is deleted from Anthropic's
  systems within a month.
- **The key is never stored, never logged, and dies with the
  session.** It goes in a masked field, not a URL.
- **The deterministic reader always runs first and its numbers always
  win.** The assist only fills gaps, and every AI-read line paints
  **green** in the grid with a note to verify it against the
  manuscript. The results workbook's audit trail records which engine
  read each line.
- **A per-session cap** (25 documents) bounds spending even on your own
  key.
- **Publishers running their own instance** can enable the assist
  permanently by deploying with `INTEGRITY_AI_ALWAYS=true` and their
  own `ANTHROPIC_API_KEY` — the gate is a policy, not a hard-coded
  switch, so no fork is needed.

# The data grid

Every input route lands in the same editable grid, and the grid is the
data of record: what you see is exactly what will be analyzed. Edit any
cell, add or delete rows (right-click), and click **Apply Edits &
Revalidate** to re-check the table.

Validation reports problems by **coloring the cells** — there is no
error text to read. A legend under the grid explains the colors whenever
any cell is painted, and hovering over a painted cell explains that
specific cell:

- **Yellow — missing.** A required value is empty. Enter it, or delete
  the row. Rows with a label but no data at all are left out of the
  analysis (they do not block it).
- **Red — unreadable.** Text where a number belongs — for example
  "n/a" in an SD cell of an uploaded spreadsheet — or a table line the
  PDF reader saw but could not use. For a PDF line, hover over the red
  cell to see the reader's reason (for example, "median [range] —
  integrity analysis needs mean and SD").
- **Blue — incongruent.** The value conflicts with the type of its row:
  an SD on a median/IQR row, continuous entries on a category row, a
  median outside its own quartiles, an SE standing in for a missing SD.
- **Pale cyan — read by OCR.** The whole table came from a scanned page,
  or an uploaded picture of a table, read by optical character
  recognition. OCR can misread digits (3 vs
  8, 1 vs 7), and in a fraud screen a single silently wrong digit
  matters — verify every value against the manuscript, or enter an
  Anthropic API key and re-upload for the higher-accuracy AI read.

A table with no colors and no legend validated cleanly, and the
**Analyze** button appears.

# Preparing your data

You rarely need this section any more: the app parses PDFs, Word
manuscripts, and journal-style tables into this format itself. It
matters when you type data into an empty table, hand-build a template
spreadsheet, or want to understand exactly what the simulation
consumes — the internal data frame every input route produces.

Each line of the table is one cell of the manuscript's baseline table:
one variable in one study arm. Lines that share a ROW label are the arms
of that variable.

## Continuous variables (mean and SD)

Four columns are required:

| Column | Meaning |
|---|---|
| `ROW`  | what is measured — "Weight", "Age", "Duration of surgery" |
| `N`    | number of subjects in the group |
| `MEAN` | the group mean, exactly as printed |
| `SD`   | the group standard deviation, exactly as printed |

A study with one baseline variable (weight) and three arms:

| ROW | MEAN | N | SD | ROUND OBSERVATION | ROUND MEAN |
|---|---|---|---|---|---|
| Weight | 72 | 100 | 10 | 0 | 1 |
| Weight | 76 | 50  | 12 | 0 | 1 |
| Weight | 64 | 50  | 25 | 0 | 1 |

The two rounding columns tell the simulation how the published numbers
were rounded — the heart of the method. `ROUND OBSERVATION` is the
precision of the raw data (0 = integers); `ROUND MEAN` is the decimal
places of the printed mean. If omitted, the app infers them from the
decimal places of the values themselves. An optional `ROUND DISPERSION`
column gives the printed precision of the SD when it differs from the
mean's (a table may print "39 (4.06)").

If the paper reports a **standard error** instead of a standard
deviation, enter it in an `SE` column. The analysis needs an SD; the app
deliberately does not convert for you (the conversion needs N and is a
decision about the analysis), and validation will point at the row — the
SE cell paints blue, the SD cell yellow.

## Median [IQR] variables (median with quartiles)

Many papers report skewed variables as **median [IQR]** — printed as
"median [Q1, Q3]", "median (IQR)", or "median [25th–75th percentile]";
the interquartile range IS the span from the first quartile (Q1) to the
third (Q3). Enter these with two additional columns, `Q1` and `Q3`. On
a row where both quartiles are filled in, **the MEAN column holds the
median**, and the SD and SE cells must be empty.

A study reporting duration of surgery as median [Q1, Q3] in two arms:

| ROW | MEAN | N | Q1 | Q3 | ROUND MEAN |
|---|---|---|---|---|---|
| Duration of surgery | 127 | 50 | 98  | 160 | 0 |
| Duration of surgery | 133 | 50 | 101 | 155 | 0 |

`ROUND MEAN` is the printed precision of the median, exactly as for a
mean. The median must lie between its quartiles; N, the median, and
both quartiles are required. The simulation for such rows draws from a
distribution fitted to the three quartile values (a metalog
distribution), so no normality assumption is imposed.

Two printed forms that look similar cannot be used, and validation
will say so rather than guess:

- **median (range)** — a sample's min–max carries almost no
  information about the population spread; such lines are refused with
  an explanation. (This is also why the PDF and Word readers extract a
  median row only when the table *says* the bracketed interval is an
  IQR — an unlabeled `[a–b]` could be either.)
- **median with a single IQR width** — "127 (IQR 62)" gives the span
  but not where it sits around the median; the analysis needs the two
  quartiles themselves. Recover Q1 and Q3 from the paper if printed
  elsewhere, or leave the row out.

## Categorical variables (counts)

Categorical variables — sex, ASA class, type of surgery — are counts,
entered as **additional named columns**. From the example spreadsheet:

| ROW | N | MEAN | SD | Male | Female | Upper | Lower | Urologic |
|---|---|---|---|---|---|---|---|---|
| Sex | | | | 40 | 10 | | | |
| Sex | | | | 34 | 16 | | | |
| Surgery | | | | | | 7 | 8 | 35 |
| Surgery | | | | | | 7 | 15 | 28 |
| Weight | 15 | 63 | 13 | | | | | |
| Weight | 17 | 68 | 12 | | | | | |

Two arms: the first has 40 men and 10 women, the second 34 and 16. On a
category row, `N`, `MEAN`, and `SD` must be blank (blue cells point at
violations). A column is recognized as categorical when it is numeric,
integer-valued, and not filled on every line.

## Multiple trials

A `TRIAL` column separates trials; each is analyzed independently. With
no TRIAL column, everything is one trial. Lines of one variable need not
be adjacent — a (TRIAL, ROW) pair defines the variable, wherever its
lines sit. The same ROW name ("Age") can appear in any number of trials.

## Column-name flexibility

Column names are case-insensitive and trimmed. The first column
containing "TRIAL" becomes TRIAL and "ROW" becomes ROW — so "My Trial
ID" or "Row Label" are understood. `MEAN`, `N`, and `SD` must be named
exactly that (any capitalization); an *additional* column containing
"MEAN" becomes ROUND MEAN, and the first column containing "OBS" becomes
ROUND OBSERVATION. Carlisle's 2017 spreadsheet columns (`MEASURE`,
`DECM`, `NUMBER`) are also accepted. Unrecognized columns are carried
along untouched and ignored by the analysis.

# The analysis

## The p value: one-sided, toward homogeneity

For each variable, the app simulates the trial many times: for every
arm, N subjects are drawn from a normal distribution with the pooled
mean and (bias-corrected) SD; each simulated observation is rounded like
the raw data; each simulated mean is rounded like the printed mean; and
the weighted sum of squared deviations of arm means from the grand mean
is computed. The **p value is the fraction of simulations at least as
homogeneous as the reported data** (a mid-p: ties count half). Small p
means the printed means are closer together than random sampling can
readily explain — the Fujii signature. This is deliberately one-sided:
the earlier practice of doubling the proximity p was, in retrospect, a
mistake, and this implementation reports the one-sided value only.

A small p value is a **screening signal, not a verdict**. Innocent
explanations include stratified or blocked allocation, correlated
variables, mislabeled SEMs, and transcription errors — Carlisle's 2017
paper [6] discusses them at length. A trial flagged here deserves
scrutiny of the original data, not summary judgment.

**CAVEAT: Chance alone will produce P ≤ 0.05 in 1 in 20 papers, and
P ≤ 0.01 in 1 in 100 papers. Research fraud should never be alleged by
a single manuscript flagged by IntegrityAnalysis. Confirmation such as
multiple suspicious papers (e.g., Fujii, Boldt) should be sought.
Authors or journal editors should be contacted before any public
allegations of research fraud. Journals do not have the authority,
resources, or responsibility for investigating fraud. Journal editors
should refer allegations of fraud to the institution under whose
authority the research was conducted. Institutions are responsible for
ethical conduct of research.**

## What to do with a flag — Steve's recommendations

*These are my recommendations, based on fifteen years of handling such
cases as a journal editor. They are not a consensus guideline, and
nothing here binds anyone. For formal guidance, see the
[COPE flowcharts](https://publicationethics.org/guidance/flowcharts) on
suspected fabricated data, which are the reference most journals
follow. — Steve Shafer*

1. **Verify the numbers before anything else.** Extraction is
   imperfect. Check the flagged trial's values against the printed
   table — especially any cell the app colored green (derived or
   AI-read) or cyan (read by OCR). A flag built on a misread digit is
   not a finding.
2. **A single flagged paper is not evidence of misconduct.** One paper
   at P ≤ 0.05 is expected once in twenty honest papers. What made the
   Fujii and Boldt cases conclusive was the *pattern* across many
   papers by the same author.
3. **Consider the innocent explanations first**, because they are more
   common than fraud: non-random allocation that was never described as
   random, quasi-randomization, a mislabeled SEM, a transcription
   error, or a table copied between manuscripts.
4. **Contact the author before anything public.** Ask for the primary
   data and the randomization method. Most cases resolve here.
5. **If concern survives that exchange, refer it to the institution**
   under whose authority the research was done. Journals do not have
   the authority, the resources, or the responsibility to investigate
   research fraud; institutions do.
6. **Keep the analysis out of public claims.** A p value from this tool
   is a screening signal that justified a question — never a
   conclusion, and never something to publish about a named
   investigator.

## What this screen does not catch

Stated plainly, because the method is public and an honest account
serves editors better than an implied guarantee.

The Carlisle–Shafer approach detects baseline data that are **too
similar across arms** to be random samples of one population. It is
effective against fabrication as it is usually committed: people
inventing numbers by hand produce distributions that are too tidy.
Human intuition about randomness is poor — a fabricator will avoid
writing 187737 because three sevens "look non-random," when in truth
one in ten digit pairs should repeat.

It follows that a **sufficiently sophisticated fabricator would not be
caught**: someone who simulates a trial from plausible distributions —
the very thing this program does to build its null — produces baseline
data that this screen cannot distinguish from honest data. Nor does it
help that the method is open: the mechanics are published in the
Carlisle papers and the source is on GitHub, so a determined person can
also use this tool to check whether their fabricated table passes.

That is an honest limitation, not a reason to keep the method secret.
Screening raises the cost and the risk of fabrication; it does not make
fabrication impossible. It is one instrument among several — structural
checks such as GRIM/GRIMMER, statistical review, and above all the
primary data — and it should be used as a reason to look more closely,
never as a verdict on its own.

## How many simulations? (adaptive replicates)

Every row starts with 1,000 replicates. Rows that look unremarkable stop
there; rows running alarming (mid-p < 0.01) escalate to 10,000, and if
still alarming to 100,000. This spends computation where it matters —
boring rows finish fast, alarming rows get precise p values.

With a finite number of replicates, the smallest honestly reportable p
is bounded. A row's p is displayed as **"<0.0001"** only when the upper
95% confidence bound on the p value itself clears 1 in 10,000 —
otherwise the display shows the estimate with its bound. Rows with
p < 0.001 carry an explicit upper bound in the results ("≤ …"), so you
always know how much Monte Carlo noise is in a small p.

## Combining rows into a trial p

The row p values of a trial are combined with Stouffer's Z method [5] —
the same method used in the 2015 and 2017 papers. The combined value is
*not* floored at the single-row resolution: ten rows each at p = 0.02
legitimately combine to a far smaller number. When the trial p is below
0.001, it is reported with a **95% Monte Carlo interval** — the
uncertainty in the trial p arising from the finite simulation counts of
its rows — so a headline number like 3 × 10⁻⁶ is never presented as more
precise than the simulation supports.

## Categorical variables

Category tables are simulated by drawing random tables with the same
margins (row and column totals) as the reported one, and asking how
often the simulated table is at least as homogeneous (chi-square
statistic at least as small) as reported — the same one-sided, mid-p
convention as the continuous rows. Degenerate tables (an arm with no
counts, an empty category) are refused with an explanation rather than
analyzed.

## Statistical details

- Reported SDs are corrected for small-sample bias before simulation
  (the standard deviation of a sample underestimates the population
  value; the correction is the standard Γ-function factor [3]).
- Simulated observations are rounded to `ROUND OBSERVATION` decimals and
  simulated means to `ROUND MEAN` decimals, so the simulation reproduces
  the granularity of the printed table — including printed means that
  tie exactly.
- Median/IQR rows are simulated from a three-term metalog distribution
  fitted to (Q1, median, Q3); the simulated sample's quartiles are
  rounded like the printed ones.
- Very large trials are protected against memory exhaustion by chunking
  the simulation matrices; results are identical, only the batch size
  changes.

# Results and downloads

While the analysis runs, each trial's name and p value are written to
the log as it completes. (The user interface is otherwise occupied
during a long run — live progress display is a known limitation on the
roadmap.)

**Download Results** — one workbook, three worksheets. Together they
answer three different questions: what happened line by line, what the
app believed the data were, and what to report. Ticking **Graph
results** before downloading adds a PowerPoint of actual-vs-expected
distribution graphs, and the download becomes a zip holding both files
(described after the worksheets below).

*Sheet 1, `Test Results`* — the audit trail: every line the analysis
touched, in the order it ran, with a **Summary** row closing each trial
and a blank row between trials.

| Column | Meaning |
|---|---|
| `TRIAL` | the trial identifier, as it appeared in the grid. Blank on the Summary row, which prints beneath its own trial's rows |
| `ROW` | the variable identifier for that line, or `Summary` |
| `P (one-sided toward homogeneity)` | the mid-p described above — small means *more homogeneous than chance*. On the Summary row this is the Stouffer-combined trial p |
| `95% Monte Carlo bound` | how precisely the simulation pinned that number: an upper bound on a row p too small to resolve, and on the Summary row a bootstrap interval for the trial p when it fell below 0.001. Blank when the estimate needs no caveat |
| `Replicates` | how many simulations that row actually received (1,000 / 10,000 / 100,000 — the adaptive scheme stops as soon as the p is resolved, so most rows show 1,000) |

*Sheet 2, `Baseline Tables`* — the reconstruction, one block per trial
stacked down the sheet under a bold `Trial: <name>` heading: variables
as rows, arms as columns, exactly as a journal prints Table 1.

- Column headers carry each arm's N (`Arm 1 (n = 15)`); a line whose own
  N differs — dropouts, missing data — says so in its own cell
  (`; n = 14`).
- A mean/SD variable prints as `mean (SD)`; a median/IQR variable prints
  as `median [Q1, Q3]`; the row label says which.
- A categorical variable becomes a heading line (`Sex, n`) with one
  indented line per category, carrying the counts.
- Every number is formatted at the **printed precision the analysis
  assumed** (the rounding columns), so this sheet is the direct
  comparison against the manuscript page: if it disagrees with the page,
  so did the analysis.

*Sheet 3, `Summary`* — one line per study: the trial name, its combined
`P (one-sided toward homogeneity)`, and the `95% Monte Carlo interval`
where one was reported. When the analysis holds **two or more trials**,
a closing bold row gives the **overall P for the entire analysis** — the
same Stouffer (sum-of-z) combination the app applies within each trial,
now applied across the trial P values. This is the step Carlisle took to
reach a single p for the whole body of Fujii's work
([PMID 22404311](https://pubmed.ncbi.nlm.nih.gov/22404311/)): each trial
may look only mildly improbable, but improbability *accumulates*, and
the overall P is where a pattern across an author's trials becomes
visible. Trials whose P could not be computed (`No values`) are left
out, and the row's label says how many combined. This is the sheet to
keep when screening many manuscripts — the per-line detail stays in
sheet 1 for the ones worth a second look.

**Graph results — the PowerPoint of distributions.** Tick the box next
to Download Results (before or after the analysis — it only changes
what the download builds) and the download delivers a zip: the workbook
above plus `Integrity Analysis Graphs.pptx`. The deck shows the
analysis the way Carlisle's 2012 Fujii paper did
([PMID 22404311](https://pubmed.ncbi.nlm.nih.gov/22404311/)) — you see
the data hugging the mean more tightly than chance allows, instead of
taking a p-value's word for it:

- **All trials** (when there are two or more): the observed cumulative
  distribution of the trial p-values against the diagonal expected
  under honest sampling, annotated with the overall Stouffer P.
- **One slide per trial**: the same picture within the trial, over its
  baseline variables.
- **One slide per suspicious variable** (p ≤ 0.01): the expected
  distribution of the squared-error statistic — the Monte Carlo draws
  the analysis generated anyway — with a red line where the observed
  value landed. A graphical p-value: the exhibit to put in front of an
  author about a specific variable. Only flagged variables get slides,
  so the deck ends with the evidence rather than burying it.

Every graph is inserted as native, editable PowerPoint drawing objects
— axes, bars, and labels can be restyled in PowerPoint for a
presentation or a report figure.

**Download Table** — the current grid as a spreadsheet. This is a valid
input file: for a partially extracted PDF it is the round trip (fill the
gaps in Excel, re-upload), and for hand-typed data it is the checkpoint,
since nothing is retained between sessions.

**Download Baseline Table (journal view)** — a reconstruction of the
baseline table as a journal would print it: variables as rows, arms as
columns, cells as "mean (SD)", "median [Q1, Q3]", or category counts,
one worksheet per trial. Every value is formatted at the printed
precision the analysis assumed, and column headers carry each arm's N.
This is the artifact to lay beside the manuscript's Table 1: it shows
exactly what IntegrityAnalysis believed the baseline data were. If the
reconstruction disagrees with the page, so did the analysis — fix the
grid and rerun.

# Validation

The engine has been validated at two levels.

**Against Carlisle 2017.** John Carlisle generously provided the
spreadsheet of continuous baseline variables behind his 5,087-trial
analysis [6]. Run through this engine, the stored and recomputed trial p
values agree with r = 0.991 across 5,080 trials (mid-p convention,
one-sided). The engine is the 2017 method, faster and with the
refinements described above.

**End to end, from PDF to verdict.** Sixty-one published articles whose
baseline tables parse fully and whose extracted values match Carlisle's
hand-entered data were run through the complete pipeline — PDF upload,
extraction, validation, analysis — and compared with Carlisle's stored
trial p values on the log scale: r = 0.94, median disagreement a factor
of 1.05, and 97% agreement on which trials alarm at p < 0.05.

# The API (for editorial systems and publishers)

Everything the app does interactively is also callable as a REST
service, so an editorial system (Editorial Manager and kin) can screen
a submission automatically and silently during peer review. The
service is the same engine, the same deterministic-first policy, and
the same privacy contract as the app.

**Endpoints.** `GET /health` reports the service identity (open, for
monitoring). `POST /parse` accepts one document — article PDF, Word
manuscript, picture of a table, or spreadsheet (JATS XML is read by the
app but not yet by the service) — and returns the extracted baseline
table.
`POST /analyze` goes on to validate and run the Monte Carlo, returning
a per-trial results CSV and the overall Stouffer P.

**Authentication.** Every data endpoint requires a bearer token issued
by the service operator; a request without one is refused before any
handler runs, and a service with no tokens configured refuses
everything (fail closed).

**A failed parse is a round trip, not a dead end.** Failure responses
(HTTP 422) carry `templateCsv` — the partial table in the app's input
layout, with what is wrong spelled out. Fix the flagged cells and POST
that CSV straight back to `/analyze`: the failure payload is, by
construction, valid input to the next call.

**Nothing is retained by the service.** Each upload lives in a working
directory created for that request and deleted when the request ends,
success or failure; every response says `"deleted": true`, because the
contract requires confirming it. As in the app, the one exception is a
request that carries an `X-Anthropic-Key` header: that content goes to
Anthropic under the caller's own account, and their retention terms
apply to it.

**The AI assist, per request.** Sending an `X-Anthropic-Key` header
engages the AI assist for that request only, under the caller's own
key — the same consent-and-billing model as the app's key field, with
the same guarantees (the key is never stored or logged, and Anthropic's
commercial terms bar training on API submissions).

## Trials too large to analyze

IntegrityAnalysis won't analyze trials with N > 5,000 in any arm, for
two reasons.

The Monte Carlo simulation for a trial with more than 5,000 subjects in
an arm is computationally expensive. Every replicate draws N values per
arm, so the work grows with the trial.

Also, trials with more than 5,000 subjects in an arm are almost
certainly funded by large companies or government entities, which
typically institute detailed auditing and review of manuscripts before
submission. An independent fraud screen adds little to a manuscript
that has already had that scrutiny.

Investigators interested in evaluating such trials — and who have
adequate computing horsepower — can directly implement `P_Calc.R` to
perform the Monte Carlo analysis:
<https://github.com/StevenLShafer/IntegrityAnalysis/blob/main/R/P_Calc.R>

The limit applies wherever IntegrityAnalysis runs: the web app flags the
offending arm and declines to analyze, and the REST service refuses the
submission. Both read one number, so neither can drift from this page.

**Size limits, and why they are where they are.** The service refuses a
submission rather than analyzing it slowly or coarsely. Two ceilings
matter in practice:

- **5,000 subjects per arm** — the same ceiling the web app applies,
  described under "Trials too large to analyze" above. It is a property
  of IntegrityAnalysis, not of this service.
- **A simulation budget.** Ordinary baseline tables are nowhere near
  it — a 30-variable trial with 1,000 subjects per arm passes
  comfortably, and costs a few seconds — but a table engineered so that
  every row demands the maximum 100,000 replicates is refused before any
  simulation starts.

  Stated precisely, because an earlier version of this page understated
  it tenfold: the budget admits up to about **twenty minutes** of
  worst-case computation, not two. A typical trial that fits inside it
  finishes in seconds; the worst case arises only when *every* row looks
  homogeneous enough to demand full precision. That is an uncomfortable
  property — the more suspicious the data, the longer the analysis takes
  — and it is why the service is better suited to submit-and-poll than
  to a single blocking request.

If a refused submission holds several trials, send them one per
request. If it is a single very large trial, splitting it would change
the result — its rows combine into one p-value — so use the web app,
which has no request timeout. **The precision of the analysis is never
reduced to fit a limit.** A p-value quietly computed from fewer
replicates than the reader assumes would be worse than a refusal, in a
tool whose output is used to question whether someone's data are real.

A publisher's developer can try it in one line once the operator
supplies a token:

```
curl -X POST https://<service-host>/analyze \
  -H "Authorization: Bearer <token>" \
  -F "file=@manuscript.pdf"
```

Public hosting is being stood up; publishers interested in running the
service inside their own infrastructure can do so from the open
source — `IntegrityAnalysis::runApiService()` starts it, and the
endpoint definitions are `inst/api/plumber.R` in the repository.

# Notes and roadmap

- **Screening, then scrutiny.** The method flags improbable homogeneity.
  Editors should treat a flag as reason to look — at correlated
  variables, stratification, SE/SD confusion, and the original data —
  not as proof of misconduct.
- **Tests that were tried and dropped.** Earlier versions computed
  Benford's-law and repeated-digit statistics; validated against the
  5,087-trial data set, neither carried useful signal at baseline-table
  scale, and they were removed.
- **Planned.** Granularity checks (GRIM/SPRITE-style flags for
  impossible means of integer data) and a benchmark of Bayesian
  alternatives are on the issues list, as is live progress feedback
  during long runs, and a REST API so manuscript-handling systems
  (Editorial Manager, ScholarOne) can submit tables directly.
- Questions, feedback, and bug reports to Steve Shafer at
  <steven.shafer@stanford.edu>.

# About the software

The method is Carlisle and Shafer's; the original application was
written entirely by Steve Shafer (2025). Since mid-August 2026,
essentially all of the code — the PDF, Word, and spreadsheet parsers,
the OCR and AI-assist tiers, the REST API, the test suite (over a
thousand assertions), and this guide — has been written by **Claude**,
Anthropic's AI assistant (Claude Code; models Claude Opus 5 and Claude
Fable 5), working under Steve's direction. The division of labor:
Steve sets the goals, reviews the behavior, and tests every change
against real manuscripts; Claude writes the code, the tests, and the
documentation. Every source file in the repository carries a
provenance header recording who wrote it, when, and what verified
it — the same auditability this app demands of the trials it screens.
Credit where due, in both directions.

# References

1. Carlisle JB. The analysis of 168 randomised controlled trials to test
   data integrity. *Anaesthesia*. 2012;67:521–537.
   <https://doi.org/10.1111/j.1365-2044.2012.07128.x>
2. Retraction Watch leaderboard.
   <https://retractionwatch.com/the-retraction-watch-leaderboard/>
3. Unbiased estimation of standard deviation.
   <https://en.wikipedia.org/wiki/Unbiased_estimation_of_standard_deviation>
4. Carlisle JB, Dexter F, Pandit JJ, Shafer SL, Yentis SM. Calculating
   the probability of random sampling for continuous variables in
   submitted or published randomised controlled trials. *Anaesthesia*.
   2015;70:848–858. <https://doi.org/10.1111/anae.13126>
5. Stouffer SA, Suchman EA, DeVinney LC, Star SA, Williams RMJ. *The
   American Soldier, vol 1: Adjustment During Army Life.* Princeton
   University Press, 1949.
6. Carlisle JB. Data fabrication and other reasons for non-random
   sampling in 5087 randomised, controlled trials in anaesthetic and
   general medical journals. *Anaesthesia*. 2017;72:944–952.
   <https://doi.org/10.1111/anae.13938>
7. Brown NJL, Heathers JAJ. The GRIM test: a simple technique detects
   multiple anomalies in reporting of results in psychology. *Social
   Psychological and Personality Science*. 2017;8:363–369.
