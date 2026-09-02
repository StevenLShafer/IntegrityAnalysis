# harvestMedrxivS3.R - grow the medRxiv stress-test corpus through the
# server's OWN bulk channel: the requester-pays S3 bucket.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-26 by Claude Code (model Claude Fable 5) at Steve        #
# Shafer's request, the same day the HTTPS route died: the first nightly   #
# harvest got HTTP 403 on 67 of 72 PDF fetches (medRxiv's bot protection,  #
# which we do not evade - ISSUES.md issue 21). This route replaces it      #
# with the channel medRxiv built FOR bulk mining:                          #
# s3://medrxiv-src-monthly (us-east-1, requester pays - their docs:        #
# "charges ... are intended to ensure that costs are covered by the        #
# user"). Verified live the same day: 100 July-2026 packages, 842 MB,     #
# about seven cents of egress.                                             #
#                                                                          #
# Their conditions, which this corpus honors by construction: bulk TDM     #
# with author consent; link back to medRxiv rather than re-host; no        #
# redistribution. The corpus lives under C:/temp, is NEVER committed,     #
# and every file's DOI and license ride in the manifest.                   #
#                                                                          #
# ARCHITECTURE - download and processing are separate phases so each is   #
# independently testable and resumable:                                    #
#   Phase 1 (S3): list the current and previous month folders, diff       #
#     against the manifest, download up to maxFiles / maxGB NEW .meca     #
#     packages into <outDir>/incoming. Uses the aws CLI with the         #
#     "harvest" profile - a dedicated IAM user with a long-lived access  #
#     key (see below). WHY NOT Identity Center: measured 2026-08-26,     #
#     its token expired EIGHT HOURS after login (the default session     #
#     duration), so an unattended 2 AM job either failed or demanded a   #
#     daily browser login with MFA. A scheduled task cannot do that.     #
#     The dedicated user removes the problem rather than managing it.    #
#   Phase 2 (local): every .meca in incoming/ is a zip: unpack, read      #
#     DOI + title + abstract + license from the JATS XML, apply the       #
#     SHARED RCT filter (corpus/rctFilterPatterns.R - the abstract here   #
#     is the real full abstract, better input than the API's metadata),  #
#     keep RCT PDFs as <outDir>/<doi with / as _>.pdf, and delete the     #
#     package and extraction either way so disk stays bounded.            #
#                                                                          #
# COST GUARD: maxGB per run (default 2 GB ~ $0.18) on top of the          #
# account's $10/month budget alarm. There is no rate to be gentle about   #
# on S3 - requester-pays IS the courtesy - but a 1 s pause between        #
# downloads keeps the nightly job humble anyway.                           #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/harvestMedrxivS3.R [maxFiles] [maxGB] [outDir]          #
#     maxFiles  new packages per run (default 100; 0 = skip phase 1 and   #
#               just process whatever is already in incoming/)             #
#     maxGB     download budget per run (default 2)                        #
#     outDir    default C:/temp/medrxiv_rct                                #
#     months    which folders to list (default "recent"):                  #
#                 "recent"     current + previous month - NIGHTLY scope    #
#                 "all"        every Current_Content month folder (72)     #
#                 "back"       every Back_Content batch folder (16), the   #
#                              pre-2021 archive                            #
#                 "everything" both, months newest-first then the archive  #
#                 "2021-06"    a single month, for a targeted top-up       #
#                 "Back_Content/medRxiv_Batch_03"  a single batch folder   #
#                                                                          #
#   "all" deliberately still means Current_Content only, so the scheduled  #
#   backfill and any existing caller behave exactly as before. The         #
#   complete sweep has its own name because a scope that silently widened  #
#   would be the same mistake in the other direction.                      #
############################################################################

suppressPackageStartupMessages({library(xml2)})

scriptDir <- dirname(sub("--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[1]))
source(file.path(scriptDir, "rctFilterPatterns.R"))
source(file.path(scriptDir, "mecaPrefixScreen.R"))

args     <- commandArgs(trailingOnly = TRUE)
maxFiles <- if (length(args) >= 1) as.integer(args[1]) else 100L
maxGB    <- if (length(args) >= 2) as.numeric(args[2]) else 2
outDir   <- if (length(args) >= 3) args[3] else file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "medrxiv_rct")
monthArg <- if (length(args) >= 4) args[4] else "recent"
incoming <- file.path(outDir, "incoming")
dir.create(incoming, showWarnings = FALSE, recursive = TRUE)

# ---- single-instance lock ------------------------------------------------
# Two harvesters sharing an outDir share s3Manifest.csv and incoming/.
# The manifest is read, appended and rewritten wholesale, so concurrent
# runs can lose each other's rows or re-download what the other already
# has - and both would be right about what they saw.
#
# This became reachable the moment a long BACKFILL existed: it runs for
# hours and the nightly 02:00 job fires straight into it. It is also the
# leading suspect for the unexplained exit-1 of the 2026-08-27 nightly
# run, which was never diagnosed.
#
# REFUSE, DO NOT QUEUE. A nightly job that skips one night because a
# backfill is running has lost nothing: the backfill's "all" scope
# already covers everything the nightly would have fetched. A queued job
# would still be waiting when the next night's copy started.
#
# TWO BUGS FOUND WRITING THIS, both of which made an earlier version
# non-functional while looking correct, and each caught only by testing
# the state a lock exists for:
#
#   1. R's default TRE engine does not support \b, so
#      grepl("\b20280\b", out) is FALSE even with the pid plainly in
#      the line. The lock judged every LIVE holder dead and broke itself
#      on every call. Whitespace delimiters work in TRE and say what is
#      meant: the pid as its own column, not a substring of a bigger
#      number.
#   2. on.exit() at script TOP LEVEL never runs - it registers against a
#      function frame, and a script body is not one. The lock was taken
#      and never released. reg.finalizer(onexit = TRUE) does run;
#      verified by marker file before this was written.
#
#   Together those two CANCELLED OUT: the lock appeared to work because
#   its own failure to release was undone by its own failure to detect.
lockPath <- file.path(outDir, "harvest.lock")
lockAlive <- function(path) {
  if (!file.exists(path)) return(FALSE)
  info <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(info) || is.null(info$pid)) return(FALSE)
  alive <- tryCatch({
    out <- suppressWarnings(system2("tasklist",
      c("/FI", shQuote(paste0("PID eq ", info$pid)), "/NH"),
      stdout = TRUE, stderr = FALSE))
    any(grepl(paste0("(^|[[:space:]])", info$pid, "([[:space:]]|$)"), out))
  }, error = function(e) FALSE)
  if (!alive) {
    cat("stale lock from pid", info$pid, "- breaking it\n")
    unlink(path)
    return(FALSE)
  }
  cat("another harvest is running (pid ", info$pid, ", scope '",
      if (is.null(info$scope)) "?" else info$scope,
      "') - EXITING.\n", sep = "")
  cat("  Not an error: the running job's scope covers this one.\n")
  TRUE
}
if (lockAlive(lockPath)) quit(status = 0)
saveRDS(list(pid = Sys.getpid(), started = Sys.time(), scope = monthArg),
        lockPath)
.lockGuard <- new.env()
reg.finalizer(.lockGuard, function(e) {
  info <- tryCatch(readRDS(lockPath), error = function(err) NULL)
  if (!is.null(info) && identical(info$pid, Sys.getpid())) unlink(lockPath)
}, onexit = TRUE)

# The bucket root, NOT Current_Content. Folder names below carry their own
# prefix - "Current_Content/April_2021" or "Back_Content/medRxiv_Batch_01" -
# because the archive lives under a SECOND prefix that this script could
# not previously address at all. See the scope block below.
bucket  <- "s3://medrxiv-src-monthly/"
# The "harvest" profile is a dedicated IAM user with a long-lived access
# key, NOT the Identity Center login (2026-08-27). Identity Center tokens
# expire with the SSO session - 8 hours by default - so an unattended
# nightly job either fails or demands a daily browser login with MFA,
# which is not a thing a 2 AM task can do. This user can do exactly two
# things (see the inline policy HarvestS3Access): read the public
# medRxiv TDM bucket, and read/write Steve's own corpus bucket. It has
# no console access and cannot touch the API service, IAM, or billing,
# so the blast radius of the static key is far smaller than the
# AdministratorAccess session it replaces.
profile <- Sys.getenv("INTEGRITY_AWS_PROFILE", "harvest")
manifestPath <- file.path(outDir, "s3Manifest.csv")
manifest <- if (file.exists(manifestPath))
  read.csv(manifestPath, colClasses = "character") else
  data.frame(meca = character(), doi = character(), verdict = character(),
             license = character(), title = character(), pdf = character(),
             bytes = character(), date = character(),
             stringsAsFactors = FALSE)
saveManifest <- function() write.csv(manifest, manifestPath,
                                     row.names = FALSE)

# The aws CLI installs per-user and is NOT on the PATH a scheduled
# Rscript inherits (found live 2026-08-26): resolve it explicitly.
awsExe <- local({
  p <- Sys.which("aws")
  if (nzchar(p)) return(p)
  cand <- file.path(Sys.getenv("LOCALAPPDATA"),
                    "Programs/Amazon/AWSCLIV2/aws.exe")
  if (file.exists(cand)) return(cand)
  cand <- "C:/Program Files/Amazon/AWSCLIV2/aws.exe"
  if (file.exists(cand)) return(cand)
  stop("aws CLI not found - install it, or add it to PATH.", call. = FALSE)
})

awsS3 <- function(...) {
  out <- suppressWarnings(system2(awsExe, c("s3", ..., "--request-payer",
                                            "requester", "--profile",
                                            profile), stdout = TRUE,
                                  stderr = TRUE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    if (any(grepl("sso|expired|credentials|token", out, ignore.case = TRUE)))
      stop("AWS credentials for profile '", profile, "' are not working. ",
           "This profile should hold a long-lived IAM access key that ",
           "never expires - check `aws configure list --profile ", profile,
           "`, and if the key was rotated or deleted, create a new one ",
           "for the integrityanalysis-harvest user.", call. = FALSE)
    stop("aws s3 failed: ", paste(utils::tail(out, 2), collapse = " "),
         call. = FALSE)
  }
  out
}

# ---- phase 1: download new packages -------------------------------------
if (maxFiles > 0) {
  # current + previous month, so a run near month's end still sees the
  # packages the rollover is filling in. month.name, not months():
  # the folder names are English regardless of the machine's locale.
  monthName <- function(d) paste0("Current_Content/",
                                  month.name[as.integer(format(d, "%m"))],
                                  "_", format(d, "%Y"))

  # Back_Content: the pre-2021 archive, in 16 batch folders rather than
  # months. Listed on demand, because it never changes.
  # A FAILED LISTING MUST NOT LOOK LIKE AN EMPTY ONE. Returning
  # character(0) on error would turn an expired credential, a network
  # outage or a permissions change into "the scope is empty" - the run
  # would skip every download, touch the heartbeat, and report success
  # having harvested nothing. That is the exact failure this file already
  # documents twice (the 16-hour underrun, and Back_Content being
  # invisible), so it is not repeated here: awsS3() already raises with a
  # useful message, and an EMPTY listing of a prefix that is supposed to
  # exist is itself an error worth stopping for.
  listPrefix <- function(prefix) {
    ls <- awsS3("ls", paste0(bucket, prefix, "/"))
    p <- sub("^\\s*PRE\\s+", "", trimws(ls[grepl("PRE ", ls)]))
    p <- sub("/$", "", p)
    p <- p[nzchar(p)]
    if (!length(p))
      stop("listed ", bucket, prefix, "/ and found no folders. The bucket ",
           "layout has changed, or the credential cannot see it. Refusing ",
           "to treat that as an empty scope.", call. = FALSE)
    p
  }

  backFolders <- function() paste0("Back_Content/", sort(listPrefix("Back_Content")))

  # WHICH MONTHS TO LIST - the fix for a silent 16-hour underrun.
  #
  # This listed the current + previous month ONLY, which is exactly right
  # for the nightly incremental job: catch the preprints that landed
  # today, and tolerate a month rollover. It is wrong for a BACKFILL, and
  # nothing said so. On 2026-08-27 an 18-hour bulk window consumed both
  # months in 1h55m, correctly reported "0 new", and stopped - having
  # touched 2 of the bucket's 72 month folders. The wrapper faithfully
  # concluded medRxiv was exhausted. It was not; the SCOPE was.
  #
  # The lesson is not "list everything by default": the nightly job
  # SHOULD stay narrow, because listing 72 folders every night to find
  # yesterday's papers is waste. The lesson is that the scope was
  # implicit, so a caller with a different intent could not express it
  # and could not see what they were getting.
  # BACK_CONTENT WAS INVISIBLE, and nothing said so. The bucket has TWO
  # top-level prefixes: Current_Content/ (72 month folders, 2021 onward)
  # and Back_Content/ (16 batch folders, everything before that). Every
  # scope this script offered - "recent", "all", a single month - built a
  # name of the form <Month>_<Year> and looked only under Current_Content.
  # So "all" meant "all of the part we knew about", the pre-2021 archive
  # was never listed, and a caller asking for a complete backfill got a
  # partial one that reported success. Same shape as the 16-hour underrun
  # fixed above: the scope was implicit, so it could not be seen.
  currentFolders <- function() {
    m <- listPrefix("Current_Content")
    # Newest first: a backfill interrupted halfway should have collected
    # the most recent papers, not the oldest.
    ord <- order(as.Date(paste0("01_", m), format = "%d_%B_%Y"),
                 decreasing = TRUE)
    paste0("Current_Content/", m[ord])
  }

  months <- if (identical(monthArg, "all")) {
    # Kept meaning Current_Content, so that existing callers and the
    # scheduled backfill behave exactly as before. Use "everything" for
    # the genuinely complete sweep.
    currentFolders()
  } else if (identical(monthArg, "back")) {
    backFolders()
  } else if (identical(monthArg, "everything")) {
    # Months first (newest first), then the archive - the recent
    # literature is worth more per byte than 2019.
    c(currentFolders(), backFolders())
  } else if (grepl("^(Back_Content|Current_Content)/", monthArg)) {
    # A fully-qualified folder name, so a caller partitioning the bucket
    # across several machines can pass exactly what it means without
    # translating dates back and forth.
    monthArg
  } else if (grepl("^[0-9]{4}-[0-9]{2}$", monthArg)) {
    d <- as.Date(paste0(monthArg, "-01"))
    monthName(d)
  } else {
    unique(c(monthName(Sys.Date()),
             monthName(seq(Sys.Date(), length = 2, by = "-1 month")[2])))
  }
  cat("month scope '", monthArg, "': ", length(months), " folder(s)
",
      sep = "")

  listing <- do.call(rbind, lapply(months, function(m) {
    ls <- tryCatch(awsS3("ls", paste0(bucket, m, "/")),
                   error = function(e) {
                     msg <- conditionMessage(e)
                     # Swallow ONLY "this folder is not there yet", which
                     # is normal near a month rollover. A credential
                     # problem, a throttle, a network drop or a changed
                     # permission must NOT be reported as an empty folder
                     # - that turns a broken run into a quiet one, which
                     # is how this harvest went three days without
                     # downloading anything and exited 0 each night.
                     # HOW A MISSING PREFIX ACTUALLY PRESENTS, which is not
                     # what the patterns above expect.
                     #
                     # `aws s3 ls` on a prefix that holds no objects prints
                     # NOTHING and exits 1. There is no NoSuchKey, no 404,
                     # no message of any kind - S3 has no concept of an
                     # absent "folder", so there is nothing to report. The
                     # error therefore arrives as the bare string
                     # "aws s3 failed: " with an empty tail, and none of the
                     # patterns above match it.
                     #
                     # Found live 2026-09-02, the first scheduled run after
                     # this job was created: on the 2nd of the month the
                     # "recent" scope asked for Current_Content/
                     # September_2026, which medRxiv had not created yet.
                     # The nightly died, and would have died on the 1st or
                     # 2nd of EVERY month until the folder appeared.
                     #
                     # Swallowing an EMPTY message is safe in exactly the way
                     # the comment above demands. Every failure that must not
                     # be silenced says something: "Unable to locate
                     # credentials", "An error occurred (AccessDenied)",
                     # "Could not connect to the endpoint URL", a throttle,
                     # an expired token. Silence is the one signal that only
                     # an empty prefix produces.
                     benign <- grepl("NoSuchBucket|NoSuchKey|Not Found|404",
                                     msg, ignore.case = TRUE) ||
                               grepl("^aws s3 failed:\\s*$", msg)
                     if (!benign) stop(e)
                     cat("  (", m, " not in the bucket yet - skipping)\n",
                         sep = "")
                     character(0)
                   })
    ls <- ls[grepl("[.]meca$", ls)]
    if (!length(ls)) return(NULL)
    parts <- strsplit(trimws(ls), "\\s+")
    data.frame(month = m,
               bytes = as.numeric(vapply(parts, `[`, "", 3)),
               name  = vapply(parts, `[`, "", 4),
               stringsAsFactors = FALSE)
  }))
  if (is.null(listing) || nrow(listing) == 0) {
    cat("no packages listed (empty month folders?) - skipping downloads\n")
    new <- NULL
  } else {
    new <- listing[!listing$name %in% manifest$meca, , drop = FALSE]
    cat(nrow(listing), "package(s) listed;", nrow(new), "new\n")
  }
  if (!is.null(new) && nrow(new) > 0) {
    new <- utils::head(new, maxFiles)

    # PREFIX SCREENING (2026-08-29). Before this, every listed package
    # was downloaded whole and classified after unpacking - and about
    # 97% of the bytes paid for were then discarded as non-RCT. The
    # JATS record sits in the FIRST zip entry, so a 64 KB ranged GET is
    # enough to run classifyRct() and skip the ones that cannot qualify.
    # See corpus/mecaPrefixScreen.R for the measurement (40/40 agreement
    # with this pipeline's own manifest) and the fail-open rule.
    #
    # BUDGET NOW MEANS ACTUAL EGRESS. maxGB used to be applied to the
    # LISTED size of candidates before any were fetched; with screening
    # the listed size is no longer what gets paid for, so the budget is
    # charged as the run proceeds - screen bytes plus full downloads.
    # maxFiles still caps packages CONSIDERED, so a caller wanting the
    # saving raises it: screening 2,000 costs roughly what downloading
    # 12 used to.
    screenOn <- !identical(Sys.getenv("INTEGRITY_MECA_SCREEN"), "0")
    bareBucket <- sub("^s3://([^/]+)/.*$", "\\1", bucket)
    keyPrefix  <- sub("^s3://[^/]+/", "", bucket)
    budgetBytes <- maxGB * 1024^3
    spent <- 0; nScreen <- 0L; nSkip <- 0L; nGet <- 0L; nUndecided <- 0L
    cat("considering ", nrow(new), " package(s); ",
        round(sum(new$bytes) / 1024^2), " MB if every one were downloaded",
        if (screenOn) " (screening first)" else " (screening DISABLED)",
        "\n", sep = "")
    for (i in seq_len(nrow(new))) {
      if (spent >= budgetBytes) {
        cat("budget reached after ", i - 1L, " package(s)\n", sep = ""); break
      }
      key <- paste0(keyPrefix, new$month[i], "/", new$name[i])
      scr <- if (screenOn)
        screenMecaPrefix(awsExe, profile, bareBucket, key) else
        list(decided = FALSE)
      if (screenOn) {
        nScreen <- nScreen + 1L
        spent <- spent + min(.mpsWindow, new$bytes[i])
      }
      if (isTRUE(scr$decided) && !isTRUE(scr$isRct)) {
        # Recorded so the package is never reconsidered. `bytes` keeps
        # its meaning - the package's size - even though we did not pay
        # for all of it; what was actually spent is reported per run.
        manifest <- rbind(manifest, data.frame(
          meca = new$name[i], doi = scr$doi, verdict = "not-rct",
          license = substr(gsub("[\r\n,]+", " ", scr$license), 1, 60),
          title = scr$title, pdf = NA_character_,
          bytes = as.character(new$bytes[i]),
          date = format(Sys.Date()), stringsAsFactors = FALSE))
        saveManifest()
        nSkip <- nSkip + 1L
        next
      }
      if (!isTRUE(scr$decided)) nUndecided <- nUndecided + 1L
      dst <- file.path(incoming, new$name[i])
      if (!file.exists(dst))
        tryCatch({
          awsS3("cp", paste0(bucket, new$month[i], "/", new$name[i]),
                dst, "--only-show-errors")
          spent <- spent + new$bytes[i]
          nGet <- nGet + 1L
        }, error = function(e) message("download failed: ",
                                       new$name[i], " - ",
                                       conditionMessage(e)))
      Sys.sleep(1)
    }
    if (screenOn)
      cat(sprintf(paste0("screened %d, skipped %d as non-RCT without ",
                         "downloading, fetched %d (%d undecided)\n"),
                  nScreen, nSkip, nGet, nUndecided))
    cat(sprintf("egress this run: %.0f MB (budget %.0f MB)\n",
                spent / 1024^2, budgetBytes / 1024^2))
  }
}

# ---- phase 2: unpack, classify, file ------------------------------------
mecas <- list.files(incoming, pattern = "[.]meca$", full.names = TRUE)
cat(length(mecas), "package(s) in incoming\n")
kept <- 0L; dropped <- 0L; failed <- 0L
for (m in mecas) {
  ex <- file.path(tempdir(), paste0("meca", basename(tempfile(""))))
  res <- tryCatch({
    utils::unzip(m, exdir = ex)
    xmls <- list.files(file.path(ex, "content"), pattern = "[.]xml$",
                       full.names = TRUE)
    xmls <- xmls[!grepl("manifest|transfer|directives", xmls)]
    if (!length(xmls)) stop("no JATS XML in package")
    jats <- read_xml(xmls[which.max(file.size(xmls))])
    doi <- xml_text(xml_find_first(jats,
      ".//front//article-id[@pub-id-type='doi']"))
    title <- xml_text(xml_find_first(jats, ".//front//article-title"))
    abstract <- paste(xml_text(xml_find_all(jats, ".//front//abstract//p")),
                      collapse = " ")
    lic <- xml_text(xml_find_first(jats, ".//front//license"))
    pdfs <- list.files(file.path(ex, "content"), pattern = "[.]pdf$",
                       full.names = TRUE)
    isRct <- classifyRct(title, abstract)
    pdfOut <- NA_character_
    if (isRct && length(pdfs)) {
      pdfOut <- paste0(gsub("/", "_", doi), ".pdf")
      # the MAIN manuscript pdf is the largest; supplements are smaller
      file.copy(pdfs[which.max(file.size(pdfs))],
                file.path(outDir, pdfOut), overwrite = TRUE)
    }
    list(doi = doi, verdict = if (isRct) "rct" else "not-rct",
         title = substr(gsub("[\r\n,]+", " ", title), 1, 120),
         license = substr(gsub("[\r\n,]+", " ", lic), 1, 60),
         pdf = pdfOut)
  }, error = function(e) list(doi = NA_character_,
                              verdict = paste0("ERROR: ",
                                               conditionMessage(e)),
                              title = "", license = "",
                              pdf = NA_character_))
  manifest <- rbind(manifest, data.frame(
    meca = basename(m), doi = res$doi, verdict = res$verdict,
    license = res$license, title = res$title,
    pdf = res$pdf, bytes = as.character(file.size(m)),
    date = format(Sys.Date()), stringsAsFactors = FALSE))
  saveManifest()
  if (identical(res$verdict, "rct")) kept <- kept + 1L
  else if (startsWith(res$verdict, "ERROR")) failed <- failed + 1L
  else dropped <- dropped + 1L
  unlink(ex, recursive = TRUE, force = TRUE)
  unlink(m)   # processed - the manifest remembers it; disk stays bounded
}
cat(sprintf("\nprocessed %d package(s): %d RCT pdf(s) kept, %d non-RCT, %d error(s)\n",
            length(mecas), kept, dropped, failed))
nPdf <- length(list.files(outDir, pattern = "[.]pdf$"))
cat("corpus now holds", nPdf, "PDF(s)\n")

# ---- heartbeat (Steve's request, 2026-08-26) ----------------------------
# Every scheduled job on this machine is invisible when it stops: a
# harvest that dies at 2 AM - expired AWS session, network, a change
# upstream - would go unnoticed for weeks. Append one line per run; the
# 03:00 backup task checks this file's age and complains into the
# OneDrive-synced backup log if it is stale. Written LAST, so the line
# means "the run completed", not "the run started".
tryCatch({
  hb <- file.path(outDir, "heartbeat.log")
  cat(sprintf("%s  processed=%d kept=%d dropped=%d errors=%d corpus=%d\n",
              format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
              length(mecas), kept, dropped, failed, nPdf),
      file = hb, append = TRUE)
}, error = function(e) message("heartbeat write failed: ",
                               conditionMessage(e)))
