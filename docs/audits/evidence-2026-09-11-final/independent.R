# Re-executed against the final brief commit, Codex, 2026-09-11.
# Independent references for the full audit. Codex, 2026-09-10.
# No production statistic/ranking helper is used to obtain expectations.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
cat_frame <- function(tab, label = 'Category') {
  d <- data.frame(TRIAL = 'Audit', ROW = label, N = NA_real_, MEAN = NA_real_, SD = NA_real_)
  d <- d[rep(1, nrow(tab)), ]
  cbind(d, setNames(as.data.frame(tab), paste0('CAT', seq_len(ncol(tab)))))
}
ci_contains <- function(ci, p) {
  if (is.na(ci) || !nzchar(ci)) return(NA)
  lim <- as.numeric(strsplit(ci, ' to ', fixed = TRUE)[[1]])
  p >= lim[1] && p <= lim[2]
}
records <- list()
record <- function(id, d, expected, seed = 42, m = 100000) {
  write.csv(d, file.path(out, paste0('fixture-', id, '.csv')), row.names = FALSE)
  r <- run_engine(d, seed, m)
  write.csv(r, file.path(out, paste0('result-', id, '.csv')), row.names = FALSE)
  s <- r[which(r$KIND == 'summary')[1], ]
  records[[id]] <<- data.frame(case = id, seed = seed, ceiling = m,
    actual_M = max(as.numeric(r$M), na.rm = TRUE), p = s$P,
    CI95 = s$CI95, reference = expected, reference_inside_reported_CI = ci_contains(s$CI95, expected))
  write.csv(do.call(rbind, records), file.path(out, 'independent-comparisons.csv'), row.names = FALSE)
  cat(id, 'p', s$P, 'CI', s$CI95, 'reference', expected, '\n'); flush.console()
  invisible(r)
}
# Enumerate every feasible first column for R x 2 tables. The mass follows
# counting allocations: prod choose(arm N, first-cell count) / choose(total, C).
# Small integer inputs: rounding only groups floating representations of the
# same rational Pearson statistic, eleven digits below support separation.
exact_rx2 <- function(tab) {
  n <- rowSums(tab); C <- sum(tab[, 1]); total <- sum(n)
  x <- as.matrix(expand.grid(lapply(n, function(ni) 0:ni)))
  x <- x[rowSums(x) == C, , drop = FALSE]
  E <- n * C / total
  stat <- rowSums(sweep(x, 2, E, '-')^2 *
                   matrix(rep(1/E + 1/(n-E), each = nrow(x)), nrow(x)))
  prob <- exp(rowSums(sapply(seq_along(n), function(j) lchoose(n[j], x[, j]))) - lchoose(total, C))
  obs <- sum((tab[, 1] - E)^2 * (1/E + 1/(n-E)))
  stat <- round(stat, 11); obs <- round(obs, 11)
  stopifnot(abs(sum(prob)-1) < 1e-12)
  list(p = sum(prob[stat < obs]) + sum(prob[stat == obs])/2,
       distribution = data.frame(statistic = stat, probability = prob))
}
cats <- list(two_equal = rbind(c(1,1), c(1,1)), two_unequal = rbind(c(1,2), c(2,5)),
  three_tie = rbind(c(1,1), c(1,1), c(1,5)), three_off = rbind(c(0,2),c(2,2),c(3,4)),
  four_arms = rbind(c(1,2),c(2,1),c(2,3),c(1,3)),
  two_by_three = t(rbind(c(1,1),c(1,1),c(1,5))))
for (id in names(cats)) {
  tab <- cats[[id]]
  ref <- exact_rx2(if (ncol(tab) == 2) tab else t(tab))
  write.csv(ref$distribution, file.path(out, paste0('exact-law-', id, '.csv')), row.names = FALSE)
  record(id, cat_frame(tab), ref$p)
}
# Continuous fine-grid limits: the mean difference divided by its pooled
# sample SE has t(df); the lower-tail square has F(1, df). For equal N and
# three arms, SSD / ((k-1)*pooledVariance/N) has F(k-1, sum(N)-k).
continuous <- list(small = list(n=c(3,3), mu=c(0,0.2), sd=c(1,1)),
  unequal = list(n=c(5,17), mu=c(0,0.02), sd=c(1,2)),
  direct = list(n=c(100,125), mu=c(0,0.0008), sd=c(1,1)),
  three = list(n=rep(10,3), mu=c(-0.02,0,0.02), sd=rep(1,3)))
for (id in names(continuous)) {
  a <- continuous[[id]]; df <- sum(a$n)-length(a$n)
  v <- sum((a$n-1)*a$sd^2)/df
  fstat <- if (length(a$n)==2) diff(a$mu)^2/(v*sum(1/a$n)) else
    sum((a$mu-mean(a$mu))^2)/(v/a$n[1]*(length(a$n)-1))
  ref <- pf(fstat, length(a$n)-1, df)
  d <- data.frame(TRIAL='Audit', ROW='Continuous', N=a$n, MEAN=a$mu, SD=a$sd,
    ROUND_MEAN=6, ROUND_OBSERVATION=6, ROUND_DISPERSION=6)
  record(paste0('F-',id), d, ref)
}
# Exact combination at a tie: each 2x2 table has probability 2/3 of
# [[1,1],[1,1]] and 1/3 of the two extreme tables together. All rows have
# the SAME two possible mid-p values (1/3, 5/6), hence Stouffer's sum is
# a monotone function of the number of homogeneous rows, G~Bin(J, 2/3).
for (J in c(5,15,16)) for (bad in c(0,1)) {
  g <- J-bad
  d <- do.call(rbind, lapply(seq_len(J), function(j)
    cat_frame(if (j <= bad) rbind(c(0,2),c(2,0)) else rbind(c(1,1),c(1,1)), sprintf('V%02d',j))))
  ref <- pbinom(g,J,2/3,lower.tail=FALSE)+dbinom(g,J,2/3)/2
  record(paste0('combination-',J,'-',bad), d, ref)
}
writeLines('Independent reference pass completed.', file.path(out, 'independent-complete.txt'))
