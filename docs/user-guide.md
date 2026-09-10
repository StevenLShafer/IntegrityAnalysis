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
nothing leaves it unless you supply an AI key.** The uploaded file,
whatever its kind and however it arrived, any data typed into the
table, and the analysis results are all purged when the session
closes. No record of the analysis is kept here.
Manuscripts under review are confidential, and the app is built around
that: uploaded files are deleted from disk when the session ends,
downloads are generated straight into your browser, and nothing is
logged. Extraction is deterministic — the same document always yields
the same table (the Monte Carlo itself draws afresh each run unless you
set a seed; see *Reproducing a result exactly*) — and the whole analysis
runs offline: no document content is ever sent to any third-party
service, with one
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
only 4% of the time would they be this close (the app's simulation, which also models the rounding, puts it at about 0.044). Seen once, that is no big
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
[3] and did not affect Carlisle's conclusions. This app does not treat
the reported SD as the known population value at all: each simulated
trial draws its own population SD from the uncertainty the reported SDs
carry (see [statistics.md](statistics.md), "The population SD"). The
more significant problem is
**rounding**. Suppose both groups report a mean weight of 77. The
difference between the groups is 0, and under normal statistical theory
a difference of exactly 0 between two random samples is impossible — the
p value degenerates. In the real world it happens all the time, because
published data are rounded.

The way out is to leave the closed-form, unrounded normal-theory p
behind and instead **replicate the study by Monte Carlo simulation**,
rounding the simulated data exactly as the published table was rounded.
(The simulation still draws normally distributed observations; what it
stops doing is comparing rounded numbers with a formula written for
unrounded ones.) John Carlisle and Steve Shafer spent
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
(Excel `.xlsx` or `.csv`) uploads directly. The column layout is
described in *Preparing your data* below — but few users should ever
need to build one by hand: upload the article itself, or use the
journal-style route next, and note that the app's own table downloads
are all valid input files.

**A journal-style baseline table.** A spreadsheet laid out the way
journals print Table 1 — variables as rows, arms as columns with their
sizes in the headers ("Control (n = 50)"), cells like "45.3 (12.1)" —
uploads directly; the app recognizes the layout and converts it into
template rows itself. **Excel `.xlsx` and plain `.csv` both work here**
— so a table pasted out of a manuscript into a CSV is as good an input
as a workbook. The old Excel format, `.xls`, is not accepted; save the
workbook as `.xlsx`. The app's own **Editor's View** download is
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
dpi. A screenshot is smaller than that (96 dpi, with letters about ten
pixels tall, which OCR largely drops), so a picture whose type is that
small is enlarged before it is read — its pixels replicated two to four
times, with no smoothing, until the letters are the size of a printed
page's — which recovers nearly all of the words; even so, check the cyan
values with particular care. A png or jpg is decoded by the app's own
readers (the png and jpeg packages), a tif by the OCR engine itself,
never by ImageMagick, and every picture's declared dimensions are
checked from the file header before any decoder runs — an oversized or
malformed image is refused with a message, and the enlarged picture is
held to the same pixel ceiling. (GIF is deliberately not accepted: its header cannot bound
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
csv/xlsx/pdf/docx/xml/jpg/png/tif are skipped with a note (an `.xls`
with the note that the format is not accepted), an
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
verify. Fed a single article PDF, it yields a fully analyzable table
about 85% of the time on curated journal PDFs (measured on the Carlisle
corpus), less often on raw submissions; and roughly half of those
tables reproduce Carlisle's hand-entered values in every cell, the rest
needing a correction or two in the grid. For the rest, an optional **AI assist**
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
  win.** The assist only fills gaps, and every AI-read line paints its
  ROW cell **green** in the grid with a note to verify it against the
  manuscript; the message log names the variables the assist read.
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
  cell to see the reader's reason (for example, "median [range] - the
  analysis needs quartiles (Q1/Q3), not the range").
- **Blue — incongruent.** The value conflicts with the type of its row:
  an SD on a median/IQR row, continuous entries on a category row, a
  median outside its own quartiles, an SE standing in for a missing SD.
- **Green — derived or AI-read.** The parser computed the value (a
  percentage converted to a count, or an arm N recovered from the
  document), or the AI assist read the line off the page (its ROW cell
  is green). Usable as it stands, but check it against the manuscript
  before it runs; hover the cell to see how it was derived.
- **Orange — fail-safe count.** The page printed only a percentage, and
  for this arm size several counts fit it (above 100 patients at integer
  percentages, above 1,000 at one decimal). The app then reads the page in the way most
  favourable to the authors. Every whole table the printed percentages
  allow is built — each cell inside the bracket its percentage permits,
  and each arm's counts adding up to that arm's N — and the readings at
  each extreme are scored with the same statistic and the same null the
  analysis itself uses. Only those can win: the p is larger the less
  alike the arms are, so the best case is among the readings that leave
  the arms least alike and the worst among those that leave them most
  alike. A middling reading is neither.
  The one **analysed is the one with the largest p**: the authors get
  every benefit of the doubt the page allows. Hover the cell for the
  bracket of counts the percentage allows and for the best and worst p
  the page could have produced.

  When the best and the worst reading fall on opposite sides of
  p = 0.01, the row says so, because then the printed counts decide the
  answer and the percentages do not. Ask the authors for the counts
  before acting on such a trial.

  **When the page allows more readings than can be counted, the app
  does not guess.** The largest-p promise can only be kept over readings
  the app has actually listed, so where there are too many to list the
  cells are left
  **blank**, the row is named, and it is not analysed. The summary line
  says how many of the trial's rows were analysed, so the gap is
  visible. Type the printed counts in and the row analyses normally.
  This is uncommon — one manuscript in 558 of our reference collection
  triggers the fill at all — and it happens on the largest tables,
  where a reconstruction would deserve the least trust.

  The app also does **not** assume that a variable's categories divide
  the arm between them. Percentages adding to about 100 is arithmetic,
  not a statement about what the categories mean, and a table can print
  a partial list. So a rebuilt row may total slightly more or less than
  the arm's N, and when it does the cell's note says so. If you can see
  from the page that the categories are exhaustive, the printed counts
  settle it. This is a
  design decision for incomplete data, not a reading of the page; the
  printed counts, if you can get them from the author, settle it. The
  checkbox above the upload turns the fill off, in which case such rows
  are left out of the analysis.
- **Pale cyan — read by OCR.** The whole table came from a scanned page,
  or an uploaded picture of a table, read by optical character
  recognition. OCR can misread digits (3 vs
  8, 1 vs 7), and in a fraud screen a single silently wrong digit
  matters — verify every value against the manuscript, or enter an
  Anthropic API key and re-upload for the higher-accuracy AI read.

A table with no colors and no legend validated cleanly. The **Analyze**
button appears whenever validation did not fail — so a table can still
carry colors when it is ready to run: green and pale cyan are cautions,
never failures, and yellow on a row with a label but no data is a soft
warning (the row is simply left out). Red, blue, and yellow on a
required cell of a row with data mean the table did not validate; fix
them and revalidate.

# Preparing your data

Most users never need this section: the app parses PDFs, Word
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
| `ROW`  | what is measured — "Weight", "Age", "Duration of symptoms" |
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
decimal places of the values themselves: `ROUND MEAN` becomes the most
decimal places any of the variable's means shows, and `ROUND OBSERVATION`
follows it. A cell holding **text** is read for its digits before it is
converted, so "1.20" typed or pasted as text counts as two decimals; a
cell holding a **number** cannot be, because a spreadsheet stores 1.20 as
1.2 and the trailing zero is already gone by the time the app opens the
file. A comma-separated file is read the same way, so it keeps its digits
too, and a number written in scientific notation is counted at the
precision it really shows: "5.0e1" is 50 to the nearest unit, not to
three decimals. A precision you supply yourself is never overwritten,
including one coarser than the value's own digits - a mean of 50 declared
to the nearest ten stays that way. That is why the variable's maximum is used across its arms, and why
the app writes its own spreadsheets with the numbers as text (below). That second
inference is a guess — a mean printed to one decimal is often computed
from integer measurements — so when you know the raw precision, say so
in the column. An optional `ROUND DISPERSION`
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

A study reporting the duration of symptoms before enrolment as median
[Q1, Q3] in two arms (a baseline variable: measured before allocation,
so randomization is what makes the arms comparable — an outcome such as
the duration of surgery is not one):

| ROW | MEAN | N | Q1 | Q3 | ROUND MEAN |
|---|---|---|---|---|---|
| Duration of symptoms | 127 | 50 | 98  | 160 | 0 |
| Duration of symptoms | 133 | 50 | 101 | 155 | 0 |

`ROUND MEAN` is the printed precision of the median, exactly as for a
mean; `ROUND DISPERSION` is the quartiles' printed precision, inferred
from their decimals when left blank (a table often prints the quartiles
coarser than the median). The median must lie between its quartiles at
their printed precisions: integer quartiles of 5 and 6 beside a median
of 4.99 are accepted, since 5 stands for anything from 4.5 to 5.5. N,
the median, and both quartiles are required. The simulation for such rows draws from a
distribution fitted to the three quartile values (a metalog
distribution — a flexible distribution specified directly by its
quantiles), so no normality assumption is imposed. Each replicate
re-draws that distribution twice over, so a small trial's noisy
quartiles are not taken as exact: first the printed quartiles
themselves are drawn within half a printed unit of what the table
shows, then the resulting population's scale is drawn from the
quartiles' own sampling uncertainty. Because the printed quartiles are
read as intervals, a variable whose quartiles print as the same number
— an integer-printed measurement whose interquartile range is under
one unit — is analyzed rather than refused, and the Note column says
which arms printed that way. Only quartiles printed in the wrong order
(Q3 below Q1) are refused. Quartiles more lopsided than a three-term
metalog can represent are fitted at its limit, and the Note column says
so too.

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

**The long layout: one line per level.** A table with many categories
gets wide in that form, and wide is hard to edit. The
same variables may be entered one line per category level per arm, with
the level named in a `LEVEL` column and its count in `N`:

| ROW | LEVEL | N | MEAN | SD |
|---|---|---|---|---|
| Sex | Male | 40 | | |
| Sex | Male | 34 | | |
| Sex | Female | 10 | | |
| Sex | Female | 16 | | |
| Surgery | Upper | 7 | | |
| Surgery | Upper | 7 | | |
| Surgery | Lower | 8 | | |
| Surgery | Lower | 15 | | |
| Surgery | Urologic | 35 | | |
| Surgery | Urologic | 28 | | |
| Weight | | 15 | 63 | 13 |
| Weight | | 17 | 68 | 12 |

The arms are the lines that share a `ROW` and a `LEVEL`, in file order,
exactly as the lines sharing a `ROW` are the arms of a continuous
variable; so you may list all of one arm's levels together or all arms
of one level together. `MEAN` and `SD` stay blank on a level line, and
`LEVEL` stays blank on a continuous line. Both layouts are accepted in
one file, and a file in either is converted on upload to the wide form,
which is what the grid shows and the downloads carry; nothing that reads
the wide layout changes. A level named like a base column ("N") is
prefixed with its variable's name in the grid. A binary variable still
needs both of its levels ("Male" and "Not male"), because a level line
does not carry the arm's total.

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

For each variable, the app simulates the trial many times. Each
simulated trial draws its own population SD, from the spread the pooled
variance and its degrees of freedom allow, and its own common location,
a normal draw about the pooled mean; then for every arm, N subjects are
drawn from a normal distribution with that location and SD; each
simulated observation is rounded like the raw data; each simulated mean
is rounded like the printed mean; and the sum of squared deviations of
the arm means from their N-weighted grand mean is computed. (For a
large arm — at least 100 patients, with an SD of at least three steps
of the observation grid — the arm mean is drawn directly rather than
observation by observation; the result is the same to Monte Carlo
precision, and much faster. See [statistics.md](statistics.md), "The
direct draw for large arms".) The **p value is the fraction of
simulations at least as homogeneous as the reported data** (a mid-p:
ties count half). Small p means the printed means are closer together
than random sampling can readily explain — the Fujii signature. The p
is deliberately one-sided: the app reports the proximity p and never
doubles it.

A small p value is a **screening signal, not a verdict**. Innocent
explanations include stratified or blocked allocation, correlated
variables, mislabeled SEMs, and transcription errors — Carlisle's 2017
paper [6] discusses them at length. A trial flagged here deserves
scrutiny of the original data, not summary judgment.

**CAVEAT: Chance alone will produce P ≤ 0.05 in about 1 in 20 honest
papers, and P ≤ 0.01 in about 1 in 100** (about, because the
combination treats the variables as independent, and a table that
reports weight and BMI, or a measurement and its categorised version,
repeats some of its evidence; see [statistics.md](statistics.md)).
**Research fraud should never be alleged by
a single manuscript flagged by IntegrityAnalysis. Confirmation such as
multiple suspicious papers (e.g., Fujii, Boldt) should be sought.
Authors or journal editors should be contacted before any public
allegations of research fraud. Journals do not have the authority,
resources, or responsibility for investigating fraud. Journal editors
should refer allegations of fraud to the institution under whose
authority the research was conducted. Institutions are responsible for
ethical conduct of research.**

## Rounding, large trials, and rows that cannot alarm

A row's p can be unremarkable for a reason that has nothing to do with
the data being honest or dishonest: the printed precision may be too
coarse for the row to say anything at all. It is worth understanding
this, because large trials show it on every integer-reported row.

Under honest randomization the arms are samples of one population, so
their means are estimates of the same number, and as the arms grow the
estimates converge on it. The spread between two arm means shrinks like
1/√N. At 1,000 patients per arm with an SD of 13 years, the standard
error of an arm's mean age is 0.4 years. Reported to the nearest year,
the two arms will print the *same* integer about half the time — not
because anyone copied a number, but because both estimates landed
within the same year of the truth, as convergence requires. Identical
rounded means in a large trial are the expected outcome.

The simulation knows this. It rounds its simulated arms exactly as the
paper rounded its own, so its honest replicates tie on the same integer
just as often as honest data does, and a row whose arms both report
"55" gets a p near 0.27: the mid-point of a tie group that holds half of
the honest distribution. That number is correct. There is no
unexplained homogeneity in the row, so none is reported. Steve's way of
putting it: *as N goes to infinity both arms converge to the population
value; if you round, they converge to exactly the same number; there is
no unexplained homogeneity in large N, because convergence is
expected.*

Three consequences follow:

- **Such a row cannot convict on its own.** A fabricator who copies one
  arm's integer mean into the other is, on that row alone,
  indistinguishable from honest convergence. No statistic can extract
  evidence the printing removed.
- **Evidence comes from accumulation and from precision.** Many rows
  that all sit at the bottom of their tie groups are collectively
  improbable even when each is individually ordinary; that is what the
  trial p measures, and why its combination step must be exact (see the
  next section). And rows printed finely enough that convergence has
  not erased the sampling scatter — two decimals, or a small N — carry
  the row-level signal a coarse row cannot.
- **A test that ignores rounding misreads convergence as fraud.** A
  t-statistic computed from tied integer means treats the tie as exact
  and reads it as under-dispersion. Rounding turns an expected agreement
  into a false alarm for that test, and into an honest "nothing to see"
  for this one.

So when a large trial's integer-reported rows all show p values near
0.2 to 0.3, read them as rows with nothing to say, not as rows that
cleared the screen, and look to the trial p, which is where their
collective evidence is added up correctly.

**The "attainable floor" note.** The results table says this for you.
Every row has a smallest p its printed precision allows — the p of the
most homogeneous outcome the simulation can produce, which is both arms
printing the same value. When a row sits at that floor — the printed
arms agree exactly *and* no honest replicate agreed better — its Note
column reads **attainable floor**. (A row whose arms differ, however
slightly, never carries the note, even when no replicate happened to
beat it; its interval says so instead.) For integer age at 1,000 per arm the floor is about
0.27, and the note means the row cannot alarm and should not be read as
reassurance either. For a row printed to two decimals the floor is
small, and a row at it alarms; the note then means this is as far as
the row can go. The floor depends on the printing and the sample size,
never on the data.

The combination step (next section) removes the same assumption one
level up: the summed evidence of a trial's rows is judged against its
own simulated distribution, not a formula that assumes each row's p is
continuous.

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
2. **A single flagged paper is not sufficient evidence of misconduct.** One paper
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

There is a second limitation, narrower and just as concrete. The screen
compares the arms' **locations** — their means, or their medians —
against the spread the table reports. The reported spreads themselves
enter only as one pooled number saying how far apart honest locations
should fall; whether the arms' standard deviations agree with each other
is never a quantity this screen tests. **Numbers invented in the
dispersion column alone are therefore invisible to it.** An independent
audit demonstrated it on a two-arm table of 100 patients: changing the
standard deviations from 10 and 10 to 0 and 14.14 — one arm with no
variation whatsoever — leaves the p-value unchanged at 0.8365, because
the pooled variance is the same. Barnett's dispersion test, which the
package also implements, is the instrument that looks at that column;
the two are reported side by side rather than combined, since two
readings of one table are not two pieces of evidence.

That is an honest limitation, not a reason to keep the method secret.
Screening raises the cost and the risk of fabrication; it does not make
fabrication impossible. It is one instrument among several — structural
checks such as GRIM/GRIMMER [7], statistical review, and above all the
primary data — and it should be used as a reason to look more closely,
never as a verdict on its own.

## How many simulations? (adaptive replicates)

Every trial starts with 1,000 replicates per row. A trial whose p, and
every row's, is 0.1 or more stops there; one below 0.1 escalates to
10,000, and one still below 0.01 to 100,000. This spends computation
where it matters — unremarkable trials finish fast, borderline ones get
a p with a Monte Carlo standard error of about 0.002 instead of 0.007, alarming ones get the
precision a small p needs.

**Reproducing a result exactly.** An unseeded Monte Carlo is not meant
to give identical numbers from run to run: two runs of the same table
differ within the reported Monte Carlo interval. To get identical
numbers, set a seed by adding `?seed=12345` (any whole number from 1 to
2,147,483,647) to the page's address before pressing Analyze; the log
confirms it and the results workbook's Summary sheet records it. The
same table, the same seed and the same build then give the same numbers
anywhere. Record the build with the seed (the Provenance sheet carries it),
because a change to the simulation changes what a seed produces. A
local copy can be started with a seed for every analysis:
`IntegrityAnalysis::run_app(seed = 12345)`.

With a finite number of replicates, the smallest honestly reportable p
is bounded. No p is ever reported as zero: a row where no replicate
matched is floored at 1 divided by (replicates + 1). A p is displayed as
**"<0.0001"** only when the one-sided 97.5% Clopper–Pearson upper bound
(the exact binomial confidence bound) on the count of replicates at or
below the observed statistic clears 1 in 10,000; otherwise the estimate
itself is shown. The P column carries the estimate alone; every row's
exact 95% Monte Carlo interval sits in its own column ("0.27 to 0.33"
for an unremarkable row at 1,000 replicates), so you always know how
much simulation noise is in a p. The interval is about the simulation,
not the data: it says how precisely the replicates pinned that row's p.
The same floor and the same "<0.0001" rule apply to the trial p (next
section).

## Combining rows into a trial p

The row p values of a trial are combined by the **exact combination**:
the rows' evidence is summed as Stouffer's z-scores [5] (each row's p
converted to a standard normal deviate and the deviates added), as in
the 2015 and 2017 papers, but the sum is judged against its own simulated
distribution rather than the normal table. Every simulated replicate of
every row is scored the way the observed row is, the scores are summed
across rows replicate by replicate, and the trial p is the share of
those simulated honest trials that agree at least as well as the
printed one. Ten rows each at p = 0.02 — none alarming on its own —
combine to about 4 × 10⁻¹¹ by the closed form (eight rows at p = 0.05
to about 1.6 × 10⁻⁶). The trial p is floored and displayed by the same
rules as a row's (see *How many simulations?* above): floored at 1
divided by (replicates + 1), shown as "<0.0001" only when its upper
bound licenses it, and — when it falls below 0.001 — carrying an exact
**95% Monte Carlo interval** ("0 to 3.7e-05" at 100,000 replicates)
rather than a number the simulation could not resolve.

The rows are treated as independent: two variables that carry the same
information (weight and BMI, a measurement and its categorised version)
repeat their evidence and make the trial p smaller than it should be,
so look for duplicated or derived variables before reading a trial p.
`docs/statistics.md` describes the combination as it runs today; how it
differs from the closed-form combination of the 2015 and 2017 papers,
and why it changed, is in `docs/method-history.md`.

## Categorical variables

Category tables are simulated by drawing random tables with the same
margins (row and column totals) as the reported one, and asking how
often the simulated table is at least as homogeneous (chi-square
statistic at least as small) as reported — the same one-sided, mid-p
convention as the continuous rows. Degenerate tables (an arm with no
counts, an empty category) are refused with an explanation rather than
analyzed.

When a row is refused, for any reason, the Summary line for that trial
says how many of its rows were analysed, so a combined p-value is never
read as covering a table it did not cover. A row the validator leaves
out before the engine sees it counts too — a label with no values in
any cell (a percentage block the parser could not reconstruct arrives
that way), or a categorical line with no partner arm — and appears in
the results as "Not analysed" with the reason in its Note.

A row is refused when a precision column contradicts the numbers beside
it. Each of the three says what grid something sits on — the mean's, the
dispersion's, and the grid the individual measurements were recorded on —
and the analysis reads those grids as the intervals the printed values
stand for, so each has to be a grid its own numbers could have been
rounded to. A mean of 58.9 over forty patients cannot have come from
measurements recorded to the nearest hundred — averaging forty multiples
of 100 can only land on a multiple of 2.5 — and the analysis says so
rather than believing it. How much room there is depends on the arm size,
since the mean of N measurements on a grid moves in steps of that grid
divided by N; a median moves in whole steps, or half-steps for an even
number of patients. The reported spread is checked against the same grid
from the other side: measurements a step apart cannot produce a standard
deviation smaller than the step times the distance from the mean to the
nearest multiple of it, nor smaller than the step divided by the square
root of the number of patients, unless every measurement was identical - a mean
of 500 from measurements recorded to the nearest thousand forces a
standard deviation of at least 500, whatever the table prints. That check
runs only when a table says its measurements were recorded more coarsely
than it prints their average; when the two agree, which is what the app
assumes if you leave the observation precision blank, nothing is
refused. A precision **coarser** than the printed value is not refused either: a
paper printing "50" may honestly have rounded to tens. But it widens the
rounding the arms are judged against, which can take a row from an alarm
to unremarkable, so the Note beside that row's p says the answer rests on
the claim. A precision finer than the printed
value is not refused — a spreadsheet cell holding a number drops trailing
zeros, so a mean printed "50.000000" and one printed "50" reach the app as
the same number — but it is disclosed: such a row is analysed as the table claims, and the
Note beside its p says the answer depends on that claim, because a finer
precision quietly removes the rounding that decides whether two arms
printing the same number is remarkable.
Quartiles of 40 and 60 reported to the nearest ten are fine; quartiles of
45 and 55 said to be printed to the nearest ten are not, and neither is
any value paired with a far coarser claim. This matters more than it
sounds: the interval multiplies the width of the comparison the analysis
makes, so one mistyped cell could otherwise turn an unremarkable row into
an apparent finding.

A row is also refused when its printed precision asks for more accuracy
than the computer's arithmetic can carry: a value near a hundred billion
printed to twenty decimals wants more than the fifteen or so significant
digits a double-precision number holds, and the simulation would quietly
round on the machine's own grid instead of the printed one. The results
table says so in place of a p-value. Real tables are nowhere near this
limit; the check exists so that a number too big and too precise cannot
produce a confident-looking answer.

## Statistical details

- The arms' reported SDs are pooled into one population variance,
  weighting each arm's variance by its degrees of freedom (N − 1), with
  N minus the number of arms degrees of freedom in all. The simulation
  does not then treat that pooled SD as known: each simulated trial
  draws its own population SD from the spread of values the pooled
  variance and its degrees of freedom allow (the scaled inverse
  chi-square), so a small trial's uncertainty about its own SD is part
  of the null. This is the difference between a z test and a t test,
  and it matters below about ten patients per arm; above that the
  draws are so tight that nothing changes.
- Simulated observations are rounded to `ROUND OBSERVATION` decimals and
  simulated means to `ROUND MEAN` decimals, so the simulation reproduces
  the granularity of the printed table — including printed means that
  tie exactly.
- Median/IQR rows are simulated from a three-term metalog distribution
  fitted to (Q1, median, Q3), refitted for every replicate from
  quartiles drawn within their printed intervals and then given a scale
  drawn from the quartiles' own sampling uncertainty (the median/IQR
  analogue of the per-replicate SD draw): N observations per arm are
  drawn from it and rounded to the observation precision, and each
  arm's sample median is rounded like the printed median. The quartiles shape the
  distribution the observations come from; no simulated quartiles are
  computed. Median rows always draw their observations (no direct draw).
- Very large trials are protected against memory exhaustion by chunking
  the simulation matrices; results are identical, only the batch size
  changes.

# Results and downloads

While the analysis runs, each trial's name and p value are written to
the log as it completes, and the progress bar advances trial by trial,
naming the trial just finished and its p.

**Download Results** — one workbook, four worksheets. Together they
answer four different questions: what happened line by line, what the
app believed the data were, what to report, and what ran. Ticking **Graph
results** before downloading adds a PowerPoint of actual-vs-expected
distribution graphs, and the download becomes a zip holding both files
(described after the worksheets below).

*Sheet 1, `Test Results`* — the audit trail: every line the analysis
touched, in the order it ran, with a **Summary** row closing each trial
and a blank row between trials.

| Column | Meaning |
|---|---|
| `TRIAL` | the trial identifier, as it appeared in the grid. Printed on a trial's first line only and blank on every line after it, including the Summary row, which prints beneath its own trial's rows |
| `ROW` | the variable identifier for that line, or `Summary` |
| `P (one-sided toward homogeneity)` | the mid-p described above — small means *more homogeneous than chance*. On the Summary row this is the exact-combination trial p |
| `95% Monte Carlo interval` | how precisely the simulation pinned that number: the exact Clopper–Pearson 95% interval of the row p on every row the app analysed (a refused row leaves this blank, and its Replicates cell too), and on the Summary row the interval for the trial p when it fell below 0.001. Because the adaptive scheme decides when to stop by looking at the p itself, coverage is about 93.5% rather than 95% for a true p near an escalation threshold, and nominal away from them (see [statistics.md](statistics.md)) |
| `Replicates` | how many simulations the rows received (1,000 / 10,000 / 100,000 — the adaptive scheme stops as soon as the trial and every row are resolved, so an unremarkable trial shows 1,000 on every row, and an alarming one escalates every row together) |
| `Note` | the Summary line's count of analysed rows when any row was refused, and on a variable's line any of: `quartiles beyond the metalog's skew limit; fitted at the limit`, `printed quartiles do not separate in k arm(s); the fit uses their printed intervals`, `the stated mean precision (k decimals) exceeds the digits these values carry ...`, its mirror `the stated mean precision (k decimals) is coarser than the digits these values carry ...`, and `attainable floor` when the row sits at the smallest p its printed precision allows — no honest replicate agreed better than the printed arms (see "Rounding, large trials, and rows that cannot alarm"). Blank otherwise |

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
a closing bold row gives the **overall P for the entire analysis** — a
closed-form Stouffer (sum-of-z) combination of the trial P values
against the normal table. That is a different procedure from the
within-trial combination, which is judged against its own simulated
null: across trials the P values are treated as continuous and
independent, and a trial reported as "<0.0001" enters as 0.0001, on the
conservative side. This is the step Carlisle took to
reach a single p for the whole body of Fujii's work
([PMID 22404311](https://pubmed.ncbi.nlm.nih.gov/22404311/)): each trial
may look only mildly improbable, but improbability *accumulates*, and
the overall P is where a pattern across an author's trials becomes
visible. Trials whose P could not be computed (`No values`) are left
out, and the row's label says how many combined. This is the sheet to
keep when screening many manuscripts — the per-line detail stays in
sheet 1 for the ones worth a second look.

*Sheet 4, `Provenance`* — what ran: the date and time, the package
version and the engine commit, the R version, a one-line statement of
the method, and how to reproduce the analysis. Reproduction needs three
things: the same engine commit (which pins the code and, through
`renv.lock`, every package version), the same table, and the same seed
— the Summary sheet records the seed when one was set (see "Reproducing
a result exactly"). Without a seed the rerun draws afresh and lands
within the Monte Carlo interval, not on the same number.

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

The mean, SD, SE and quartile columns are written as **text**, formatted
at the precision that row was analysed at — a mean of 50.0 is written
"50.0", not 50. A spreadsheet cannot hold a trailing zero in a number, so
writing them as numbers would have thrown away the precision the analysis
used, and re-uploading the file would have analysed the same table on a
coarser grid. Excel shows text numbers left-aligned with a green corner
and offers "Convert to Number"; converting a block of them is a few
keystrokes, and it is only needed to do arithmetic in the sheet — the app
itself reads them either way, and reads the digits before converting. `N`,
the category counts and the rounding columns stay as numbers: they are
whole numbers, so there is no precision in them to lose.

**Download Baseline Table (journal view)** — the reconstruction of the
baseline table as a journal would print it, one worksheet per trial:
the same content as the results workbook's `Baseline Tables` sheet
(described above), as a file of its own. This is the artifact to lay
beside the manuscript's Table 1: it shows
exactly what IntegrityAnalysis believed the baseline data were. If the
reconstruction disagrees with the page, so did the analysis — fix the
grid and rerun.

# Validation

The engine has been validated at two levels.

**Against Carlisle 2017.** John Carlisle generously provided the
spreadsheet of continuous baseline variables behind his 5,087-trial
analysis [6]. Run through the current engine (the most recent row of
[the validation ledger](validation-ledger.md), which records every such
measurement), the stored and recomputed trial p values agree with
r = 0.993 across 5,041 usable trials (mid-p convention, one-sided), and
the two agree on whether a trial alarms at p < 0.05 for 98.5% of
trials. The engine is the 2017 method, faster and with the refinements
described above.

**End to end, from PDF to verdict.** The complete pipeline — PDF
upload, extraction, validation, analysis — is exercised against the
Carlisle corpus of published articles: the deterministic reader yields
an analyzable table from about 85% of curated journal PDFs, and the
recomputed trial p values are compared with Carlisle's stored ones
(see *The AI assist* above for what the reader recovers and where it
needs help).

# Trials too large to analyze

IntegrityAnalysis won't analyze trials with N > 5,000 in any arm — on
a categorical line, the arm's category counts added together — for two
reasons.

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
offending arm (the N cell, or the category counts whose total exceeds
the ceiling) and declines to analyze, and the REST service refuses the
submission. Both read one number, so neither can drift from this page.

# The API (for editorial systems and publishers)

Everything the app does interactively is also callable as a REST
service, so an editorial system (Editorial Manager and kin) can screen
a submission automatically and silently during peer review. The
service is the same engine, the same deterministic-first policy, and
the same privacy contract as the app.

**Endpoints.** `GET /health` reports the service identity (open, for
monitoring). `POST /parse` accepts one document — article PDF, Word
manuscript, JATS XML article, picture of a table, or spreadsheet — and
returns the extracted baseline table. JATS XML is the route intended
for editorial systems, which hold the manuscript as XML before any PDF
exists and whose tables are real cells rather than page geometry.
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

## Size limits, and why they are where they are

The service refuses a submission rather than analyzing it slowly or
coarsely. Two ceilings matter in practice:

- **5,000 subjects per arm** (counting a categorical line's counts
  together) — the same ceiling the web app applies, described under
  "Trials too large to analyze" above. It is a property of
  IntegrityAnalysis, not of this service.
- **A simulation budget.** Ordinary baseline tables are nowhere near
  it — a 30-variable trial with 1,000 subjects per arm passes
  comfortably, and costs a few seconds — but a table engineered so that
  every row demands the maximum 100,000 replicates is refused before any
  simulation starts. The budget admits up to about **twenty minutes** of
  worst-case computation. A typical trial that fits inside it finishes
  in seconds; the worst case arises only when *every* row looks
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

Publishers can run the service inside their own infrastructure from the
open source — `IntegrityAnalysis::runApiService()` starts it, and the
endpoint definitions are `inst/api/plumber.R` in the repository.

# Notes and roadmap

- **Screening, then scrutiny.** The method flags improbable homogeneity.
  Editors should treat a flag as reason to look — at correlated
  variables, stratification, SE/SD confusion, and the original data —
  not as proof of misconduct.
- **Planned.** Granularity checks (GRIM/SPRITE-style flags for
  impossible means of integer data) and a benchmark of Bayesian
  alternatives are on the issues list.
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
