# securityCheckMutations.R - the mutation set behind the rowTotal pin in
# tools/securityCheck.R (group 8), checked in so that it does not have to
# be re-derived by the next screen (screen 2026-09-10-1050, F3).
#
# PROVENANCE: assembled by Claude Code (model Claude Fable 5.1), 2026-09-10,
# from the harnesses run for screens 2026-09-10-0611, -0633, -0858, -0923,
# -0955, -1031 and -1050 and for CodeRabbit's comment on PR #248. Each
# case is a shape that a previous version of the pin let through with the
# N-based row total - the 24a8177 quantity screen 0815 replaced - in force.
#
# WHAT IT DOES. It rewrites R/failsafeTable.R in place, one mutation at a
# time, runs tools/securityCheck.R, and reports whether the check fired;
# then restores the file byte for byte. Every mutation must fire and the
# clean tree must pass. It is NOT part of the test suite (each run is a
# full tripwire, ~3 s, and there are forty of them): run it by hand after
# any edit to the pin or to the rowTotal statement -
#
#     Rscript tools/securityCheckMutations.R [path to a checkout]
#
# - and paste the table into the pull request. Nothing is written outside
# R/failsafeTable.R, and git status must be clean afterwards.

args <- commandArgs(TRUE)
if (length(args)) setwd(args[1])
stopifnot(file.exists("R/failsafeTable.R"), file.exists("tools/securityCheck.R"))
rscript <- file.path(R.home("bin"), "Rscript")
origRaw <- readBin("R/failsafeTable.R", "raw", file.info("R/failsafeTable.R")$size)
orig <- readLines("R/failsafeTable.R", warn = FALSE)
restore <- function() writeBin(origRaw, "R/failsafeTable.R")
on.exit(restore(), add = TRUE)

fires <- function() {
  out <- suppressWarnings(system2(rscript, c("--vanilla", "tools/securityCheck.R"),
                                  stdout = TRUE, stderr = TRUE))
  any(grepl("SECURITY CHECK FAILED", out))
}
defLine <- function(l, set) grep(paste0("^\\s*", set, "\\s*<-"), l)
rowLine <- function(l) {
  i <- grep("rowTotal <- if \\(isTRUE\\(partition\\)\\)", l)
  stopifnot(length(i) == 1); i
}
fillLine <- function(l) {
  i <- grep("^\\.ppFailsafeTableFill <- function", l); stopifnot(length(i) == 1); i
}
# the N-based total in place of the reference statement (three lines)
nBased <- function(l) {
  i <- rowLine(l); l[i] <- "  rowTotal <- as.numeric(N[keep])"; l[i + 1L] <- ""; l[i + 2L] <- ""
  list(l = l, i = i)
}
# a line appended AFTER the correct three-line statement
after <- function(l, line) { i <- rowLine(l); append(l, line, after = i + 2L) }
elseBranch <- function(l, line1, line2 = "") {
  i <- rowLine(l); l[i + 1L] <- line1; l[i + 2L] <- line2; l
}
deadVapply <- c("    sum(as.numeric(ifelse(amb[i, ], hi[i, ], cnt[i, ])), na.rm = TRUE), numeric(1))")

cases <- list(
  "(unmutated)" = function(l) l,
  # ---- group 8's neighbours, kept so a regression there is seen too
  "0611: candDn <- seq_along(keys)" = function(l) {
    i <- defLine(l, "candDn"); l[i] <- "  candDn <- seq_along(keys)"; l },
  "0633: scoring gate moved AFTER candUp" = function(l) {
    gi <- grep("\\.ppTableRefineReps > \\.ppTableCellMax", l)[1]
    block <- l[gi:(gi + 3L)]; l <- l[-(gi:(gi + 3L))]
    append(l, block, after = defLine(l, "candDn")) },
  # ---- the N-based total, and every spelling that hid it
  "0858: rowTotal <- as.numeric(N[keep]) unconditionally" = function(l) nBased(l)$l,
  "0923: dead `unused <- vapply(ifelse)` beside" = function(l) {
    z <- nBased(l); l <- z$l; i <- z$i
    l[i + 1L] <- "  unused <- vapply(keep, function(i)"; l[i + 2L] <- deadVapply; l },
  "0955a: non-assignment dead `invisible(vapply(ifelse))`" = function(l) {
    z <- nBased(l); l <- z$l; i <- z$i
    l[i + 1L] <- "  invisible(vapply(keep, function(i)"
    l[i + 2L] <- paste0(deadVapply, ")"); l },
  "0955b: same line `; if (FALSE) ifelse(...)`" = function(l) {
    z <- nBased(l); l <- z$l; i <- z$i
    l[i] <- "  rowTotal <- as.numeric(N[keep]); if (FALSE) ifelse(amb[i, ], hi[i, ], cnt[i, ])"; l },
  "0955c: guarded `if (FALSE) rowTotal <- vapply(ifelse)`" = function(l) {
    z <- nBased(l); l <- z$l; i <- z$i
    l[i + 1L] <- "  if (FALSE) rowTotal <- vapply(keep, function(i)"; l[i + 2L] <- deadVapply; l },
  "0955d: `dead = vapply(ifelse)`" = function(l) {
    z <- nBased(l); l <- z$l; i <- z$i
    l[i + 1L] <- "  dead = vapply(keep, function(i)"; l[i + 2L] <- deadVapply; l },
  "0955e: indexed `dead[1] <- sum(ifelse)`" = function(l) {
    z <- nBased(l); l <- z$l; i <- z$i
    l[i + 1L] <- "  dead <- numeric(1); dead[1] <- sum(ifelse(amb[1, ], hi[1, ], cnt[1, ]))"; l },
  "0955f: `if (TRUE)` in place of isTRUE(partition)" = function(l) {
    i <- rowLine(l); l[i] <- sub("isTRUE\\(partition\\)", "TRUE", l[i]); l },
  "0955g: right-assign of an N-based rowTotal" = function(l) {
    z <- nBased(l); l <- z$l; i <- z$i
    l[i] <- "  as.numeric(N[keep]) -> rowTotal"
    l[i + 1L] <- "  dead <- vapply(keep, function(i)"; l[i + 2L] <- deadVapply; l },
  "0955h: second assignment via assign(\"rowTotal\", N[keep])" = function(l)
    after(l, "  assign(\"rowTotal\", as.numeric(N[keep]))"),
  "1031a: `rowTotal[] <- as.numeric(N[keep])` after" = function(l)
    after(l, "  rowTotal[] <- as.numeric(N[keep])"),
  "1031b: `rowTotal[seq_along(rowTotal)] <- ...` after" = function(l)
    after(l, "  rowTotal[seq_along(rowTotal)] <- as.numeric(N[keep])"),
  "1031c: `for (rowTotal in list(as.numeric(N[keep]))) NULL`" = function(l)
    after(l, "  for (rowTotal in list(as.numeric(N[keep]))) NULL"),
  "1031d: `assign(x = \"rowTotal\", ...)`" = function(l)
    after(l, "  assign(x = \"rowTotal\", as.numeric(N[keep]))"),
  "1031e: assign() through a variable" = function(l)
    after(l, "  nm <- \"rowTotal\"; assign(nm, as.numeric(N[keep]))"),
  "1031f: list2env(list(rowTotal = ...), environment())" = function(l)
    after(l, "  list2env(list(rowTotal = as.numeric(N[keep])), environment())"),
  "1031g: negated branch `if (!isTRUE(partition))`" = function(l) {
    i <- rowLine(l); l[i] <- sub("isTRUE\\(partition\\)", "!isTRUE(partition)", l[i]); l },
  "1031h: braced RHS with both strings in dead statements" = function(l) {
    i <- rowLine(l)
    l[i] <- "  rowTotal <- { if (FALSE) isTRUE(partition); if (FALSE) vapply(keep, function(i)"
    l[i + 1L] <- deadVapply; l[i + 2L] <- "    as.numeric(N[keep]) }"; l },
  "1031i: makeActiveBinding(\"rowTotal\", ...)" = function(l)
    after(l, "  makeActiveBinding(\"rowTotal\", function() as.numeric(N[keep]), environment())"),
  "CR248a: `rowTotal[[1L]] <- ...` after" = function(l)
    after(l, "  rowTotal[[1L]] <- as.numeric(N[keep])[1]"),
  "CR248b: `names(rowTotal) <- NULL` after" = function(l)
    after(l, "  names(rowTotal) <- NULL"),
  "CR248c: `attr(rowTotal, \"a\") <- 1` after" = function(l)
    after(l, "  attr(rowTotal, \"a\") <- 1"),
  "CR248d: TRUE branch `{ N[keep]; rep(0, length(keep)) }`" = function(l) {
    i <- rowLine(l)
    l[i] <- sub("as.numeric\\(N\\[keep\\]\\) else", "{ N[keep]; rep(0, length(keep)) } else", l[i])
    stopifnot(grepl("rep\\(0", l[i])); l },
  "CR248e: ELSE branch dead ifelse, returns rep(0)" = function(l)
    elseBranch(l, "    { ifelse(amb[1, ], hi[1, ], cnt[1, ]); rep(0, length(keep)) }"),
  "CR248f: right-assign onto an indexed target" = function(l)
    after(l, "  as.numeric(N[keep]) -> rowTotal[]"),
  "1050-F1a: braced ELSE, dead full vapply, returns as.numeric(N)[keep]" = function(l)
    elseBranch(l, "    { vapply(keep, function(i)", paste0(deadVapply, "; as.numeric(N)[keep] }")),
  "1050-F1b: braced ELSE, dead local function around ifelse, N[ keep ]" = function(l)
    elseBranch(l, "    { f <- function(i) ifelse(amb[i, ], hi[i, ], cnt[i, ]); as.numeric(N[ keep ]) }"),
  "1050-F1c: `* 0` appended to the sum" = function(l) {
    i <- rowLine(l)
    l[i + 2L] <- sub("na.rm = TRUE\\)", "na.rm = TRUE) * 0", l[i + 2L]); stopifnot(grepl("\\* 0", l[i + 2L])); l },
  "1050-F2a: `msg <- \"#\"; rowTotal[] <- ...` (a # in a string)" = function(l)
    after(l, "  msg <- \"#\"; rowTotal[] <- as.numeric(N[keep])"),
  "1050-F2b: `msg <- \"#\"; assign(\"rowTotal\", ...)`" = function(l)
    after(l, "  msg <- \"#\"; assign(\"rowTotal\", as.numeric(N[keep]))"),
  "1050-F2c: group 1 - a banned primitive after a # in a string" = function(l)
    after(l, "  msg <- \"#\"; system(\"id\")"),
  "1050-F3a: backticked `rowTotal` <- ..." = function(l)
    after(l, "  `rowTotal` <- as.numeric(N[keep])"),
  "1050-F3b: delayedAssign(\"rowTotal\", ...)" = function(l)
    after(l, "  delayedAssign(\"rowTotal\", as.numeric(N[keep]))"),
  "1050-F3c: e <- environment(); e[[\"rowTotal\"]] <- ..." = function(l)
    after(l, "  e <- environment(); e[[\"rowTotal\"]] <- as.numeric(N[keep])"),
  "1050-F3d: for (rowTotal / in ...) split over two lines" = function(l) {
    i <- rowLine(l); append(l, c("  for (rowTotal", "       in list(as.numeric(N[keep]))) NULL"), after = i + 2L) },
  "1050-F3e: assign( / (\"rowTotal\", ...) split over two lines" = function(l) {
    i <- rowLine(l); append(l, c("  assign(", "    \"rowTotal\", as.numeric(N[keep]))"), after = i + 2L) },
  "1050-F3f: a helper defined BEFORE the fill, called from the body" = function(l) {
    l <- after(l, "  .ppRebind(as.numeric(N[keep]))")
    i <- fillLine(l)
    append(l, c(".ppRebind <- function(v) assign(\"rowTotal\", v, envir = parent.frame())", ""), after = i - 1L) },
  "1050-F3g: environment()$rowTotal <- ..." = function(l)
    after(l, "  environment()$rowTotal <- as.numeric(N[keep])")
)

res <- character(0)
for (nm in names(cases)) {
  writeLines(cases[[nm]](orig), "R/failsafeTable.R")
  f <- fires()
  res <- c(res, sprintf("%-70s tripwire fires: %s", nm, if (f) "YES" else "no"))
  cat(res[length(res)], "\n")
}
restore()
final <- fires()
cat("\nrestored; final: ", if (final) "FAILS (bad)" else "passes", "\n")
bad <- c(res[-1][!grepl("YES$", res[-1])], if (grepl("YES$", res[1])) res[1], if (final) "restored tree fails")
if (length(bad)) { cat("\nNOT AS REQUIRED:\n"); cat(bad, sep = "\n"); quit(status = 1L) }
cat("every mutation fires; the clean tree passes\n")
