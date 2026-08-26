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
#     packages into <outDir>/incoming. Uses the aws CLI with profile      #
#     "steve" (Identity Center; the session refreshes itself for ~90     #
#     days - when it finally expires this phase logs one clear line       #
#     telling Steve to run `aws sso login --profile steve` and exits      #
#     without touching the manifest).                                      #
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
############################################################################

suppressPackageStartupMessages({library(xml2)})

scriptDir <- dirname(sub("--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[1]))
source(file.path(scriptDir, "rctFilterPatterns.R"))

args     <- commandArgs(trailingOnly = TRUE)
maxFiles <- if (length(args) >= 1) as.integer(args[1]) else 100L
maxGB    <- if (length(args) >= 2) as.numeric(args[2]) else 2
outDir   <- if (length(args) >= 3) args[3] else "C:/temp/medrxiv_rct"
incoming <- file.path(outDir, "incoming")
dir.create(incoming, showWarnings = FALSE, recursive = TRUE)

bucket  <- "s3://medrxiv-src-monthly/Current_Content/"
profile <- "steve"
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
      stop("AWS credentials need a refresh: run  aws sso login --profile ",
           profile, "  and re-run this script.", call. = FALSE)
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
  monthName <- function(d) paste0(month.name[as.integer(format(d, "%m"))],
                                  "_", format(d, "%Y"))
  m1 <- monthName(Sys.Date())
  m2 <- monthName(seq(Sys.Date(), length = 2, by = "-1 month")[2])
  listing <- do.call(rbind, lapply(unique(c(m1, m2)), function(m) {
    ls <- tryCatch(awsS3("ls", paste0(bucket, m, "/")),
                   error = function(e) {
                     if (grepl("sso login", conditionMessage(e)))
                       stop(e)
                     character(0)  # month folder may not exist yet
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
    new <- new[cumsum(new$bytes) <= maxGB * 1024^3, , drop = FALSE]
    new <- utils::head(new, maxFiles)
    cat("downloading", nrow(new), "package(s), ",
        round(sum(new$bytes) / 1024^2), "MB\n")
    for (i in seq_len(nrow(new))) {
      dst <- file.path(incoming, new$name[i])
      if (!file.exists(dst))
        tryCatch(awsS3("cp", paste0(bucket, new$month[i], "/", new$name[i]),
                       dst, "--only-show-errors"),
                 error = function(e) message("download failed: ",
                                             new$name[i], " - ",
                                             conditionMessage(e)))
      Sys.sleep(1)
    }
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
cat("corpus now holds", length(list.files(outDir, pattern = "[.]pdf$")),
    "PDF(s)\n")
