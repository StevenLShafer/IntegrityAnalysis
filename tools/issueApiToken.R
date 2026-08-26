# issueApiToken.R - issue, revoke, and sync API bearer tokens (issue 1).
#
# PROVENANCE: written 2026-08-26 by Claude Code (model Claude Fable 5)
# to Steve's design: "we need a software mechanism for that, perhaps in
# a private repository on GitHub." The MECHANISM is this public script;
# the DATA is a private registry repository
# (github.com/StevenLShafer/IntegrityAnalysis-operations) that stores
# only SHA-256 hashes - a token exists in plaintext exactly once, on
# the operator's screen at issuance, to be handed to the partner. Even
# the private registry leaking would compromise nothing.
#
# The deployed service (AWS App Runner) receives the ACTIVE hashes in
# its INTEGRITY_API_TOKENS environment variable as "sha256:<hex>"
# entries; .apiAuthorized() hashes what a caller presents and compares.
# Revocation is flipping a registry row and re-syncing (~1 minute
# App Runner configuration redeploy).
#
# Usage (from the package root; the registry clone location comes from
# the INTEGRITY_OPS_DIR environment variable, default
# C:/dev/IntegrityAnalysis-operations):
#   Rscript tools/issueApiToken.R issue  "Partner name" "contact@email"
#   Rscript tools/issueApiToken.R revoke "Partner name"
#   Rscript tools/issueApiToken.R list
#   Rscript tools/issueApiToken.R sync      # push active hashes to AWS
#
# issue/revoke commit and push the registry, then sync automatically.

opsDir <- Sys.getenv("INTEGRITY_OPS_DIR", "C:/dev/IntegrityAnalysis-operations")
regPath <- file.path(opsDir, "tokens.csv")
serviceArn <- Sys.getenv("INTEGRITY_API_SERVICE_ARN", "")
awsProfile <- Sys.getenv("INTEGRITY_AWS_PROFILE", "steve")
awsRegion  <- "us-east-1"
imageId <- "196253397540.dkr.ecr.us-east-1.amazonaws.com/integrityanalysis-api:latest"
accessRole <- "arn:aws:iam::196253397540:role/IntegrityAnalysisAppRunnerECR"

awsExe <- local({
  p <- Sys.which("aws")
  if (nzchar(p)) return(p)
  cand <- file.path(Sys.getenv("LOCALAPPDATA"),
                    "Programs/Amazon/AWSCLIV2/aws.exe")
  if (file.exists(cand)) return(cand)
  "C:/Program Files/Amazon/AWSCLIV2/aws.exe"
})

readReg <- function() {
  if (!file.exists(regPath))
    return(data.frame(partner = character(), contact = character(),
                      sha256 = character(), issued = character(),
                      status = character(), notes = character(),
                      stringsAsFactors = FALSE))
  read.csv(regPath, colClasses = "character")
}
writeReg <- function(reg, msg) {
  write.csv(reg, regPath, row.names = FALSE)
  system2("git", c("-C", opsDir, "add", "tokens.csv"))
  system2("git", c("-C", opsDir, "commit", "-q", "-m", shQuote(msg)))
  system2("git", c("-C", opsDir, "push", "-q"))
}

syncAws <- function(reg) {
  active <- reg$sha256[reg$status == "active"]
  value <- paste(paste0("sha256:", active), collapse = ",")
  if (!nzchar(serviceArn)) {
    arn <- system2(awsExe, c("apprunner", "list-services", "--profile",
                             awsProfile, "--region", awsRegion, "--query",
                             shQuote(paste0("ServiceSummaryList[?ServiceName==",
                                            "'integrityanalysis-api'].ServiceArn")),
                             "--output", "text"), stdout = TRUE)
    serviceArn <- trimws(arn[1])
  }
  cfg <- sprintf(paste0(
    '{"ImageRepository":{"ImageIdentifier":"%s",',
    '"ImageRepositoryType":"ECR","ImageConfiguration":{"Port":"8080",',
    '"RuntimeEnvironmentVariables":{"INTEGRITY_API_TOKENS":"%s"}}},',
    '"AuthenticationConfiguration":{"AccessRoleArn":"%s"},',
    '"AutoDeploymentsEnabled":true}'), imageId, value, accessRole)
  cfgFile <- tempfile(fileext = ".json")
  writeLines(cfg, cfgFile)
  out <- system2(awsExe, c("apprunner", "update-service", "--service-arn",
                           serviceArn, "--source-configuration",
                           paste0("file://", cfgFile), "--profile",
                           awsProfile, "--region", awsRegion, "--query",
                           "'Service.Status'", "--output", "text"),
                 stdout = TRUE, stderr = TRUE)
  cat("sync:", length(active), "active token hash(es) pushed;",
      "service:", trimws(paste(out, collapse = " ")), "\n")
}

args <- commandArgs(trailingOnly = TRUE)
cmd <- if (length(args) >= 1) args[1] else "list"
reg <- readReg()

if (cmd == "issue") {
  stopifnot(length(args) >= 2)
  partner <- args[2]
  contact <- if (length(args) >= 3) args[3] else ""
  token <- paste0("ia_", paste(format(as.hexmode(as.integer(
    openssl::rand_bytes(32))), width = 2), collapse = ""))
  h <- digest::digest(token, algo = "sha256", serialize = FALSE)
  reg <- rbind(reg, data.frame(
    partner = partner, contact = contact, sha256 = h,
    issued = format(Sys.Date()), status = "active", notes = "",
    stringsAsFactors = FALSE))
  writeReg(reg, paste("issue:", partner))
  cat("\n=== TOKEN (shown once - hand to the partner now) ===\n",
      token, "\n=====================================================\n\n")
  syncAws(reg)
} else if (cmd == "revoke") {
  stopifnot(length(args) >= 2)
  hit <- reg$partner == args[2] & reg$status == "active"
  if (!any(hit)) stop("no active token for partner: ", args[2])
  reg$status[hit] <- "revoked"
  reg$notes[hit] <- paste("revoked", format(Sys.Date()))
  writeReg(reg, paste("revoke:", args[2]))
  syncAws(reg)
} else if (cmd == "sync") {
  syncAws(reg)
} else {
  print(reg[, c("partner", "issued", "status")], row.names = FALSE)
}
