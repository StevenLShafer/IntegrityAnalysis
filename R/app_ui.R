# Testing Baseline RCT Values for Fraud / Error
# August  2025

###############################
# UI                          #
###############################
#
# PROVENANCE: was ui.R at the repository root until the package restructure
# (phase 1, Claude Code model Claude Fable 5, 2026-08-16 - see
# docs/package-restructure-plan.md). Two changes only:
#   - the top-level `ui <- ...` object became the function app_ui(), so the
#     page is built when run_app() asks for it rather than at package load
#     (the stanpumpR pattern; a load-time object would also fail R CMD check,
#     since building it calls shinydashboard before packages are attached).
#   - the three static assets are referenced through the "www/" resource
#     prefix that run_app() registers with addResourcePath(), because a
#     packaged app has no auto-served www/ directory. The files themselves
#     moved unchanged to inst/www/.
# Phase 2 (same date) added the testNote banner: Steve wants a PR test
# deployment to SAY, in the app itself, which PR it is and what to test,
# so triage never requires opening GitHub. When testNote is NULL (the
# production app.R) the page is built exactly as before.

app_ui <- function(testNote = NULL)
  dashboardPage(
    title = "RCT Integrity Analysis",
    dashboardHeader(
      title = 
        div(
          h3(
            "Evaluation of Baseline Data Integrity", 
            style="margin: 0;"
            ), 
          h4(
            "Carlisle Shafer 'Monte Carlo' approach", 
            style="margin: 0;"
            )
          ),
      titleWidth = "100%"
      ),
    dashboardSidebar(
      collapsed = FALSE,
      title = "Instructions",
      tags$style(paste(".skin-blue .sidebar .shiny-download-link,",
                       ".skin-blue .sidebar a.btn { color: #444; }")),
      tags$style(".sidebar { height: 10px; }"),
      p(),
      # The user guide is served as a web page rather than downloaded
      # (Steve's request, 2026-08-19): it is the same file the pages
      # workflow publishes as https://integrityanalysis.io/guide.html,
      # so readers get the current guide, with its table of contents,
      # in a new tab instead of a file in their Downloads folder.
      tags$a(
        href = "https://integrityanalysis.io/guide.html",
        target = "_blank", rel = "noopener",
        class = "btn btn-default",
        icon("book"), "View Documentation"
        ),
      # The Template / Example download buttons that lived here were
      # removed 2026-08-26 (Steve: "no longer useful - everyone will
      # have PDFs to test with", and their absence steers users toward
      # the upload-a-PDF workflow, which is now the intended one). The
      # template FORMAT remains documented in the user guide's
      # "Preparing your data" section, and inst/extdata keeps
      # Template.xlsx / Example.xlsx for the test suite's format pins.
      br(),
      br(),
      h6(
        "Developed from John Carlisle's analysis of fraudulent research studies ",
        "(references 2012, 2015, and 2017, see documentation) using the Monte Carlo approach",
        "developed by John Carlisle and Steve Shafer."
        ),
      br(),
      # The purge guarantee, stated where every user sees it before
      # uploading a confidential manuscript (Steve's requirement,
      # 2026-08-17; enforcement is in app_server's onSessionEnded).
      h6(
        strong("Privacy: "),
        "nothing you upload or enter is retained. The uploaded PDF or",
        "spreadsheet, any data typed into the table, and the analysis",
        "results are all purged when this session closes. No record of",
        "the analysis is kept."
        ),
      br(),
      # The caveat (Steve's wording, 2026-08-19, from his experience as
      # Editor-in-Chief of Anesthesia & Analgesia): what a flag does and
      # does not mean, and who is responsible for investigating fraud.
      # Bold, between the privacy statement and the contact line; the
      # same note appears in the user guide.
      h6(
        strong(HTML(paste(
          "CAVEAT: Chance alone will produce P &le; 0.05 in 1 in 20",
          "papers, and P &le; 0.01 in 1 in 100 papers. Research fraud",
          "should never be alleged by a single manuscript flagged by",
          "IntegrityAnalysis. Confirmation such as multiple suspicious",
          "papers (e.g., Fujii, Boldt) should be sought. Authors or",
          "journal editors should be contacted before any public",
          "allegations of research fraud. Journals do not have the",
          "authority, resources, or responsibility for investigating",
          "fraud. Journal editors should refer allegations of fraud to",
          "the institution under whose authority the research was",
          "conducted. Institutions are responsible for ethical conduct",
          "of research.")))
        ),
      br(),
      # Usage-counting disclosure, in Steve's first person (2026-08-19).
      # Implementation and privacy design: R/usageCount.R.
      h6(
        strong("Usage counting: "),
        "I tabulate the number of times IntegrityAnalysis is opened and",
        "the number of analyses run - simple counts, and nothing else.",
        "Not even your IP address reaches the counter, because the",
        "count is sent by the server, not by your browser. I want to",
        "know whether the program is being used: there is no point",
        "maintaining a program that nobody uses. - Steve Shafer"
        ),
      HTML(
        '<p>
        <h6>Please direct questions and feedback to Steve Shafer at
        <a href="mailto:steven.shafer@stanford.edu">steven.shafer@stanford.edu</a>
        .
        </h6>
        </p>'
        )
      ),
    dashboardBody(
      # Visible only on PR test deployments (run_app(testNote = ...)):
      # a banner naming the PR and what to test, so the tester never has
      # to inspect the PR itself to know what to look for.
      if (!is.null(testNote))
        fluidRow(
          div(
            strong("TEST DEPLOYMENT - "), testNote,
            style = paste0(
              "background-color: #f39c12; color: #000; padding: 8px 5%; ",
              "font-size: 15px; border-bottom: 2px solid #c87f0a;")
          )
        ),
      shinyjs::useShinyjs(),
      tags$script(src = "www/app.js"),
      tags$head(tags$link(href = "www/app.css", rel = "stylesheet")),
      style = "max-height: 95vh; overflow-y: auto;" ,
      tags$head(
        tags$style(
          type="text/css", 
          "#inline label { 
          display: table-cell; 
          text-align: center; 
          vertical-align: middle; 
          } 
        #inline .form-group {
        display: table-row;
        }"
        )
      ),
      # The template-format figure that sat here (Table.png) came from
      # the original 2025 design, when users were expected to hand-build
      # the input spreadsheet and needed the format explained up front.
      # Now that the app parses PDFs, Word manuscripts, and journal-style
      # tables itself, the figure is reference material - "more of a
      # curiosity" (Steve, 2026-08-26) - and lives in the user guide's
      # "Preparing your data" section instead.
      #
      # Layout (Steve's design, 2026-08-26): sidebar | workflow | data.
      # The workflow column holds everything the user DOES - upload,
      # options, the API key, and the action buttons as the analysis
      # advances. The data column shows what came in: the editable
      # grid, its color legend, and below them a message box narrating
      # the upload. On a narrow window Bootstrap stacks the columns,
      # workflow first.
      fluidRow(
        column(
          4,
          HTML(paste0(
            # Both spreadsheet routes accept the same three formats;
            # the old wording attached "(csv, xls, xlsx)" to the first
            # only, so a reader with a journal-style CSV could not tell
            # it was supported (Steve, 2026-08-27).
            "<br>Select one or more spreadsheets - csv, xls or xlsx - ",
            "in either the data entry layout or a journal-style ",
            "baseline table (variables as rows, arms as columns, ",
            "including this app's own Editor's View download); ",
            "article PDFs, Word manuscripts (docx), or a ",
            "zip of many such files - everything combines into one ",
            "table, distinguished by trial - or start with an empty ",
            "table and type the data in<br>")),
          fileInput("upload", NULL, multiple = TRUE,
                    accept = c(".csv", ".xls", ".xlsx", ".pdf", ".docx",
                               ".zip")),
          # Opt-in approximation (Steve, 2026-08-21): percent-only cells
          # whose printed rounding cannot pin a unique count fall back to
          # round(arm N x percent). Everything the parser derives - exact
          # or approximate - paints GREEN in the grid: OK to use, but
          # best to check before the analysis runs.
          checkboxInput("pctApprox", paste(
            "Convert percent-only cells to approximate counts when the",
            "exact count cannot be determined (derived values show green",
            "in the table below)"), value = TRUE, width = "100%"),
          # The AI assist, bring-your-own-key (ISSUES.md issue 8). A
          # password-type field: the key never appears on screen, never
          # goes in a URL, is never stored or logged, and dies with the
          # session (see the upload observer in app_server.R). The
          # consent sentence below is load-bearing - the app's standing
          # privacy promise is "no document content is ever sent to any
          # third-party service", and entering a key is the uploader's
          # explicit, per-session revision of that promise for their own
          # documents.
          passwordInput("aiKey", NULL, width = "100%",
                        placeholder = paste(
                          "Optional: your Anthropic API key turns on the",
                          "AI assist for hard-to-read documents")),
          # Live key verdict (Steve's design, 2026-08-25): a green
          # "Key validated" or a red "Invalid key" about a second after
          # typing stops, so the uploader always knows whether THIS
          # session is armed. See the aiKeyStatus observer in
          # app_server.R.
          uiOutput("aiKeyStatus"),
          HTML(paste0(
            # margin-top must stay ZERO: with the old -12px this div
            # climbed over the key verdict rendered above it, and
            # neither could be read (Steve's report, 2026-08-26)
            "<div style='font-size: 85%; color: #666; margin-top: 0; ",
            "margin-bottom: 8px;'>",
            "<b>AI assist (optional - bring your own key).</b> With a key ",
            "entered above, pages the deterministic reader cannot fully ",
            "parse are sent to the Anthropic API under <i>your</i> account ",
            "(roughly $0.06&ndash;0.11 per article). Entering a key is ",
            "your consent to send the uploaded documents' content (text, ",
            "or page images for scanned pages) to that ",
            "service during this session. The handoff stays confidential: ",
            "Anthropic's commercial terms bar it from training models on ",
            "API submissions, and API data is deleted within about 30 ",
            "days. The key is never stored or ",
            "logged, and AI-read lines show green for review. Without a ",
            "key, nothing you upload ever leaves this server.</div>")),
          actionButton("blank", "Start With an Empty Table"),
          HTML("<br><br>"),
          # The action buttons appear here as the analysis advances:
          # Apply Edits & Revalidate, Analyze, the extracted-table and
          # journal-view downloads, and the results download.
          uiOutput("validateButton"),
          uiOutput("GoButton"),
          # Appears after a PDF parse: the extracted table as a spreadsheet,
          # so a partial extraction is a round trip (fill the gaps, re-upload
          # the spreadsheet) rather than a dead end - the failure contract
          # from ISSUES.md issue 1.
          uiOutput("extractedButton"),
          # Issue 15 (Steve, 2026-08-17): after validation succeeds, the
          # journal-style reconstructed baseline table - variables as
          # rows, arms as columns, cells as journals print them - the
          # artifact an editor compares against the manuscript page.
          uiOutput("journalButton"),
          uiOutput("downloadButton"),
          uiOutput("stopButton")
        ),
        column(
          8,
          # The editable pre-analysis grid (Steve's request, 2026-08-17):
          # whatever the upload produced - spreadsheet rows or a PDF
          # extraction - is shown here for inspection and editing BEFORE
          # any statistics run. Edits take effect through the "Apply
          # Edits & Revalidate" button in the workflow column; for a
          # parsed PDF this is where a missing arm N gets filled in
          # directly.
          rhandsontable::rHandsontableOutput("dataGrid"),
          # Issue 13 (2026-08-18): color legend for problem cells, shown
          # only when validation flagged something - yellow = missing,
          # red = unreadable, blue = incongruent, cyan = OCR.
          uiOutput("issueLegend"),
          # The message box (Steve's design, 2026-08-26): everything the
          # upload narrates - files read, lines skipped, AI or OCR
          # engagement - lands directly under the data it describes.
          # The box itself (border, scroll) is built in app_server's
          # logContent renderer, so nothing shows when there is nothing
          # to say.
          uiOutput("logContent")
        )
      )
    )
  )
