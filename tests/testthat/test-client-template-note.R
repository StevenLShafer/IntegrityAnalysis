# test-client-template-note.R - the two supplied API clients save the
# template CSV exactly as the service returned it, and say so when a cell
# begins with a character spreadsheet software reads as a formula.
#
# The clients are driven as a user runs them - the real scripts, as child
# processes, against a stub HTTP server on 127.0.0.1 whose reply carries a
# template with the harmless label "=1+1" and a negative mean. Nothing
# leaves the loopback interface and the token is an invented string.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) after an       #
# outside security review of the same date.                                #
############################################################################
skip_if_not_installed("callr")
skip_if_not_installed("httpuv")

# IA_CLIENT_DIR lets a differential run point the SAME test at another
# checkout's clients (the unfixed ones); the default is this tree's tools/.
clientDir <- Sys.getenv("IA_CLIENT_DIR", normalizePath(test_path("..", "..", "tools"), winslash = "/"))
skip_if_not(file.exists(file.path(clientDir, "apiClient.py")), "clients not found")

startStub <- function(handler) {
  port <- httpuv::randomPort()
  px <- callr::r_bg(function(port, handler) {
    httpuv::runServer("127.0.0.1", port, list(call = handler))
  }, args = list(port = port, handler = handler))
  up <- FALSE
  for (i in 1:100) {
    up <- tryCatch({ con <- socketConnection("127.0.0.1", port, open = "r+", timeout = 1); close(con); TRUE },
                   error = function(e) FALSE, warning = function(w) FALSE)
    if (up) break
    Sys.sleep(0.1)
  }
  if (!up) { px$kill(); skip("stub server did not start") }
  list(px = px, port = port, base = paste0("http://127.0.0.1:", port))
}
pythonExe <- function() {
  for (p in c("python3", "python")) {
    exe <- Sys.which(p)
    if (!nzchar(exe)) next
    # (Windows offers a Store alias named python3 that only prints a message)
    ok <- tryCatch(suppressWarnings(system2(exe, "--version", stdout = TRUE, stderr = TRUE)), error = function(e) character(0))
    if (length(ok) && is.null(attr(ok, "status")) && any(grepl("^Python 3", ok))) return(exe)
  }
  ""
}
runClient <- function(cmd, args) {
  old <- Sys.getenv(c("INTEGRITY_API_TOKEN", "R_LIBS"), unset = NA)
  on.exit({
    for (nm in names(old)) if (is.na(old[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv, as.list(setNames(old[[nm]], nm)))
  })
  Sys.setenv(INTEGRITY_API_TOKEN = "dummy-test-token-not-a-secret",
             R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  out <- suppressWarnings(system2(cmd, args, stdout = TRUE, stderr = TRUE))
  list(status = if (is.null(attr(out, "status"))) 0L else attr(out, "status"),
       text = paste(out, collapse = "\n"))
}
rscript <- file.path(R.home("bin"), "Rscript")

# /parse returns a template with a formula-looking label and a negative
# mean; /analyze returns one with plain labels
formulaTemplate <- "\"TRIAL\",\"ROW\",\"N\",\"MEAN\",\"SD\"\n\"1\",\"=1+1\",\"20\",\"-0.5\",\"9.2\"\n\"1\",\"Age\",\"20\",\"54.1\",\"9.2\"\n"
plainTemplate   <- "\"TRIAL\",\"ROW\",\"N\",\"MEAN\",\"SD\"\n\"1\",\"Age\",\"20\",\"-0.5\",\"9.2\"\n"

test_that("both clients keep the template verbatim and note a formula-looking cell", {
  stub <- startStub(local({ ft <- formulaTemplate; pt <- plainTemplate; function(req) {
    # JSON string escapes: a quote becomes \" and a newline \n (fixed = TRUE:
    # the replacement is literal, so two source backslashes make one)
    esc <- function(s) gsub("\n", "\\n", gsub("\"", "\\\"", s, fixed = TRUE), fixed = TRUE)
    body <- if (identical(req$PATH_INFO, "/health")) '{"ok":true}'
            else if (identical(req$PATH_INFO, "/parse")) paste0('{"ok":true,"rows":2,"templateCsv":"', esc(ft), '"}')
            else paste0('{"ok":true,"rows":1,"overallP":0.5,"templateCsv":"', esc(pt), '"}')
    list(status = 200L, headers = list("Content-Type" = "application/json"), body = body)
  } }))
  on.exit(stub$px$kill(), add = TRUE)

  py <- pythonExe()
  clients <- list(R = list(cmd = rscript, pre = file.path(clientDir, "apiClient.R")))
  if (nzchar(py)) clients$python <- list(cmd = py, pre = file.path(clientDir, "apiClient.py"))

  for (nm in names(clients)) {
    cl <- clients[[nm]]
    dir <- file.path(tempdir(), paste0("tpl-", nm, "-", basename(tempfile(""))))
    dir.create(dir)
    csv <- file.path(dir, "table.csv")
    writeLines(c("TRIAL,ROW,N,MEAN,SD", "1,Age,20,54.1,9.2"), csv)
    # the formula-looking label: noted, and kept exactly
    r <- runClient(cl$cmd, c(shQuote(cl$pre), "parse", stub$base, shQuote(csv)))
    expect_identical(r$status, 0L, info = paste(nm, r$text))
    expect_true(grepl("note: 1 cell", r$text, fixed = TRUE), info = paste(nm, r$text))
    expect_true(grepl("text editor", r$text, fixed = TRUE), info = paste(nm, r$text))
    saved <- readLines(file.path(dir, "table-template.csv"))
    expect_true(any(grepl("\"=1+1\"", saved, fixed = TRUE)), info = paste(nm, "template must be verbatim"))
    expect_true(any(grepl("\"-0.5\"", saved, fixed = TRUE)))
    # plain labels and a negative number: no note
    r2 <- runClient(cl$cmd, c(shQuote(cl$pre), "analyze", stub$base, shQuote(csv)))
    expect_identical(r2$status, 0L, info = paste(nm, r2$text))
    expect_false(grepl("note:", r2$text, fixed = TRUE), info = paste(nm, r2$text))
  }
})
