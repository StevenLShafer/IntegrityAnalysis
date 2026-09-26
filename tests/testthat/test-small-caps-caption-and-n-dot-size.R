# test-small-caps-caption-and-n-dot-size.R - a "Table" set in small capitals
# and split by the text layer into "T" + "able" is one word, and "(N.=50)"
# is an arm size (ISSUES.md issue 147, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# Loadsman corpus (Altinsoy 2015, Minerva Anestesiologica; two arms of 50): #
# "T" at (58, 530) and "able" at (63, 533), "Group C (N.=50) Group S        #
# (N.=50)", rows "Age (yr) 43.4+/-16.7 47.3+/-15.9 0.232"; the engine found  #
# no caption on the page and no usable table in the paper.                 #
############################################################################

pm <- "\u00b1"

test_that("a caption number ending in the journal's dash is an anchor", {
  w <- data.frame(text = c("Table", "I.\u2014", "Demographic", "data."), x = c(58, 83, 98, 150), y = 530,
                  width = c(22, 16, 50, 18), height = 11, stringsAsFactors = FALSE)
  expect_identical(nrow(.ppCaptionAnchors(w)), 1L)
})

test_that("a lone capital flush against a lower-case word on a nearby baseline is one word", {
  w <- data.frame(text = c("T", "able", "I.", "Demographic", "Age", "I", "II"),
                  x = c(58, 63, 83, 98, 58, 200, 200), y = c(530, 533, 530, 530, 567, 567, 580),
                  width = c(5, 17, 6, 50, 13, 3, 6), height = c(11, 8, 11, 11, 10, 10, 10),
                  stringsAsFactors = FALSE)
  j <- .ppJoinSmallCaps(w)
  expect_identical(j$text, c("Table", "I.", "Demographic", "Age", "I", "II"))
  expect_identical(j$width[1], 22)
  expect_identical(j$y[1], 530)
  # a capital on its own line ("I" of a roman numeral) is left alone, and
  # so is a capital a gap away from the next word
  w2 <- data.frame(text = c("A", "bright", "T", "he"), x = c(58, 70, 100, 104), y = c(100, 100, 200, 210),
                   width = c(6, 25, 6, 10), height = c(10, 10, 10, 10), stringsAsFactors = FALSE)
  expect_identical(.ppJoinSmallCaps(w2)$text, c("A", "bright", "T", "he"))
})

minervaPdf <- function(file = file.path(tempdir(), "minerva.pdf")) {
  vx <- c(271, 364)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells, p) c(list(w(58, y, label)), lapply(1:2, function(k) w(vx[k], y, cells[k])), list(w(446, y, p)))
  cells <- c(
    list(w(58, 530, "T"), w(64, 533, "able"), w(84, 530, "I.\u2014"), w(102, 530, "Demographic data.")),
    list(w(262, 547, "Group C (N.=50)"), w(356, 547, "Group S (N.=50)"), w(453, 551, "P")),
    list(w(270, 554, paste0("(Mean", pm, "SD)")), w(363, 554, paste0("(Mean ", pm, "SD)"))),
    row(567, "Age (yr)", c(paste0("43.4", pm, "16.7"), paste0("47.3", pm, "15.9")), "0.232"),
    row(576, "Length (cm)", c(paste0("170.9", pm, "9.1"), paste0("170.4", pm, "7.5")), "0.774"),
    row(584, "Weight (kg)", c(paste0("76.5", pm, "12.2"), paste0("78.8", pm, "13")), "0.382"),
    row(601, "BMI (kg/m2)", c(paste0("26.3", pm, "4.4"), paste0("27.1", pm, "4.2")), "0.335"),
    list(w(58, 610, "Sex (male/female)"), w(259, 610, "36/14 (72%/28%)"), w(352, 610, "37/13 (74%/26%)"), w(446, 610, "1.000")),
    list(w(58, 658, "Group C: chlorhexidine gluconate and benzydamine hydrochloride; Group S: saline, BMI: Body Mass Index.")))
  makeTablePdf(file, cells)
}

test_that("a rebuilt Minerva page reads its small-caps caption and its (N.=50) sizes", {
  r <- parseBaselineTableHeuristics(minervaPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(50L, 50L))
  expect_identical(r$arms$arm, c("Group C", "Group S"))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(43.4, 47.3))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(12.2, 13))
  expect_identical(length(unique(cont$ROW)), 4L)
})
