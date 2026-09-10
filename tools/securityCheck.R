# securityCheck.R - static security tripwire, run by the GitHub Actions
# checks before anything deploys.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-08-20,
# from the full-repository security review Steve requested. The review's
# conclusions live in AGENTS.md ("Security"); this script mechanises the
# handful of properties that a one-line diff could silently break. It is
# a TRIPWIRE, not a substitute for reviewing new code: it catches the
# known-dangerous patterns recurring, nothing more.
#
# THE PROPERTIES IT PINS (each verified by hand in the review):
#  1. Nothing in R/ evaluates constructed code or shells out, except the
#     one reviewed subprocess launcher (parseBaselineTableFiles.R, which
#     shQuote()s every argument and runs Rscript --vanilla).
#  2. The comments log stays HTML-escaped at its single entry point
#     (outputComments.R) - it is rendered with HTML(), and file names
#     from uploads flow into it.
#  3. No workflow uses pull_request_target, which would hand repository
#     secrets (the shinyapps tokens) to code from forked PRs.
#  4. No credential material is committed.
#
# Usage:  Rscript tools/securityCheck.R     (exit 0 = pass, 1 = fail)

fail <- character(0)
note <- function(msg) fail <<- c(fail, msg)

rFiles <- list.files("R", pattern = "[.]R$", full.names = TRUE)
srcOf <- function(f) readLines(f, warn = FALSE)

## 1 - code execution primitives -----------------------------------------
# system2 is allowed ONLY in the reviewed subprocess launcher; everything
# else on this list is banned outright in R/ (corpus/ and tools/ are
# local tooling, reviewed but not deployed - the app is what ships).
banned <- c("\\bsystem\\s*\\(",
            "\\bshell\\s*\\(",
            "\\bshell.exec\\s*\\(",
            "\\beval\\s*\\(",
            "\\bparse\\s*\\(\\s*text",
            "\\bsource\\s*\\(",
            "\\bReduce\\s*\\(\\s*get\\b",
            # XML parser options that switch off libxml2's own defences
            # (issue 29). NOENT and DTDLOAD enable external entities -
            # XXE, which reads local files or forwards requests. HUGE
            # lifts the entity-expansion cap, which is what makes a
            # billion-laughs bomb work. libxml2 is safe by DEFAULT; the
            # entire risk is someone adding one of these to get past a
            # "document too large" complaint, so it is banned in R/
            # rather than left to review.
            "[\"']HUGE[\"']",
            "[\"']NOENT[\"']",
            "[\"']DTDLOAD[\"']",
            # ...and the three the 2026-09-03 screen of PR #162 measured
            # to be as dangerous: DTDVALID reads an external entity into
            # the document exactly as NOENT does, DTDATTR fetches the
            # external DTD (a server-side request to an author-chosen
            # URL), XINCLUDE is banned on principle. DTDVALID is the one
            # a publisher's DTD reference tempts someone to add.
            "[\"']DTDVALID[\"']",
            "[\"']DTDATTR[\"']",
            "[\"']XINCLUDE[\"']")
for (f in rFiles) {
  src <- srcOf(f)
  code <- sub("#.*$", "", src)          # comments may NAME the patterns
  for (pat in banned) {
    hit <- grep(pat, code)
    if (length(hit))
      note(sprintf("%s:%d: banned pattern %s", f, hit[1], pat))
  }
  hit <- grep("\\bsystem2\\s*\\(", code)
  # Two reviewed launchers, each with its own pinned properties below:
  # parseBaselineTableFiles.R (Rscript per file) and, since 2026-09-02,
  # parseTatr.R's .ppTatrRun() (the pegged Python over one PDF). Review
  # of the second, recorded here as AGENTS.md requires: the interpreter
  # comes from INTEGRITY_TATR_PYTHON or a fixed home path, never from a
  # request; the script path likewise; every argument is shQuote()d and
  # every path is one this process created in tempdir(); the model runs
  # offline (no --allow-download); its output is a file read as XML data;
  # and the call carries an OS timeout. It is absent wherever the Python
  # is (shinyapps.io), so the app's deployed surface is unchanged.
  if (length(hit) && !basename(f) %in% c("parseBaselineTableFiles.R", "parseTatr.R"))
    note(sprintf("%s:%d: system2() outside the reviewed launchers", f, hit[1]))
  # ...and in parseTatr.R the exemption is for .ppTatrRun() ALONE: a
  # system2() anywhere else in that file is a new launcher (CodeRabbit
  # on #147).
  if (length(hit) && basename(f) == "parseTatr.R") {
    fnStart <- grep("^\\.ppTatrRun\\s*<-\\s*function", code)
    fnEnd <- if (length(fnStart)) {
      nxt <- grep("^[A-Za-z.][A-Za-z0-9._]*\\s*<-\\s*function", code)
      nxt <- nxt[nxt > fnStart[1]]
      if (length(nxt)) nxt[1] - 1L else length(code)
    } else 0L
    stray <- hit[!(length(fnStart) > 0 & hit >= fnStart[1] & hit <= fnEnd)]
    if (length(stray))
      note(sprintf("%s:%d: system2() in R/parseTatr.R outside .ppTatrRun() - a new, unreviewed launcher",
                   f, stray[1]))
  }
}
if (file.exists("R/parseTatr.R")) {
  tr  <- sub("#.*$", "", srcOf("R/parseTatr.R"))
  run <- grep("^\\.ppTatrRun\\s*<-\\s*function", tr)
  body <- if (length(run)) tr[run[1]:min(run[1] + 40, length(tr))] else character(0)
  if (!any(grepl("timeout\\s*=\\s*timeout", body)))
    note("R/parseTatr.R: .ppTatrRun() lost its OS timeout on the Python subprocess")
  if (any(grepl("--allow-download", body, fixed = TRUE)))
    note("R/parseTatr.R: .ppTatrRun() would let the model fetch weights at inference (offline by design)")
  if (!any(grepl("shQuote\\(sc\\)", body)) || !any(grepl("shQuote\\(lst\\)", body)))
    note("R/parseTatr.R: .ppTatrRun() passes a path to the shell unquoted")
  if (any(grepl("stdout\\s*=\\s*TRUE", body)))
    note("R/parseTatr.R: .ppTatrRun() captures the model's stdout - its output is the XML file, read as data")
  # the 2026-09-02 screen's findings, each pinned (F1, F2, F3, F5)
  if (!any(grepl("--max-mem-mb", body, fixed = TRUE)))
    note("R/parseTatr.R: .ppTatrRun() no longer caps the model process's memory (--max-mem-mb; screen F1)")
  if (!any(grepl("INTEGRITY_PARSE_BUDGET", body, fixed = TRUE)))
    note("R/parseTatr.R: .ppTatrRun() ignores the parse child's budget (INTEGRITY_PARSE_BUDGET; screen F3)")
  if (!any(grepl("file.copy(pdfFile, pdf)", body, fixed = TRUE)))
    note("R/parseTatr.R: .ppTatrRun() passes the uploader's own file name to the model (screen F5)")
  disc <- grep("^\\.ppTatr(Python|Script)\\s*<-\\s*function", tr)
  dbody <- if (length(disc)) tr[min(disc):min(max(disc) + 12, length(tr))] else character(0)
  if (any(grepl("tatrenv|path\\.expand|getwd\\(", dbody)))
    note("R/parseTatr.R: the model is discovered from the home directory or cwd, not configuration (screen F2)")
  pf <- sub("#.*$", "", srcOf("R/parseBaselineTableFiles.R"))
  if (!any(grepl("TMPDIR = childTmp", pf, fixed = TRUE)) || !any(grepl("unlink(childTmp", pf, fixed = TRUE)))
    note("R/parseBaselineTableFiles.R: the parent no longer owns and removes the child's tempdir (screen F4)")
  ut <- sub("#.*$", "", srcOf("R/utils.R"))
  # Since 2026-09-06 (repeat outside screen, F3) the page-size cap lives in
  # ONE gate, .ppRenderablePages(), which every rasteriser must call: local
  # OCR in utils.R and the AI route's .ppPageImagesB64() in aiFallback.R.
  gp <- grep("^\\.ppRenderablePages\\s*<-\\s*function", ut)
  gbody <- if (length(gp)) ut[gp[1]:min(gp[1] + 12, length(ut))] else character(0)
  if (!any(grepl("pdf_pagesize", gbody, fixed = TRUE)) || !any(grepl("\\.ppRasterMaxPixels", gbody)))
    note("R/utils.R: .ppRenderablePages() does not apply the page-size cap (screen F1 / repeat F3)")
  op <- grep("^\\.ppOcrPages\\s*<-\\s*function", ut)
  obody <- if (length(op)) ut[op[1]:min(op[1] + 40, length(ut))] else character(0)
  if (!any(grepl("\\.ppRenderablePages\\(", obody)))
    note("R/utils.R: .ppOcrPages() rasterises pages without .ppRenderablePages() (screen F1)")
  if (file.exists("R/aiFallback.R")) {
    af <- sub("#.*$", "", srcOf("R/aiFallback.R"))
    ap <- grep("^\\.ppPageImagesB64\\s*<-\\s*function", af)
    abody <- if (length(ap)) af[ap[1]:min(ap[1] + 12, length(af))] else character(0)
    if (!any(grepl("\\.ppRenderablePages\\(", abody)))
      note("R/aiFallback.R: .ppPageImagesB64() rasterises pages without .ppRenderablePages() (repeat screen F3)")
  }
}

## 1b - the JATS reader parses bytes it has bounded ------------------------
# Screen of PR #162 (2026-09-03): libxml2's FILE reader inflates a gzip
# stream transparently, so a 389 KB upload named .xml became 400 MB of
# XML and a 15 GB parse child; a single colspan="100000000" made a
# 1.5 GB matrix. Pinned: the reader has exactly one read_xml() call, on
# BYTES with NOBLANKS alone; the bytes are read only after .ppJatsOK()
# has judged size and gzip magic; and both cell parsers clamp spans.
if (file.exists("R/parseJats.R")) {
  js <- sub("#.*$", "", srcOf("R/parseJats.R"))
  calls <- grep("read_xml\\s*\\(", js)
  if (length(calls) != 1L ||
      !grepl("read_xml\\(bytes,\\s*options\\s*=\\s*\"NOBLANKS\"\\)", js[calls[1]]))
    note(paste("R/parseJats.R: the JATS reader must call read_xml() exactly once,",
               "on bytes, with options = \"NOBLANKS\" alone - a path argument lets",
               "libxml2 inflate a gzip named .xml (screen of PR #162)"))
  if (sum(grepl("options\\s*=", js)) != 1L)
    note("R/parseJats.R: a second parser options= appeared - review it against the screen of PR #162")
  # inside .ppJatsRead() itself (the gate function reads two magic bytes
  # of its own, which is the point of it)
  rd <- grep("^\\.ppJatsRead\\s*<-\\s*function", js)
  nxt <- grep("^[A-Za-z.][A-Za-z0-9._]*\\s*<-\\s*function", js); nxt <- nxt[nxt > rd[1]]
  body <- if (length(rd)) js[rd[1]:(if (length(nxt)) nxt[1] - 1L else length(js))] else character(0)
  ok <- grep("\\.ppJatsOK\\s*\\(", body); rb <- grep("readBin\\s*\\(", body)
  if (!length(body) || !length(ok) || !length(rb) || min(ok) > min(rb))
    note("R/parseJats.R: .ppJatsRead() reads the bytes before .ppJatsOK() has bounded the file")
  if (!any(grepl("min\\(cs,\\s*\\.ppMaxCellSpan\\)", js)))
    note("R/parseJats.R: colspan is no longer clamped to .ppMaxCellSpan (screen F2)")
  # second screen of #162: only OUTERMOST paragraphs and rows are
  # selected, else nesting multiplies the text by the depth. The nested
  # tests in test-parse-jats.R carry the property; this grep only says
  # the guards are still present.
  if (sum(grepl("not\\(ancestor::p\\)", js)) < 3L ||
      !any(grepl("not\\(ancestor::td\\)", js)))
    note("R/parseJats.R: an XPath lost its outermost-node guard (not(ancestor::p) / not(ancestor::td)) - nested elements multiply the text")
  # the budget must be APPLIED, incrementally - the loop stops when it is
  # spent (a scratch break that kept the constant and dropped its use
  # passed the first version of this pin)
  if (!any(grepl("if\\s*\\(spent\\s*>\\s*\\.ppJatsMaxTextChars\\)\\s*break", js)))
    note("R/parseJats.R: the text-vector budget (.ppJatsMaxTextChars) is no longer applied as the paragraphs are read")
  # third screen of #162: every .//title in an XPath carries the
  # outermost-title guard, and the gate refuses a declared entity
  tl <- grep("title", js); tl <- tl[grepl("//\\*\\[|\\.//title|self::title", js[tl])]
  if (length(tl) && !all(grepl("not\\(ancestor::title\\)", js[tl])))
    note("R/parseJats.R: a caption XPath selects <title> without not(ancestor::title) - nested titles multiply the caption")
  # the CALL, not the phrase (the refusal message names <!ENTITY too, and
  # a scratch break that kept the message passed the first version)
  if (!any(grepl("grepRaw\\(\"<!ENTITY\"", js)))
    note("R/parseJats.R: .ppJatsOK() no longer refuses a declared internal entity (<!ENTITY)")
  # fourth screen of #162: the entity search sees ASCII only, so a NUL
  # anywhere is refused (UTF-16 hid the keyword) and the first byte is
  # "<"; and counts, not time, bound the work - cells per table, cells
  # per document, body paragraphs - each APPLIED, not merely defined
  if (!any(grepl("any\\(bytes == as\\.raw\\(0L\\)\\)", js)))
    note("R/parseJats.R: .ppJatsOK() no longer refuses NUL bytes - a UTF-16 file hides <!ENTITY from the byte search")
  if (!any(grepl("first != as\\.raw\\(0x3c\\)", js)))
    note("R/parseJats.R: .ppJatsOK() no longer requires the first byte to be \"<\"")
  if (!any(grepl("nCells > \\.ppMaxTableCells", js)))
    note("R/parseJats.R: the per-table cell count (.ppMaxTableCells) is no longer applied before the matrix is built")
  if (!any(grepl("spentCells > \\.ppMaxDocCells", js)))
    note("R/parseJats.R: the document cell budget (.ppMaxDocCells) is no longer applied across table-wraps")
  if (!any(grepl("length\\(body\\) > \\.ppMaxBodyParas", js)))
    note("R/parseJats.R: the body paragraph cap (.ppMaxBodyParas) is no longer applied")
  # the adapter runs lazily, inside the candidate loop, for tried tables
  # only: its one call must come after the loop opens
  ad <- grep("\\.ppDocxLines\\(", js); lp <- grep("for \\(i in seq_along\\(cand\\)\\)", js)
  if (length(ad) != 1L || !length(lp) || ad[1] < lp[1])
    note("R/parseJats.R: .ppDocxLines() runs for every table before ranking - it must run once, inside the candidate loop")
}
if (file.exists("R/parseDocx.R")) {
  dx <- sub("#.*$", "", srcOf("R/parseDocx.R"))
  if (!any(grepl("\\.ppClip\\(txt,\\s*\\.ppMaxCellChars\\)", dx)))
    note("R/parseDocx.R: .ppDocxTextLine() no longer clips a cell to .ppMaxCellChars")
}
if (file.exists("R/parseDocx.R")) {
  dx <- sub("#.*$", "", srcOf("R/parseDocx.R"))
  if (!any(grepl("pmin\\(span,\\s*\\.ppMaxCellSpan\\)", dx)))
    note("R/parseDocx.R: gridSpan is no longer clamped to .ppMaxCellSpan (screen F2)")
}

## 2 - the comments log stays escaped ------------------------------------
oc <- srcOf("R/outputComments.R")
if (!any(grepl("\\.escapeHtml\\(text\\)", oc)) ||
    !any(grepl("\\.escapeHtml\\(line\\)", oc)))
  note(paste("R/outputComments.R no longer escapes messages -",
             "the log renders as HTML and carries uploaded file names"))

## 3 - workflow triggers --------------------------------------------------
for (wf in list.files(".github/workflows", pattern = "[.]ya?ml$",
                      full.names = TRUE)) {
  if (any(grepl("pull_request_target", srcOf(wf))))
    note(paste0(wf, ": pull_request_target exposes deploy secrets to forks"))
  # A workflow_run job inherits the secrets and fires on the triggering
  # run's HEAD branch, so a `branches: [main]` filter alone also matches a
  # fork's pull request from a branch named main; the deploy job must
  # require a push from this repository (screen 2026-09-06-1749, F2)
  # comments stripped first: a commented-out copy of the condition must
  # not satisfy the check (screen 2026-09-07-0702, I2 - the failure mode
  # AGENTS.md records for an earlier pin)
  src <- sub("#.*$", "", srcOf(wf))
  if (any(grepl("^\\s*workflow_run:", src)) &&
      !any(grepl("workflow_run\\.event\\s*==\\s*'push'", src) &
           grepl("head_repository\\.full_name\\s*==\\s*github\\.repository", src)))
    note(paste0(wf, ": a workflow_run job does not require event == 'push' from",
                " this repository - a fork PR from a branch named main could",
                " trigger the privileged deploy"))
}

# The precision columns are read as INTERVALS, and an interval is a direct
# multiplier on the null's spread: a grid the printed value cannot sit on
# turns an honest row into an accusation (screens 2026-09-07-1758 F1 and
# -1907 F1/F2, both rated high). P_Calc's gate must test all three columns
# and the degenerate all-zero row; comments are stripped first, so a
# commented-out call does not satisfy the check.
pc <- sub("#.*$", "", srcOf("R/P_Calc.R"))
for (fn in c("\\.iaOnStatedGrid\\s*\\(", "\\.iaObservationGridOK\\s*\\(",
             "\\.iaZeroRowGridOK\\s*\\(", "\\.iaSdReachesGrid\\s*\\("))
  # the pattern matches CALLS only ("name(" ), never the definition
  # ("name <- function"), so one match is the gate still calling it
  if (!any(grepl(fn, pc)))
    note(paste("R/P_Calc.R: the printed-precision gate no longer calls",
               gsub("\\\\s\\*\\\\\\(|\\\\", "", fn),
               "- a stated grid the values do not sit on would widen the",
               "null without saying so"))

# Both producers of unusable table lines must cap what they hand the grid:
# the cap was extracted into .iaCapSkipped() so the two call sites could
# share it, and one of them did not (screen 2026-09-07-2000, F3). A zip may
# carry 300 files, so a per-file cap is the only thing between one upload
# and a grid of tens of thousands of rows.
# each producer named separately: counting calls would accept two in one
# block and none in the other (CodeRabbit on PR #221). The wide branch
# caps its whole FILE with .iaCapSkippedFile(), since one sheet may hold
# thousands of "Trial:" blocks and a per-block cap bounds nothing
# (screen 2026-09-07-2101, F4 - which also predicted that this pin would
# trip on the correct fix, as it did).
as_ <- sub("#.*$", "", srcOf("R/app_server.R"))
if (!any(grepl(".iaCapSkippedFile(", as_, fixed = TRUE)) ||
    !any(grepl("r$skipped <- .iaCapSkipped(", as_, fixed = TRUE)))
  note(paste("R/app_server.R: one of the two skipped-line producers no longer",
             "caps what it adds to the grid - a zip of many files would build",
             "an unbounded grid and an unbounded skip registry"))

## 4 - committed credentials ----------------------------------------------
# Tracked text files only; the corpus xlsx and PDFs are gitignored.
tracked <- system2("git", c("ls-files"), stdout = TRUE)
tracked <- tracked[grepl("[.](R|r|yaml|yml|md|Rmd|html|css|json|txt|csv)$",
                         tracked)]
secretPat <- c("sk-ant-[A-Za-z0-9-]{10,}",
               "ANTHROPIC_API_KEY\\s*[=:]\\s*[A-Za-z0-9_-]{12,}",
               "SHINY_(TOKEN|SECRET)\\s*[=:]\\s*[A-Za-z0-9_-]{12,}")
for (f in setdiff(tracked, "tools/securityCheck.R")) {
  if (!file.exists(f)) next
  src <- srcOf(f)
  for (pat in secretPat) {
    hit <- grep(pat, src)
    if (length(hit))
      note(sprintf("%s:%d: looks like a committed credential (%s)",
                   f, hit[1], pat))
  }
}

## 5 - the API surface ----------------------------------------------------
# Added 2026-08-26 after the API security review. Each assertion pins a
# fix whose removal would silently reopen a finding; the review's
# reasoning is in AGENTS.md "The API surface".
if (file.exists("R/apiService.R")) {
  api <- srcOf("R/apiService.R")
  plum <- if (file.exists("inst/api/plumber.R"))
    srcOf("inst/api/plumber.R") else character(0)

  # Checked STRUCTURALLY, by reading each function's body: a line-by-line
  # grep false-positived on "as.data.frame" the first time it ran, which
  # is exactly the brittleness the re-review predicted.
  fnBody <- function(src, name) {
    i <- grep(paste0("^", name, "\\s*<-\\s*function"), src)
    if (!length(i)) return(character(0))
    depth <- 0; out <- character(0)
    for (j in i[1]:length(src)) {
      out <- c(out, src[j])
      depth <- depth + lengths(regmatches(src[j], gregexpr("\\{", src[j]))) -
                       lengths(regmatches(src[j], gregexpr("\\}", src[j])))
      if (j > i[1] && depth <= 0) break
    }
    out
  }

  # H1: a request-size ceiling exists and runs as a filter
  if (!any(grepl("\\.apiMaxBytes", plum)) ||
      !any(grepl("@filter sizelimit", plum, fixed = TRUE)))
    note(paste("inst/api/plumber.R lost its request-size filter -",
               "an unbounded upload is buffered in memory (review H1)"))

  # H2: /analyze refuses an oversized table before simulating
  if (!any(grepl("\\.apiMaxRows", api)) ||
      !any(grepl("\\.apiMaxTrials", api)) ||
      !any(grepl("too_large", api, fixed = TRUE)))
    note(paste("R/apiService.R lost the /analyze size gate - a crafted",
               "table can pin the single-threaded service (review H2)"))

  # F4: the four size limits are checked independently while the Monte
  # Carlo cost is their PRODUCT. Measured: one row at the permitted
  # maximum (N = 100,000, 100,000 replicates) costs 199 seconds, and
  # the gate maxima come to ~12 days of compute in a single request.
  # Reachable deliberately - escalation fires on homogeneous rows, which
  # the submitter controls. The independent gates LOOK sufficient, which
  # is exactly why this needs pinning: someone tidying "redundant"
  # checks would remove the one that is not.
  #
  # PIN THE ASSIGNMENT AND THE CALL SITE, not the mere appearance of the
  # names. The first version of this assertion searched for
  # "\\.apiMaxDrawBudget" anywhere on a non-comment line, and PASSED a
  # deliberate break: the constant is also interpolated into the refusal
  # MESSAGE, so commenting out its definition and hard-coding
  # drawWork <- 0 left the grep perfectly happy. That is the second time
  # an assertion here matched something other than what it meant to pin
  # (the first matched a commented-out line). The lesson is not "write
  # better greps" - it is that an assertion nobody has WATCHED FAIL is
  # not evidence, so every one of these gets broken on purpose once.
  if (!any(grepl("^[^#]*\\.apiMaxDrawBudget\\s*<-", api)) ||
      !any(grepl("^[^#]*\\.apiDrawWork\\s*<-\\s*function", api)))
    note(paste("R/apiService.R lost the compute-product gate's",
               "definitions - rows, trials, N and columns can each pass",
               "while the simulation they ask for runs for days (F4)"))
  # ...and the gate must still be CONSULTED: a live call to .apiDrawWork
  # compared against the budget, inside the analyze path.
  anz <- fnBody(api, "\\.apiAnalyze")
  if (length(anz) &&
      (!any(grepl("^[^#]*<-\\s*\\.apiDrawWork\\s*\\(", anz)) ||
       !any(grepl("^[^#]*>\\s*\\.apiMaxDrawBudget", anz))))
    note(paste("R/apiService.R: .apiAnalyze no longer compares",
               ".apiDrawWork() against .apiMaxDrawBudget - the",
               "compute-product gate is defined but not enforced (F4)"))

  # H3: spreadsheets get a decompression-bomb preflight
  if (!any(grepl("\\.apiZipInflationOK", api)))
    note(paste("R/apiService.R lost the zip-inflation preflight -",
               "an xlsx bomb is read in-process (review H3)"))

  # M5: CSV output is formula-sanitized on every emit path
  if (!any(grepl("\\.apiCsvSafe", api)))
    note(paste("R/apiService.R lost .apiCsvSafe - returned CSVs can",
               "smuggle spreadsheet formulas to the editor (review M5)"))
  # The HUMAN-facing results CSV must be sanitized; the MACHINE-facing
  # templateCsv must NOT be (sanitizing it renames variables and breaks
  # issue 1's round-trip contract - caught in re-review 2026-08-26).
  tmpl <- fnBody(api, "\\.apiTemplateCsv")
  res5 <- fnBody(api, "\\.apiResultsCsv")
  if (length(res5) && !any(grepl("\\.apiCsvSafe", res5)))
    note(paste("R/apiService.R: .apiResultsCsv no longer sanitizes -",
               "the editor-facing CSV can smuggle formulas (review M5)"))
  # The journal-style tables (issue 15, returned by /analyze) are a
  # THIRD human-facing CSV surface, carrying manuscript-derived ROW
  # LABELS. The generic "is .apiCsvSafe used anywhere in this file"
  # check would still pass if this one call site lost it, so pin the
  # call site itself.
  #
  # CORRECTED (F3, 2026-08-27): this comment used to justify the
  # assertion by saying the COLUMN HEADERS are arm names parsed from
  # the manuscript. They are not. buildBaselineTables
  # (baselineTable.R:127) names columns POSITIONALLY - "Arm 1
  # (n = 15)", from an index and a number - so no manuscript string
  # reaches the header by that route. The assertion is kept on its true
  # rationale, the row labels. An assertion should stand on a rationale
  # that survives checking, or not at all: a false one invites the next
  # reader to verify it, find it false, and delete the guard with it.
  jline <- grep("^[^#]*buildBaselineTables", api)
  if (length(jline)) {
    win <- api[jline[1]:min(jline[1] + 8, length(api))]
    if (!any(grepl("\\.apiCsvSafe", win)))
      note(paste("R/apiService.R: the journal-style CSV is emitted",
                 "without .apiCsvSafe - its row labels come from the",
                 "manuscript and would carry formulas to the editor"))
  }
  # The journal tables expand super-linearly in the input (one line per
  # populated category column), so the /analyze INPUT gates do not bound
  # them - an output-size cap must exist or a legal table becomes a
  # multi-hundred-MB response (independent screen, 2026-08-27).
  if (!any(grepl("^[^#]*\\.apiMaxJournalCells", api)))
    note(paste("R/apiService.R lost the journal output-size bound -",
               "journalTables can be inflated into a memory DoS that",
               "tryCatch cannot catch"))

  # ...and .apiCsvSafe must sanitize NAMES, not only values: a header is
  # as executable as a cell. DEFENCE IN DEPTH - no live path is known to
  # put manuscript text in names() (see the F3 note above); the guard is
  # one apostrophe against a plausible future one.
  csvFn <- fnBody(api, "\\.apiCsvSafe")
  # ^[^#]* so a COMMENTED-OUT assignment does not satisfy the check -
  # the first version of this assertion passed on exactly that
  if (length(csvFn) && !any(grepl("^[^#]*names\\(data\\)\\s*<-", csvFn)))
    note(paste("R/apiService.R: .apiCsvSafe no longer sanitizes column",
               "names - the header row loses its formula guard"))

  if (length(tmpl) && any(grepl("^[^#]*\\.apiCsvSafe", tmpl)))
    note(paste("R/apiService.R: .apiTemplateCsv sanitizes - that renames",
               "variables and breaks the round-trip contract (issue 1)"))
  plumEmit <- grep("^[^#]*(utils::)?write\\.csv\\(", plum)
  for (i in plumEmit)
    note(sprintf(paste("inst/api/plumber.R:%d: raw write.csv - emit",
                       "through .apiResultsCsv/.apiTemplateCsv so the",
                       "sanitize policy stays in one place (M5)"), i))

  # M6: a custom error handler hides internal detail from callers
  if (!any(grepl("pr_set_error", api, fixed = TRUE)))
    note(paste("R/apiService.R lost pr_set_error - plumber's default",
               "handler returns R condition text to callers (review M6)"))
}

# M4: the AI key must never be written into the child options blob
if (file.exists("R/parseBaselineTableFiles.R")) {
  pf <- srcOf("R/parseBaselineTableFiles.R")
  if (!any(grepl("\\.ppSplitChildKey", pf)))
    note(paste("R/parseBaselineTableFiles.R lost .ppSplitChildKey - the",
               "caller's API key may be serialized to disk (review M4)"))
  if (any(grepl("args\\s*=\\s*c\\(list\\(ai\\s*=\\s*ai\\), list\\(\\.\\.\\.\\)\\)", pf)))
    note(paste("R/parseBaselineTableFiles.R writes list(...) into the",
               "options blob again - that path carries apiKey (M4)"))
}

## 6 - table images: no ImageMagick, header before decoder -----------------
# Added 2026-09-02 with image uploads (jpg/png/tif; Steve: "this creates
# a new security surface (JPG malware)"). An image decoder is a classic
# attack surface and the uploader is the author under investigation, so
# these are pinned: hostile bytes never route through ImageMagick
# (tesseract's own reader only); GIF stays out (screen F1: its header
# cannot bound the decoder); the header read is bounded; and every path
# that decodes or reads an image has refused oversized or malformed
# headers FIRST, checked inside the function that does the decoding.
#
# SYNTAX-AWARE, NOT GREP (CodeRabbit on #145, after screen F4). The
# checks read the R parser's own token table: comments are absent by
# construction, a "#" inside a string is a string, and a string is seen
# whichever quote it uses. Every assertion below was verified to trip on
# a deliberate break in a scratch copy - see the verification loop in
# the PR that added it (#145).
if (file.exists("R/utils.R")) {
  # code-only lines: every terminal token except comments, joined by
  # spaces, on the line where it starts - with the line's brace delta
  # taken from the '{' and '}' TOKENS, so a brace inside a regex string
  # (this parser is full of them) cannot end a function body early
  codeOf <- function(f) {
    pd <- utils::getParseData(parse(f, keep.source = TRUE))
    pd <- pd[pd$terminal & pd$token != "COMMENT", ]
    n <- max(pd$line1)
    txt <- character(n); delta <- integer(n)
    for (ln in unique(pd$line1)) {
      tk <- pd[pd$line1 == ln, ]
      txt[ln]   <- paste(tk$text, collapse = " ")
      delta[ln] <- sum(tk$token == "'{'") - sum(tk$token == "'}'")
    }
    structure(txt, delta = delta)
  }
  # the code lines of one top-level function, by token brace depth
  bodyOf <- function(code, name) {
    delta <- attr(code, "delta")
    i <- grep(paste0("^", gsub(".", "\\.", name, fixed = TRUE),
                     "\\s*<-\\s*function"), code)
    if (!length(i)) return(character(0))
    depth <- 0; opened <- FALSE; out <- character(0)
    for (j in i[1]:length(code)) {
      out <- c(out, code[j])
      depth <- depth + delta[j]
      if (depth > 0) opened <- TRUE
      # not before the first brace: a signature can span several lines,
      # and stopping at depth 0 there truncated the body to two lines
      if (opened && depth <= 0) break
    }
    out
  }
  imgFiles <- c("R/utils.R", "R/parseBaselineTableHeuristics.R",
                "R/parseBaselineTable.R", "R/aiFallback.R", "R/apiService.R",
                "R/app_server.R")
  # ImageMagick by any door: the package name as a token (magick::,
  # library(magick), requireNamespace("magick")) or one of its functions
  # called unqualified after an attach
  magickFns <- paste0("\\b(image_read|image_info|image_write|image_convert|",
                      "image_resize|image_scale|image_data|image_ocr)\\s*\\(")
  for (f in imgFiles[file.exists(imgFiles)]) {
    code <- codeOf(f)
    if (any(grepl("\\bmagick\\b", code)) || any(grepl(magickFns, code)))
      note(paste(f, "reaches ImageMagick (magick, or one of its functions",
                 "unqualified) - the 2026-09-02 decision was tesseract's",
                 "own reader only (review, image uploads)"))
  }
  ut <- codeOf("R/utils.R")
  if (any(grepl("[\"']gif[\"']", ut)))
    note(paste("R/utils.R accepts GIF again - the 2026-09-02 screen (F1)",
               "showed its header cannot bound the decoder's allocation"))
  # the bounded read itself, not the symbol's presence
  dims <- bodyOf(ut, ".ppImageDims")
  if (!length(dims) ||
      !any(grepl(paste0("readBin\\s*\\(\\s*con\\s*,\\s*\"raw\"\\s*,\\s*n\\s*=\\s*",
                        "min\\s*\\(\\s*size\\s*,\\s*\\.ppImageHeaderBytes\\s*\\)\\s*\\)"),
                 dims)))
    note(paste("R/utils.R: .ppImageDims() no longer reads the header through",
               "readBin(con, \"raw\", n = min(size, .ppImageHeaderBytes)) -",
               "a crafted image header is read without limit"))
  # the TIFF dimension entry is one SHORT or LONG, else the file is
  # refused - with another type or count the value field is an offset
  # (screen 2026-09-03, F1)
  if (length(dims) &&
      !any(grepl("cnt\\s*!=\\s*1\\s*\\|\\|\\s*!\\s*typ\\s*%in%\\s*c\\s*\\(\\s*3\\s*,\\s*4\\s*\\)",
                 dims)))
    note(paste("R/utils.R: .ppImageDims() no longer refuses a TIFF dimension",
               "entry whose count is not 1 or whose type is not SHORT/LONG -",
               "an offset would be read as a small width"))
  # ...and the cap reads EVERY directory, not the first alone
  # (screen 2026-09-03, F2). This is a NEGATIVE grep - a rewrite that
  # reads one directory some other way would not trip it; the property
  # itself is carried by the two-page bomb in test-image-uploads.R
  if (length(dims) && any(grepl("pages\\s*==\\s*1L", dims)))
    note(paste("R/utils.R: .ppImageDims() reads dimensions from the first",
               "TIFF directory only again - a tiny page 1 ahead of a huge",
               "page 2 passes the cap"))
  # preflight before decode, INSIDE the function that decodes
  orderIn <- function(f, fn, before, after, what) {
    if (!file.exists(f)) return(invisible())
    b <- bodyOf(codeOf(f), fn)
    if (!length(b)) { note(paste(f, "lost", fn, "- the image path moved")); return(invisible()) }
    i <- grep(before, b); j <- grep(after, b)
    if (length(j) && (!length(i) || min(i) > min(j))) note(what)
  }
  # the two decoders added with the screenshot enlargement (PR #168):
  # png::readPNG / jpeg::readJPEG are called ONLY inside .ppImageGrey(),
  # and .ppImageUpscaled() decides the factor from the header before it
  # decodes - the screen measured an 88 KB blank PNG over the cap costing
  # a gigabyte to decode for an enlargement then refused (F1)
  decAll <- grep("readPNG|readJPEG", ut)
  decIn  <- grep("readPNG|readJPEG", bodyOf(ut, ".ppImageGrey"))
  if (!length(decAll) || length(decAll) != length(decIn))
    note(paste("R/utils.R: png::readPNG / jpeg::readJPEG are called outside",
               ".ppImageGrey() (or not at all) - the decoders have one gated site"))
  # ...and .ppImageGrey() has exactly one caller, .ppImageUpscaled(), which
  # judged the cap first (second screen of PR #168, note 1)
  gCalls <- grep("\\.ppImageGrey\\s*\\(", ut)
  gDef   <- grep("^\\.ppImageGrey\\s*<-\\s*function", ut)
  gIn    <- grep("\\.ppImageGrey\\s*\\(", bodyOf(ut, ".ppImageUpscaled"))
  if (length(setdiff(gCalls, gDef)) != length(gIn))
    note(paste("R/utils.R: .ppImageGrey() is called somewhere other than",
               ".ppImageUpscaled() - the decoder has one caller, behind the cap"))
  orderIn("R/utils.R", ".ppImageUpscaled",
          "\\.ppImageDims\\s*\\(", "\\.ppImageGrey\\s*\\(",
          paste("R/utils.R: .ppImageUpscaled() decodes the picture before",
                "judging the factor from its header (.ppImageDims) - an",
                "over-cap picture is decoded for nothing (screen of PR #168, F1)"))
  # the long-layout converter counts the wide table's columns and refuses
  # BEFORE it builds anything - the build was cubic in time and quadratic
  # in memory, reached before every downstream gate (screen
  # 2026-09-06-1749, F1)
  if (!any(grepl("\\.iaMaxLevelColumns", bodyOf(codeOf("R/app_globals.R"), ".iaLongToWide"))))
    note(paste("R/app_globals.R: .iaLongToWide() no longer gates the wide",
               "table's width on .iaMaxLevelColumns (screen 1749, F1)"))
  orderIn("R/app_globals.R", ".iaLongToWide",
          "\\.iaMaxLevelColumns", "matrix\\s*\\(",
          paste("R/app_globals.R: .iaLongToWide() builds the wide table before",
                "gating its width on .iaMaxLevelColumns - a long file of",
                "all-distinct levels pins the worker for hours (screen 1749, F1)"))
  orderIn("R/parseBaselineTableHeuristics.R", "parseBaselineTableHeuristics",
          "\\.ppImageOK\\s*\\(", "\\.ppImageData\\s*\\(",
          paste("R/parseBaselineTableHeuristics.R decodes an image",
                "(.ppImageData) without .ppImageOK() first, in the function",
                "that decodes it"))
  orderIn("R/apiService.R", ".apiReadUpload",
          "\\.ppImageOK\\s*\\(", "parseBaselineTableFiles\\s*\\(",
          paste("R/apiService.R: .apiReadUpload() spawns a child for an upload",
                "without the image preflight (.ppImageOK) first"))
  orderIn("R/aiFallback.R", ".ppImageFileB64",
          "\\.ppImageOK\\s*\\(", "readBin\\s*\\(",
          paste("R/aiFallback.R: .ppImageFileB64() reads image bytes for the",
                "model without .ppImageOK() first"))
  # ...and the model's own size limits, in the same function, before the
  # bytes are read (screen 2026-09-03, N1)
  orderIn("R/aiFallback.R", ".ppImageFileB64",
          "\\.ppImageAiRefusal\\s*\\(", "readBin\\s*\\(",
          paste("R/aiFallback.R: .ppImageFileB64() reads image bytes for the",
                "model without .ppImageAiRefusal() first - a 20 MB image is",
                "encoded for Anthropic to reject"))
}

## 7 - one definition of the zero snap ------------------------------------
# Security screen 2026-09-08-0709, finding F4. The disclosure note and
# the engine each decide "the arms are equal" from a zero tolerance, and
# they were the SAME EXPRESSION WRITTEN TWICE, six lines apart, in each
# of two branches of P_Calc(). They agreed, but nothing made them agree,
# and the tolerance has already been changed three times on the record
# (screens 1441 I1, 1459 F1, and 1048 F1, which found it depended on the
# author's choice of origin). A one-line edit to either copy reopens the
# gap the commit that introduced them existed to close.
#
# The property: in CODE, not in comments, every simRow that snaps takes
# its zeroTol from the shared .iaZeroSnapTol() binding, there is exactly
# one definition of it, and the origin-dependent expression does not
# come back. The categorical branch is the one legitimate literal - a
# contingency-table statistic has no floating-point dust to snap, so it
# passes zeroTol = 0 and is allowed by name.
pcCode <- sub("#.*$", "", srcOf("R/P_Calc.R"))
zeroTolLines <- grep("zeroTol\\s*=", pcCode, value = TRUE)
badLit <- grep("zeroTol\\s*=\\s*0\\s*\\)", zeroTolLines,
               value = TRUE, invert = TRUE)
badLit <- grep("zeroTol\\s*=\\s*[0-9]", badLit, value = TRUE)
if (length(badLit))
  note(paste("R/P_Calc.R: a simRow sets zeroTol from a literal rather than",
             "the shared .iaZeroSnapTol() binding (screen 2026-09-08-0709",
             "F4) -", paste(trimws(badLit), collapse = " | ")))
snapDef <- grep("^\\s*\\.iaZeroSnapTol\\s*<-", pcCode)
if (length(snapDef) != 1L)
  note(paste("R/P_Calc.R: .iaZeroSnapTol() must be defined exactly once,",
             "found", length(snapDef)))
snapCalls <- setdiff(grep("\\.iaZeroSnapTol\\s*\\(", pcCode), snapDef)
if (length(snapCalls) != 2L)
  note(paste("R/P_Calc.R: expected exactly two callers of .iaZeroSnapTol()",
             "- the median and the continuous branch - found",
             length(snapCalls)))
if (any(grepl("1e-26\\s*\\*\\s*\\(\\s*1\\s*\\+", pcCode)))
  note(paste("R/P_Calc.R: the origin-dependent zero tolerance",
             "1e-26 * (1 + centre^2) is back in code (screen",
             "2026-09-08-1048 F1)"))

# AND THE EQUALITY THAT MATTERS IS STRUCTURAL, NOT FORGIVEN (independent
# audit 2026-09-09, F6). A replicate must be translated by ITS OWN first
# arm, so that arms which all drew the same value give a bitwise zero and
# need no tolerance at all. Translating by the OBSERVED first arm instead
# - one constant for every replicate - leaves dust the tolerance has to
# catch, and that tolerance shrinks with the printed precision, which the
# manuscript supplies: at fourteen decimals it dropped about 18% of
# genuine ties. The two spellings differ by a few characters in the
# reading and by a factor of two in the answer, so both are pinned.
for (nm in c("MCMean", "MCMed")) {
  bad <- grep(paste0(nm, "\\s*<-\\s*", nm, "\\s*-\\s*ROWS\\$MEAN\\["),
              pcCode, value = TRUE)
  if (length(bad))
    note(paste0("R/P_Calc.R: ", nm, " is translated by the OBSERVED first arm ",
                "again - equal arms in a replicate stop being exactly zero ",
                "(audit 2026-09-09 F6) - ", paste(trimws(bad), collapse = " | ")))
  ok <- grep(paste0(nm, "\\s*<-\\s*", nm, "\\s*-\\s*", nm, "\\[\\s*,\\s*1\\s*\\]"),
             pcCode)
  if (!length(ok))
    note(paste0("R/P_Calc.R: ", nm, " is no longer translated by its own first ",
                "arm; the zero snap goes back to forgiving dust instead of ",
                "never producing it (audit 2026-09-09 F6)"))
  # ...AND IT MUST HAPPEN BEFORE THE CENTRE IS TAKEN (security screen
  # 2026-09-09-1614, F1). Pinning the spelling alone left the ordering
  # free: moving the translation one statement later computes the
  # N-weighted centre from UNTRANSLATED means and then measures a
  # translated matrix against it, which is a large systematic error in
  # every row p rather than dust - and the screen verified the assertion
  # stayed silent on exactly that mutation. Same style as the
  # header-before-readBin ordering check above.
  ctr <- grep(paste0("<-\\s*drop\\(\\s*", nm, "\\s*%\\*%"), pcCode)
  if (length(ok) && length(ctr) && min(ok) > min(ctr))
    note(paste0("R/P_Calc.R: ", nm, " is translated AFTER its weighted centre ",
                "is taken, so the centre is computed from untranslated means ",
                "(screen 2026-09-09-1614 F1)"))
}

## 8 - the fail-safe fill spends simulation only on ranked candidates ----
# Security screens 2026-09-08-2100 (F1) and 2026-09-09-0721 (F1). Scoring
# every distinct null was the dominant cost of parsing: an ordinary Table
# 1 - two arms of 700, a three-level percentage block - produced 20,449
# nulls and took 190 s end to end, past the 60 s subprocess timeout, so
# the manuscript did not parse at all. The fix ranks the groups by their
# statistic and simulates only the extremes.
#
# This cannot be measured statically, but the SHAPE that made it slow
# can be pinned, and that shape is a simulation call ranging over every
# group. The property: .ppTableRankMax is defined once and used, and
# .ppTableP() is never called from a vapply/sapply/lapply over `keys`.
# The wall-clock budget itself is asserted at runtime in
# tests/testthat/test-screen-2026-09-09.R, which fails without the bound.
fsCode <- sub("#.*$", "", srcOf("R/failsafeTable.R"))
rankDef <- grep("^\\s*\\.ppTableRankMax\\s*<-", fsCode)
if (length(rankDef) != 1L)
  note(paste("R/failsafeTable.R: .ppTableRankMax must be defined exactly",
             "once, found", length(rankDef)))
if (!length(setdiff(grep("\\.ppTableRankMax", fsCode), rankDef)))
  note(paste("R/failsafeTable.R: .ppTableRankMax is defined but never used -",
             "the bound on how many nulls are simulated is not in force",
             "(screens 2026-09-08-2100 F1, 2026-09-09-0721 F1)"))
# THE POSITIVE PROPERTY, because matching the bad shapes did not work
# (security screen 2026-09-10-0536, F4). The previous spelling matched the
# LOOP HEADER line and then looked for .ppTableP on that same line, so it
# caught only a one-line regression: `for (k in keys) {` with the call in
# a braced body - the way anyone would actually write it back in - walked
# straight past, and so did a multi-line vapply. An assertion whose
# comment claims coverage it does not have is the shape AGENTS.md records
# as one of this project's worst defects.
#
# So instead of enumerating what is forbidden, this pins what is required:
# every .ppTableP() call in the file sits on a line that iterates one of
# the four bounded candidate sets. Mutation-verified against the four
# shapes the screen listed.
#
# THAT ALONE WAS NOT ENOUGH EITHER (security screen 2026-09-10-0611, F1).
# The call lines can be left exactly as they are while a candidate SET is
# redefined as `seq_along(keys)` - the most natural place to put the
# sweep back - and every call still "sits on a bounded line". The screen
# verified by mutation that this check stayed silent on it, and that the
# rank constant's "defined but never used" check stayed silent too, since
# the other set still referenced it. So the DEFINITIONS are pinned as
# well: candUp and candDn must be a utils::head() bounded by
# .ppTableRankMax, topUp and topDn a utils::head() bounded by
# .ppTableRefineTop. A definition spans two lines, so each is read with
# the line after it.
ppLines <- grep("\\.ppTableP\\s*\\(", fsCode, value = TRUE)
ppDef   <- grep("^\\s*\\.ppTableP\\s*<-", fsCode, value = TRUE)
ppCalls <- setdiff(ppLines, ppDef)
bounded <- grepl("for\\s*\\(\\s*i\\s+in\\s+(candUp|candDn|topUp|topDn)\\s*\\)", ppCalls)
if (!length(ppCalls) || !all(bounded))
  note(paste("R/failsafeTable.R: every .ppTableP() call must sit on a line",
             "that iterates candUp/candDn/topUp/topDn - a call outside those",
             "bounded sets is a sweep over every group, which is the 190 s",
             "parse the ranking replaced (screens 2026-09-09-0721 F1 and",
             "-1532) -", paste(trimws(ppCalls[!bounded]), collapse = " | ")))
# WHAT THIS PIN MUST SAY, AND WHY IT SAYS IT THIS WAY (screens
# 2026-09-10-0611 F1 and -0633 F2). The first spelling required only that
# the definition contain `utils::head(` and the constant SOMEWHERE on its
# two lines. The next screen defeated it five ways without touching the
# call sites: a NEGATIVE n (`head(x, -.ppTableRankMax)` returns all but
# the last 50 - the full sweep, constant present), `.ppTableRankMax *
# length(keys)`, the constant parked in a second statement on the same
# line, and a second assignment after the pinned one by `<<-`, `=` or
# `set[] <-`, none of which `^name <-` counted. So: the constant must be
# the WHOLE final argument of head(), and every assignment form to the
# four names is counted, not only `<-`.
for (set in c("candUp", "candDn", "topUp", "topDn")) {
  const <- if (set %in% c("candUp", "candDn")) ".ppTableRankMax" else ".ppTableRefineTop"
  # counted as MATCHES, not lines: a second assignment on the pinned
  # definition's own line (`candDn <- head(...); candDn <<- seq_along(keys)`)
  # is one line and two assignments, and the first harness run let it by
  pat <- paste0("(^|[^A-Za-z0-9._])", set, "\\s*(\\[[^]]*\\])?\\s*(<<-|<-|=)[^=]")
  hits <- regmatches(fsCode, gregexpr(pat, fsCode))
  nAssign <- sum(lengths(hits))
  assigns <- which(lengths(hits) > 0)
  defn <- if (nAssign == 1L)
    paste(fsCode[assigns:min(assigns + 1L, length(fsCode))], collapse = " ") else ""
  exact <- paste0("utils::head\\s*\\(.*,\\s*", gsub(".", "\\.", const, fixed = TRUE),
                  "\\s*\\)")
  if (nAssign != 1L || !grepl(exact, defn))
    note(paste0("R/failsafeTable.R: ", set, " must be assigned exactly once, as ",
                "utils::head(<order>, ", const, ") with the constant as the whole ",
                "final argument - anything else is the sweep over every group ",
                "coming back through the definition (screens 2026-09-10-0611 F1, ",
                "-0633 F2); found ", nAssign, " assignment(s)"))
}
# and the enumeration must still count before it builds (2100 F1)
avDef  <- grep("^\\s*\\.ppArmVectorCount\\s*<-", fsCode)
avCall <- setdiff(grep("\\.ppArmVectorCount\\s*\\(", fsCode), avDef)
# ...and the FILL must count every arm before it builds any (screen
# 2026-09-10-0536 F1; pinned here after screen 0611 showed the revert of
# that fix - build every arm, then take the product - passed this group
# unnoticed). Inside .ppFailsafeTableFill(), the first call to the
# counter must come before the first call to the builder. Same style as
# group 7's translation-before-centre ordering.
fillAt <- grep("^\\s*\\.ppFailsafeTableFill\\s*<-\\s*function", fsCode)
if (length(fillAt) == 1L) {
  # the body runs to the next top-level definition, not to the end of the
  # file - it is the last function today, and that is not a property to
  # lean on (screen 2026-09-10-0633 F2)
  nextDef <- grep("^[A-Za-z._][A-Za-z0-9._]*\\s*<-\\s*function", fsCode)
  endAt <- min(c(nextDef[nextDef > fillAt], length(fsCode)))
  body <- seq(fillAt, endAt)
  cntAll <- body[grep("\\.ppArmVectorCount\\s*\\(", fsCode[body])]
  bldAll <- body[grep("\\.ppArmVectors\\s*\\(", fsCode[body])]
  prodAt <- body[grep("prod\\s*\\(\\s*counts\\s*\\)", fsCode[body])]
  # EVERY count before ANY build, with the product taken in between: the
  # previous spelling compared only the FIRST of each, so moving the
  # per-arm count inside the build loop - precisely the shape it claimed
  # to pin - passed (screen 2026-09-10-0633 F2). Strict inequalities, since
  # nothing legitimate puts two of these on one line.
  if (!length(cntAll) || !length(bldAll) || !length(prodAt) ||
      max(cntAll) >= min(bldAll) || max(cntAll) >= min(prodAt) ||
      max(prodAt) >= min(bldAll))
    note(paste("R/failsafeTable.R: .ppFailsafeTableFill() must count EVERY arm",
               "(.ppArmVectorCount), take prod(counts), and only then build ANY",
               "(.ppArmVectors) - a count inside the build loop is the 1,636 MB",
               "decline of screen 2026-09-10-0536 F1"))
  # ...and the scoring-cost gate must precede the first scoring loop
  # (screen 2026-09-10-0633 F1): the dimension check, then candUp.
  gateAt <- body[grep("\\.ppTableRefineReps\\s*>\\s*\\.ppTableCellMax", fsCode[body])]
  candAt <- body[grep("(^|[^A-Za-z0-9._])candUp\\s*<-", fsCode[body])]
  if (!length(gateAt) || !length(candAt) || min(gateAt) >= min(candAt))
    note(paste("R/failsafeTable.R: the scoring-cost gate (arms x levels x",
               ".ppTableRefineReps against .ppTableCellMax) must precede the",
               "candUp loop - without it a two-candidate block of 200 arms by",
               "37 levels costs 1,008 MB (screen 2026-09-10-0633 F1)"))
} else {
  note(paste("R/failsafeTable.R: .ppFailsafeTableFill() must be defined",
             "exactly once, found", length(fillAt)))
}
if (length(avDef) != 1L || !length(avCall))
  note(paste("R/failsafeTable.R: .ppArmVectorCount() must be defined and",
             "called from .ppArmVectors() before any vector is built -",
             "without it a block declines by enumerating itself (153 s at",
             "an arm of 500,000; screen 2026-09-08-2100 F1)"))

## ------------------------------------------------------------------------
if (length(fail)) {
  cat("SECURITY CHECK FAILED:
")
  for (m in fail) cat("  -", m, "
")
  quit(status = 1)
}
cat("Security check passed:", length(rFiles), "R/ files,",
    "8 property groups.
")
