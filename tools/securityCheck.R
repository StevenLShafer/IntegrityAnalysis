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
            "\\bReduce\\s*\\(\\s*get\\b")
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
  tmpl <- fnBody(api, "\\.apiTemplateCsv")
  res5 <- fnBody(api, "\\.apiResultsCsv")
  if (length(res5) && !any(grepl("\\.apiCsvSafe", res5)))
    note(paste("R/apiService.R: .apiResultsCsv no longer sanitizes -",
               "the editor-facing CSV can smuggle formulas (review M5)"))
  # The journal-style tables (issue 15, returned by /analyze) are a
  # THIRD human-facing CSV surface, and their COLUMN HEADERS are arm
  # names parsed from the manuscript. The generic "is .apiCsvSafe used
  # anywhere in this file" check would still pass if this one call site
  # lost it, so pin the call site itself.
  jline <- grep("^[^#]*buildBaselineTables", api)
  if (length(jline)) {
    win <- api[jline[1]:min(jline[1] + 8, length(api))]
    if (!any(grepl("\\.apiCsvSafe", win)))
      note(paste("R/apiService.R: the journal-style CSV is emitted",
                 "without .apiCsvSafe - arm names become column headers",
                 "and would carry formulas to the editor"))
  }
  # ...and .apiCsvSafe must sanitize NAMES, not only values: a header is
  # as executable as a cell (found 2026-08-27 screening journalTables).
  csvFn <- fnBody(api, "\\.apiCsvSafe")
  # ^[^#]* so a COMMENTED-OUT assignment does not satisfy the check -
  # the first version of this assertion passed on exactly that
  if (length(csvFn) && !any(grepl("^[^#]*names\\(data\\)\\s*<-", csvFn)))
    note(paste("R/apiService.R: .apiCsvSafe no longer sanitizes column",
               "names - arm names reach the editor as live formulas"))

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

## ------------------------------------------------------------------------
if (length(fail)) {
  cat("SECURITY CHECK FAILED:
")
  for (m in fail) cat("  -", m, "
")
  quit(status = 1)
}
cat("Security check passed:", length(rFiles), "R/ files,",
    "5 property groups.
")
