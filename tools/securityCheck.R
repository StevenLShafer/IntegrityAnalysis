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
            "[\"']DTDLOAD[\"']")
for (f in rFiles) {
  src <- srcOf(f)
  code <- sub("#.*$", "", src)          # comments may NAME the patterns
  for (pat in banned) {
    hit <- grep(pat, code)
    if (length(hit))
      note(sprintf("%s:%d: banned pattern %s", f, hit[1], pat))
  }
  hit <- grep("\\bsystem2\\s*\\(", code)
  if (length(hit) && basename(f) != "parseBaselineTableFiles.R")
    note(sprintf("%s:%d: system2() outside the reviewed launcher", f, hit[1]))
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
}

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

## ------------------------------------------------------------------------
if (length(fail)) {
  cat("SECURITY CHECK FAILED:
")
  for (m in fail) cat("  -", m, "
")
  quit(status = 1)
}
cat("Security check passed:", length(rFiles), "R/ files,",
    "6 property groups.
")
