# test-plusminus-glyphs.R - three more ways a page prints its plus-minus,
# an arm-name line of ordinals, and a caption whose title sits under a
# bare "Table 1" (ISSUES.md issue 45, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's junk-label findings G2/G3 on the Saitoh papers of the  #
# Loadsman corpus: CJA 1995;42:1096 (scanned; OCR gives "45.5 + 11.4" and #
# "56.7 • 6.9", caption "(Number or mean + SD)"), CJA 1997;44:390 ("45.6 • #
# 8.2 47.7 + 7.7", header "Group 1 Group 2 Group 3 Group 4"), and Acta     #
# 1997;41:741 (the font maps the plus-minus to the digit 2: legend "mean2SD",#
# cells "49.527.9"; caption line "Table 1" alone, title beneath). On each  #
# the real Table 1 parsed to nothing and a results table or the model won.#
############################################################################

test_that("a bullet between two numbers tokenizes as mean +/- SD", {
  line <- data.frame(text = c("56.7", "•", "6.9", "57.1", "•", "6.7"),
                     x = c(200, 225, 235, 300, 325, 335), width = c(22, 5, 16, 22, 5, 16),
                     stringsAsFactors = FALSE)
  t <- .ppTokenizeLine(line)
  expect_identical(t$type, c("meanSD", "meanSD"))
  expect_identical(t$num1, c(56.7, 57.1))
  expect_identical(t$num2, c(6.9, 6.7))
})

ocrPdf <- function(file = file.path(tempdir(), "ocrplus.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "TABLE I Demographic data (Number or mean + SD)", adj = 0)),
    rowCells(100, "", c("PTBC", "PTC"), vx),
    rowCells(118, "Number of patients", c("15", "15"), vx),
    rowCells(136, "Age (yr)",    c("45.5 + 11.4", "45.0 + 9.5"), vx),
    rowCells(154, "Sex (M/F)",   c("7/8", "7/8"), vx),
    rowCells(172, "Height (cm)", c("167.1 + 10.0", "166.9 + 10.2"), vx),
    rowCells(190, "Body weight (kg)", c("56.7 • 6.9", "57.1 • 6.7"), vx),
    list(list(x = 60, y = 220, text = "There were no differences between the groups.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("'mean + SD' announced: plus-separated pairs are mean +/- SD; the bullet row reads too", {
  r <- parseBaselineTableHeuristics(ocrPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Height", "Body weight"))
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(45.5, 45.0))
  expect_identical(cont$SD[cont$ROW == "Age"], c(11.4, 9.5))
  expect_identical(cont$SD[cont$ROW == "Body weight"], c(6.9, 6.7))
  expect_identical(r$arms$N, c(15L, 15L))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("unannounced, a plus pair is read only beside two mean +/- SD cells on its line; and Group 1..4 names the arms", {
  f  <- file.path(tempdir(), "groups.pdf")
  vx <- c(230, 310, 390, 470)
  cells <- c(
    list(list(x = 60, y = 70, text = "TABLE Demographic data", adj = 0)),
    rowCells(100, "", c("Group 1", "Group 2", "Group 3", "Group 4"), vx),
    rowCells(118, "n", c("40", "40", "40", "10"), vx),
    rowCells(136, "Age (yr)", c("45.6 • 8.2", "47.7 + 7.7", "48.0 • 7.1", "46.2 • 7.7"), vx),
    rowCells(154, "Weight (kg)", c("56.5 • 6.7", "57.9 • 6.4", "57.4 • 7.9", "55.8 • 6.2"), vx),
    list(list(x = 60, y = 180, text = "Number or mean • SD.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$arms$arm, c("Group 1", "Group 2", "Group 3", "Group 4"))
  expect_identical(r$arms$N, c(40L, 40L, 40L, 10L))
  age <- r$data[r$data$ROW == "Age" & !is.na(r$data$MEAN), ]
  expect_identical(age$MEAN, c(45.6, 47.7, 48.0, 46.2))
  expect_identical(age$SD, c(8.2, 7.7, 7.1, 7.7))
  # a lone "a + b" on a line with no mean +/- SD cells is not repaired
  f2 <- file.path(tempdir(), "lonePlus.pdf")
  cells2 <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient data", adj = 0)),
    rowCells(100, "", c("A (n = 10)", "B (n = 10)"), c(300, 420)),
    rowCells(130, "Dose (mg)", c("5 + 2", "6"), c(300, 420)),
    rowCells(148, "Age (yr)", c("45 ± 12", "46 ± 11"), c(300, 420)))
  makeTablePdf(f2, cells2)
  r2 <- parseBaselineTableHeuristics(f2, quiet = TRUE)
  expect_false(any(r2$data$ROW == "Dose" & !is.na(r2$data$SD) & r2$data$SD == 2))
})

actaPdf <- function(file = file.path(tempdir(), "acta.pdf")) {
  vx <- c(280, 370, 460)
  cells <- c(
    list(list(x = 300, y = 70, text = "Table 1", adj = 0)),
    list(list(x = 300, y = 86, text = "Patient characteristics in the two groups. Values", adj = 0)),
    list(list(x = 300, y = 100, text = "are number or mean2SD.", adj = 0)),
    rowCells(124, "", c("DBS3.3", "DBS3.2", "modified DBS"), vx),
    rowCells(142, "Number", c("n=15", "n=15", "n=15"), vx),
    rowCells(160, "Age (yr)",    c("49.527.9", "46.427.4", "48.028.4"), vx),
    rowCells(178, "Height (cm)", c("167.328.2", "166.629.0", "168.428.8"), vx),
    rowCells(196, "Weight (kg)", c("57.229.6", "59.328.6", "57.129.3"), vx))
  makeTablePdf(file, cells)
}

test_that("'mean2SD' announced: a fused cell splits at the 2 that leaves equal decimals; the caption takes its title line", {
  r <- parseBaselineTableHeuristics(actaPdf(), quiet = TRUE)
  expect_match(r$caption, "^Table 1 Patient characteristics in the two groups")
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(49.5, 46.4, 48.0))
  expect_identical(cont$SD[cont$ROW == "Age"], c(7.9, 7.4, 8.4))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(57.2, 59.3, 57.1))
  expect_identical(cont$SD[cont$ROW == "Height"], c(8.2, 9.0, 8.8))
  expect_identical(r$arms$N, c(15L, 15L, 15L))
  # unannounced, the fused cells stay as they were
  f2 <- file.path(tempdir(), "acta2.pdf")
  cells2 <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(100, "", c("A (n = 15)", "B (n = 15)"), c(300, 420)),
    rowCells(130, "Age (yr)", c("49.527.9", "46.427.4"), c(300, 420)),
    rowCells(148, "Height (cm)", c("167.328.2", "166.629.0"), c(300, 420)))
  makeTablePdf(f2, cells2)
  r2 <- tryCatch(parseBaselineTableHeuristics(f2, quiet = TRUE), error = function(e) NULL)
  expect_true(is.null(r2) || !any(!is.na(r2$data$SD)))
})
