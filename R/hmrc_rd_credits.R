#' Download HMRC R&D tax credit statistics
#'
#' Downloads and tidies the HMRC Research and Development Tax Credits
#' Statistics publication, covering the SME R&D Relief and Research and
#' Development Expenditure Credit (RDEC) schemes. Annual data runs from
#' 2000-01 to the most recent financial year, published annually in September.
#'
#' @param scheme Character vector or `NULL` (default = all schemes).
#'   Valid values: `"sme"`, `"rdec"`, `"total"`.
#' @param measure Character vector or `NULL` (default = all measures).
#'   Valid values: `"claims"`, `"amount_gbp_m"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `tax_year`, `scheme`, `description`,
#'   `measure`, `value`.
#'
#' @details
#' Data before 2003-04 covers only the SME scheme (RDEC was introduced in
#' 2002). Figures for the most recent two years are provisional and subject
#' to revision as late claims are processed.
#'
#' @source
#' <https://www.gov.uk/government/statistics/corporate-tax-research-and-development-tax-credit>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_rd_credits()
#' hmrc_rd_credits(scheme = "sme", measure = "claims")
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_rd_credits <- function(scheme  = NULL,
                            measure = NULL,
                            cache   = TRUE) {

  valid_schemes  <- c("sme", "rdec", "total")
  valid_measures <- c("claims", "amount_gbp_m")

  if (!is.null(scheme)) {
    bad <- setdiff(scheme, valid_schemes)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown scheme{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_schemes}}"
      ))
    }
  }
  if (!is.null(measure)) {
    bad <- setdiff(measure, valid_measures)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown measure{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_measures}}"
      ))
    }
  }

  slug <- "corporate-tax-research-and-development-tax-credit"
  loc  <- resolve_govuk_attachment(slug, "rd_tax_credits_main")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_rd_credits_table(path)

  if (!is.null(scheme))  out <- out[out$scheme  %in% scheme,  ]
  if (!is.null(measure)) out <- out[out$measure %in% measure, ]
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "rd_credits_annual",
    hmrc_publication = "R&D Tax Credits Statistics",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "counts/cash",
    frequency        = "annual"
  )
}

# -- Internal parser -----------------------------------------------------------

parse_rd_credits_table <- function(path) {
  read_sheet <- function(sheet, sme_col, rdec_col, total_col) {
    raw <- readODS::read_ods(path, sheet = sheet,
                             col_names = FALSE, as_tibble = FALSE)
    data_rows <- raw[6:nrow(raw), ]
    years_raw <- trimws(as.character(data_rows[[1]]))
    valid     <- grepl("^20\\d{2}-\\d{2}$", years_raw)
    list(
      years     = years_raw[valid],
      data_rows = data_rows[valid, ],
      sme_col   = sme_col,
      rdec_col  = rdec_col,
      total_col = total_col
    )
  }

  rd1 <- read_sheet("RD1", sme_col = 7L, rdec_col = 11L, total_col = 13L)
  rd2 <- read_sheet("RD2", sme_col = 5L, rdec_col = 9L,  total_col = 11L)

  if (length(rd1$years) == 0) {
    cli::cli_abort("Could not locate year rows in R&D credits table. Please file an issue.")
  }

  extract <- function(sheet_data, col, scheme, desc, measure) {
    if (col > ncol(sheet_data$data_rows)) return(NULL)
    raw_vals <- as.character(sheet_data$data_rows[[col]])
    raw_vals <- gsub(",", "", raw_vals)
    vals <- suppressWarnings(as.numeric(raw_vals))
    data.frame(
      tax_year    = sheet_data$years,
      scheme      = scheme,
      description = desc,
      measure     = measure,
      value       = vals,
      stringsAsFactors = FALSE
    )
  }

  results <- list(
    extract(rd1, rd1$sme_col,   "sme",   "SME R&D Relief",                "claims"),
    extract(rd1, rd1$rdec_col,  "rdec",  "R&D Expenditure Credit (RDEC)", "claims"),
    extract(rd1, rd1$total_col, "total", "All R&D schemes",               "claims"),
    extract(rd2, rd2$sme_col,   "sme",   "SME R&D Relief",                "amount_gbp_m"),
    extract(rd2, rd2$rdec_col,  "rdec",  "R&D Expenditure Credit (RDEC)", "amount_gbp_m"),
    extract(rd2, rd2$total_col, "total", "All R&D schemes",               "amount_gbp_m")
  )
  results <- Filter(Negate(is.null), results)

  out <- do.call(rbind, results)
  out <- out[order(out$scheme, out$measure, out$tax_year), ]
  rownames(out) <- NULL
  out
}
