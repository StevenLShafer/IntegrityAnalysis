# test-client-redirects.R - the two supplied API clients (tools/apiClient.py,
# tools/apiClient.R) do not follow a redirect with the bearer token, and
# refuse a plain-http base URL that is not this machine.
#
# The clients are driven as a user runs them - the real scripts, as child
# processes, against two stub HTTP servers on 127.0.0.1: one that answers
# the health check and redirects the authenticated request, one that
# records what reaches it. Nothing leaves the loopback interface and the
# token is an invented string.
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

# a stub server in a child process; `handler(req)` must be self-contained
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
json200 <- function(body) list(status = 200L, headers = list("Content-Type" = "application/json"), body = body)

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
  # the child inherits the token and, for Rscript, this session's library
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

test_that("neither client follows a redirect with the token, and both work when not redirected", {
  record <- tempfile("reached-", fileext = ".txt")
  # the recording server: whatever reaches it is written down
  sink <- startStub(local({ record <- record; function(req) {
    auth <- if (is.null(req$HTTP_AUTHORIZATION)) "" else req$HTTP_AUTHORIZATION
    cat(req$REQUEST_METHOD, req$PATH_INFO, auth, "\n", file = record, append = TRUE)
    if (identical(req$PATH_INFO, "/health"))
      return(list(status = 200L, headers = list("Content-Type" = "application/json"), body = '{"ok":true,"commit":"deadbeefdeadbeef"}'))
    # the JSON escapes are literal here (\\" and \\n in the R source)
    list(status = 200L, headers = list("Content-Type" = "application/json"),
         body = '{"ok":true,"rows":1,"templateCsv":"\\"TRIAL\\",\\"ROW\\",\\"N\\",\\"MEAN\\",\\"SD\\"\\n\\"1\\",\\"Age\\",\\"20\\",\\"54.1\\",\\"9.2\\"\\n"}')
  } }))
  on.exit(sink$px$kill(), add = TRUE)
  # the redirecting server: health is fine, the authenticated request is
  # sent elsewhere
  target <- paste0(sink$base, "/parse")
  redir <- startStub(local({ target <- target; function(req) {
    if (identical(req$PATH_INFO, "/health"))
      return(list(status = 200L, headers = list("Content-Type" = "application/json"), body = '{"ok":true}'))
    list(status = 302L, headers = list("Location" = target, "Content-Type" = "text/plain"), body = "moved")
  } }))
  on.exit(redir$px$kill(), add = TRUE)

  csv <- tempfile("table-", fileext = ".csv")
  writeLines(c("TRIAL,ROW,N,MEAN,SD", "1,Age,20,54.1,9.2"), csv)

  py <- pythonExe()
  clients <- list(R = list(cmd = rscript, pre = file.path(clientDir, "apiClient.R")))
  if (nzchar(py)) clients$python <- list(cmd = py, pre = file.path(clientDir, "apiClient.py"))
  expect_true(length(clients) >= 1L)

  for (nm in names(clients)) {
    cl <- clients[[nm]]
    if (file.exists(record)) unlink(record)
    r <- runClient(cl$cmd, c(shQuote(cl$pre), "parse", redir$base, shQuote(csv)))
    expect_false(r$status == 0L, info = paste(nm, "must not report success after a redirect:", r$text))
    expect_true(grepl("redirect", r$text, ignore.case = TRUE), info = paste(nm, r$text))
    reached <- if (file.exists(record)) readLines(record) else character(0)
    expect_false(any(grepl("dummy-test-token", reached, fixed = TRUE)),
                 info = paste(nm, "forwarded the token:", paste(reached, collapse = " | ")))
    # the same client, pointed straight at a service, still works
    r2 <- runClient(cl$cmd, c(shQuote(cl$pre), "parse", sink$base, shQuote(csv)))
    expect_identical(r2$status, 0L, info = paste(nm, r2$text))
    expect_true(grepl("ok=TRUE|ok=True", r2$text), info = paste(nm, r2$text))
    # and refuses a remote service that is not https
    r3 <- runClient(cl$cmd, c(shQuote(cl$pre), "parse", "http://service.example.invalid", shQuote(csv)))
    expect_false(r3$status == 0L, info = paste(nm, r3$text))
    expect_true(grepl("https", r3$text, fixed = TRUE), info = paste(nm, r3$text))
  }
})
