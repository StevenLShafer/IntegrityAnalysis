# blandAltman.R - do the two instruments agree well enough to substitute
# for one another?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request: "Can you graph a bland-altman plot of the limits of    #
# agreement between the Carlisle-Shafer approach and the Barnett          #
# approach". LOCAL CORPUS TOOLING ONLY.                                    #
#                                                                          #
# THE SCALE PROBLEM, which has to be solved before a Bland-Altman plot     #
# means anything. Bland and Altman compare two measurements of THE SAME    #
# QUANTITY IN THE SAME UNITS. These two methods report neither:            #
#                                                                          #
#   Carlisle-Shafer  a trial p-value, one-sided toward homogeneity         #
#   Barnett          a posterior probability of dispersion, plus epsilon,  #
#                    a log multiplier on the precision                     #
#                                                                          #
# Differencing a p-value against a posterior probability would produce a   #
# picture with limits of agreement in it and no meaning. Both are          #
# therefore mapped onto ONE scale first: signed standardised evidence of   #
# under-dispersion, in standard deviations, positive when the arms are     #
# MORE alike than randomisation predicts.                                  #
#                                                                          #
#   ours     z = qnorm(1 - p). The p is already one-sided toward           #
#            homogeneity, so this is just its probit. p = 0.5 gives 0.     #
#                                                                          #
#   Barnett  his model's entire content is that the t-statistics of an     #
#            honest table have the spread a t-distribution predicts. Push  #
#            each t through its own distribution function and then through #
#            the normal quantile - the probability integral transform -    #
#            and under the null those k values are EXACTLY standard        #
#            normal, whatever the degrees of freedom. Their sum of squares #
#            is then exactly chi-square on k, and                          #
#                                                                          #
#                p = P(chi-square on k <= observed sum of squares)         #
#                                                                          #
#            is a one-sided p for excess homogeneity - the SAME quantity   #
#            our p measures, in the same units and the same direction.     #
#            This is his statistic expressed as a p, not his published     #
#            output, which is a posterior probability; the correlation     #
#            with his own epsilon is reported so the substitution can be   #
#            judged rather than assumed.                                   #
#                                                                          #
# MATCHING THE RESOLUTION, which a first version of this script got wrong  #
# and which changed the whole picture. Our p is a MONTE CARLO p: floored   #
# at 1/(m+1) and capped at 0.9999, so its probit cannot leave about -3.7   #
# to +4.4. Barnett's has no such floor, and the registry's data-entry      #
# errors give some trials t-statistics in the hundreds, so his z reached   #
# -230. Differencing a bounded measurement against an unbounded one        #
# produces a Bland-Altman plot that measures nothing but the bound: the    #
# difference becomes minus the unbounded term and the points fall on a     #
# straight diagonal, which is exactly what the first plot showed.          #
#                                                                          #
# A method cannot be asked to agree beyond the resolution of the           #
# instrument it is compared against. Barnett's p is therefore clipped to   #
# OUR floor and cap before either is probit-transformed. How often that    #
# clipping binds is reported, because it is a real limitation of ours and  #
# not a nuisance to be hidden.                                             #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/blandAltman.R [outDir] [outPng]                         #
############################################################################

args   <- commandArgs(trailingOnly = TRUE)
outDir <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
outPng <- if (length(args) >= 2) args[2] else
  file.path(outDir, "blandAltman.png")

ts  <- utils::read.csv(file.path(outDir, "tStatsByVariable.csv"),
                       stringsAsFactors = FALSE)
b   <- utils::read.csv(file.path(outDir, "barnett.csv"),
                       stringsAsFactors = FALSE)
scr <- utils::read.csv(file.path(outDir, "screened.csv"),
                       stringsAsFactors = FALSE)
scr$P <- suppressWarnings(as.numeric(scr$P))

## ---- Barnett's statistic, standardised -----------------------------------
ts <- ts[is.finite(ts$t) & is.finite(ts$df) & ts$df > 0, ]
# Probability integral transform. Clipped away from 0 and 1 so that a
# single absurd t - and the corpus has them, from registry data-entry
# errors - cannot become an infinite z and destroy its trial's sum.
u <- stats::pt(ts$t, df = ts$df)
u <- pmin(pmax(u, 1e-12), 1 - 1e-12)
ts$z <- stats::qnorm(u)
agg <- stats::aggregate(cbind(ss = ts$z^2, k = rep(1, nrow(ts))) ~ TRIAL,
                        data = ts, FUN = sum)
# One-sided p for excess homogeneity: the probability of a spread this
# small or smaller. Small p = arms too alike, exactly as ours reads.
agg$pBarnett <- stats::pchisq(agg$ss, df = agg$k)

## ---- join ----------------------------------------------------------------
m <- merge(agg, scr[, c("NCT", "P")], by.x = "TRIAL", by.y = "NCT")
m <- merge(m, b[, c("TRIAL", "epsilon", "pDispersed", "nStat")], by = "TRIAL")
m <- m[is.finite(m$P) & m$k >= 3 & is.finite(m$pBarnett), ]

# Our Monte Carlo floor and cap ARE the resolution of this comparison.
PLO <- 1 / (100000 + 1); PHI <- 0.9999
clipB <- mean(m$pBarnett < PLO | m$pBarnett > PHI)
m$zCS <- stats::qnorm(1 - pmin(pmax(m$P, PLO), PHI))
m$zBarnett <- stats::qnorm(1 - pmin(pmax(m$pBarnett, PLO), PHI))
m <- m[is.finite(m$zCS) & is.finite(m$zBarnett), ]
cat("trials with both answers:", nrow(m), "\n")
cat(sprintf("Barnett clipped to our resolution: %.2f%% of trials\n",
            100 * clipB))

avg <- (m$zCS + m$zBarnett) / 2
dif <- m$zCS - m$zBarnett
bias <- mean(dif); sdd <- stats::sd(dif)
loLo <- bias - 1.96 * sdd; loHi <- bias + 1.96 * sdd

cat(sprintf("\nbias (ours - Barnett): %+.3f SD\n", bias))
cat(sprintf("SD of differences    : %.3f\n", sdd))
cat(sprintf("95%% limits of agreement: %+.3f to %+.3f\n", loLo, loHi))
cat(sprintf("outside the limits   : %.2f%% (5%% expected if normal)\n",
            100 * mean(dif < loLo | dif > loHi)))
cat(sprintf("Pearson  r(zCS, zBarnett): %+.3f\n",
            stats::cor(m$zCS, m$zBarnett)))
cat(sprintf("Spearman r(zCS, zBarnett): %+.3f\n",
            stats::cor(m$zCS, m$zBarnett, method = "spearman")))
cat(sprintf("Spearman r(zBarnett, his epsilon): %+.3f  <- is the\n",
            stats::cor(m$zBarnett, m$epsilon, method = "spearman")))
cat("   standardisation faithful to his own output?\n")
capped <- mean(m$P >= 0.9999 | m$P <= 1e-4)
cat(sprintf("\ntrials pinned at one of our p caps: %.2f%%\n", 100 * capped))

## ---- plot ----------------------------------------------------------------
grDevices::png(outPng, width = 1500, height = 820, res = 130)
graphics::par(mfrow = c(1, 2), mar = c(5.6, 4.6, 3.4, 1.2), bg = "white")

dens <- grDevices::rgb(0.13, 0.29, 0.55, 0.10)
# Trials where one method is pinned at the shared resolution limit are
# drawn apart. They are the diagonal streaks, and leaving them
# unexplained would invite them to be read as structure in the data.
pin  <- m$P <= PLO | m$P >= PHI | m$pBarnett <= PLO | m$pBarnett >= PHI
pinC <- grDevices::rgb(0.75, 0.35, 0.05, 0.35)

# Panel A - the two measurements against each other.
plot(m$zBarnett, m$zCS, pch = 16, cex = 0.30,
     col = ifelse(pin, pinC, dens),
     xlab = "Barnett  (z, + = arms too alike)",
     ylab = "Carlisle-Shafer  (z, + = arms too alike)",
     main = "A. The same trials, both instruments")
graphics::abline(0, 1, col = "grey35", lwd = 1.4, lty = 2)
graphics::abline(h = 0, v = 0, col = "grey80", lwd = 0.8)
graphics::legend("topleft", bty = "n", cex = 0.82,
  legend = c(sprintf("n = %s trials", format(nrow(m), big.mark = ",")),
             sprintf("Pearson r = %+.3f", stats::cor(m$zCS, m$zBarnett)),
             "dashed = line of identity",
             sprintf("orange = at a resolution limit (%.1f%%)",
                     100 * mean(pin))))

# Panel B - Bland and Altman proper.
plot(avg, dif, pch = 16, cex = 0.30, col = ifelse(pin, pinC, dens),
     xlab = "mean of the two z-scores",
     ylab = "difference  (Carlisle-Shafer  -  Barnett)",
     main = "B. Bland-Altman: limits of agreement")
graphics::abline(h = bias, col = "#B22222", lwd = 2)
graphics::abline(h = c(loLo, loHi), col = "#B22222", lwd = 1.6, lty = 2)
graphics::abline(h = 0, col = "grey80", lwd = 0.8)
usr <- graphics::par("usr")
graphics::text(usr[2], bias, sprintf(" bias %+.2f", bias), adj = c(1, -0.5),
               col = "#B22222", cex = 0.8)
graphics::text(usr[2], loHi, sprintf(" +1.96 SD  %+.2f", loHi),
               adj = c(1, -0.5), col = "#B22222", cex = 0.8)
graphics::text(usr[2], loLo, sprintf(" -1.96 SD  %+.2f", loLo),
               adj = c(1, 1.3), col = "#B22222", cex = 0.8)
graphics::mtext(sprintf("limits of agreement span %.2f SD", loHi - loLo),
                side = 1, line = 3.5, cex = 0.80, col = "grey25")
graphics::mtext("correlated, but not interchangeable",
                side = 1, line = 4.5, cex = 0.80, col = "grey25")

grDevices::dev.off()
cat("\nwritten:", outPng, "\n")
utils::write.csv(m[, c("TRIAL", "k", "zCS", "zBarnett", "epsilon",
                       "pDispersed", "P")],
                 file.path(outDir, "blandAltman.csv"), row.names = FALSE)
