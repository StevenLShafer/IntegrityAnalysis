# checkCapacity.R - report shinyapps.io active-hours usage against the plan.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-26 by Claude (Claude Code, model Claude Opus 5) at Steve  #
# Shafer's request: "I am also concerned about shinyapps.io server         #
# bandwidth / computing allocation limitations. Should we perhaps have a   #
# message if shinyapps.io is too busy to handle more requests?"           #
#                                                                          #
# THE HONEST ANSWER TO THAT QUESTION, recorded here because it shapes what #
# this script does and does not do:                                        #
#                                                                          #
# The app CANNOT show its own "too busy" page. When shinyapps.io is at     #
# its connection or instance limit, Posit's proxy answers the browser      #
# before our R process is ever reached - there is nothing for our code to  #
# render. Likewise when the monthly ACTIVE HOURS allowance is exhausted:   #
# the application is simply taken offline by the platform, and a visitor   #
# sees Posit's page, not ours.                                            #
#                                                                          #
# So the useful intervention is not a message - it is knowing BEFORE the   #
# cliff. This script sums the active hours the account has consumed in     #
# the current calendar month and warns as the plan limit approaches. The   #
# nightly backup task runs it and appends the result to the backup log in  #
# OneDrive, so the warning is visible from any device (same philosophy as  #
# the harvest heartbeat: a resource that runs out silently is the          #
# dangerous kind).                                                        #
#                                                                          #
# If the warning fires during outreach, the fix is a plan upgrade in the   #
# shinyapps.io dashboard - minutes of work, and cheap next to an editor    #
# finding the app offline.                                                #
#                                                                          #
# INTEGRITY_SHINY_HOURS sets the monthly allowance (default 500, the       #
# Starter plan). Set it to match whatever plan is current.                 #
############################################################################

suppressPackageStartupMessages(library(rsconnect))

limit <- suppressWarnings(as.numeric(
  Sys.getenv("INTEGRITY_SHINY_HOURS", "500")))
if (is.na(limit) || limit <= 0) limit <- 500

usage <- tryCatch(rsconnect::accountUsage(usageType = "hours"),
                  error = function(e) NULL)
if (is.null(usage) || is.null(usage$points)) {
  cat("CAPACITY: could not read shinyapps usage",
      "(not authenticated, or the API changed)\n")
  quit(status = 0)
}

# points: per application, a list of [epoch_ms, hours] pairs
monthStart <- as.numeric(as.POSIXct(format(Sys.Date(), "%Y-%m-01"),
                                    tz = "UTC")) * 1000
total <- 0
perApp <- list()
for (app in names(usage$points)) {
  pts <- usage$points[[app]]
  h <- 0
  for (p in pts) {
    if (length(p) < 2) next
    ts <- suppressWarnings(as.numeric(p[[1]]))
    hr <- suppressWarnings(as.numeric(p[[2]]))
    if (!is.na(ts) && !is.na(hr) && ts >= monthStart) h <- h + hr
  }
  perApp[[app]] <- h
  total <- total + h
}

pct <- 100 * total / limit
cat(sprintf("CAPACITY: %.1f active hours used this month across the ACCOUNT",
            total), sprintf("(assuming a %.0f-hour plan: %.0f%%)\n",
                            limit, pct))
# Per-app, because the allowance is shared: measured 2026-08-26, nearly
# all of this account's hours belong to stanpumpR (a different project,
# under active development by Dean Attali), not IntegrityAnalysis. A
# busy neighbour can exhaust the allowance and take THIS app offline,
# which is why the per-app split is printed rather than just the total.
for (app in names(perApp))
  if (perApp[[app]] > 0.05)
    cat(sprintf("   %s: %.1f h\n", app, perApp[[app]]))

if (pct >= 80) {
  cat("CAPACITY WARNING: at or beyond 80% of the ASSUMED",
      sprintf("%.0f-hour allowance.", limit),
      "Confirm the real plan limit in the shinyapps.io dashboard and set",
      "INTEGRITY_SHINY_HOURS to match. When the allowance runs out,",
      "shinyapps.io takes the applications OFFLINE and visitors see",
      "Posit's page - the app cannot show a message of its own.",
      "The allowance is shared across every app on the account.\n")
} else if (pct >= 60) {
  cat("CAPACITY NOTE: over 60% of the assumed allowance used; watch it",
      "if outreach is under way.\n")
}
