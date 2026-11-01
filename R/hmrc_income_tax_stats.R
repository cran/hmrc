#' Download HMRC Income Tax liabilities by income range
#'
#' Downloads and tidies HMRC Table 2.5, which reports the number of Income Tax
#' payers and their liabilities grouped by total income range, for each
#' available tax year. Numbers of taxpayers are in thousands; amounts are in
#' millions of pounds unless otherwise noted. Published annually in May/June.
#'
#' @param tax_year Character vector or `NULL` (default = all years). Filter to
#'   specific tax years, e.g. `"2023-24"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `tax_year`, `income_range`,
#'   `income_lower_gbp`, `taxpayers_thousands`, `total_income_gbp_m`,
#'   `tax_liability_gbp_m`, `average_rate_pct` (in per cent),
#'   `average_tax_gbp`, and `estimate` (`"outturn"` or `"projection"`).
#'
#' @details
#' The earliest tax year is outturn from the Survey of Personal Incomes;
#' later years are HMRC projections from that survey. The `estimate`
#' column marks which is which. Values suppressed for small sample sizes
#' are returned as `NA`.
#'
#' @source
#' <https://www.gov.uk/government/statistics/income-tax-liabilities-by-income-range>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   it <- hmrc_income_tax_stats()
#'   it[it$income_range == "All Ranges", ]
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_income_tax_stats <- function(tax_year = NULL,
                                  cache    = TRUE) {

  slug <- "income-tax-liabilities-by-income-range"
  loc  <- resolve_govuk_attachment(slug, "Table_2\\.5")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")

  sheets      <- readODS::list_ods_sheets(path)
  data_sheets <- sheets[grepl("^2_5_IT_Liabilities_", sheets)]

  if (length(data_sheets) == 0) {
    abort_schema("Income Tax Table 2.5", "any 2_5_IT_Liabilities_ sheets",
                 found = paste(sheets, collapse = ", "))
  }

  results <- lapply(data_sheets, function(s) parse_income_tax_sheet(path, s))
  out <- do.call(rbind, results)
  out$estimate <- income_tax_estimate_type(out$tax_year,
                                           income_tax_outturn_year(path))

  if (!is.null(tax_year)) {
    bad <- setdiff(tax_year, unique(out$tax_year))
    if (length(bad) > 0) {
      cli::cli_warn(c(
        "Tax year{?s} not found: {.val {bad}}",
        "i" = "Available years: {.val {unique(out$tax_year)}}"
      ))
    }
    out <- out[out$tax_year %in% tax_year, ]
  }
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "income_tax_liabilities_by_range",
    hmrc_publication = "Income Tax liabilities by income range (Table 2.5)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "liabilities",
    frequency        = "annual",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

IT_COLS <- c(
  taxpayers_thousands = "^total number of income tax payers",
  total_income_gbp_m  = "^total income$",
  tax_liability_gbp_m = "^total income tax liability",
  average_rate_pct    = "^average rate of income tax",
  average_tax_gbp     = "^average amount of income tax"
)

parse_income_tax_sheet <- function(path, sheet) {
  pub <- "Income Tax Table 2.5"
  raw <- read_sheet_raw(path, sheet, pub)
  yr  <- parse_tax_year(sub("^2_5_IT_Liabilities_", "", sheet))

  hdr <- find_row(raw, "^range of total income")[1]
  if (is.na(hdr)) abort_schema(pub, paste0("the header row in ", sheet))
  idx <- match_columns(unlist(raw[hdr, ]), IT_COLS, pub)

  range_raw <- trimws(as.character(raw[[1]]))
  rows <- which(seq_along(range_raw) > hdr & !is.na(range_raw) &
                  nzchar(range_raw) & !grepl("End of", range_raw, ignore.case = TRUE))
  if (length(rows) == 0L) abort_schema(pub, paste0("data rows in ", sheet))
  range_raw <- range_raw[rows]

  is_all <- grepl("All Ranges", range_raw, ignore.case = TRUE)
  income_lower <- parse_num(gsub("\\+", "", range_raw))
  income_lower[is_all] <- NA_real_
  income_range <- ifelse(is_all, "All Ranges", gsub("[\u00a3,]", "", range_raw))

  col_vals <- function(key) parse_num(raw[[idx[[key]]]][rows])

  data.frame(
    tax_year            = yr,
    income_range        = income_range,
    income_lower_gbp    = income_lower,
    taxpayers_thousands = col_vals("taxpayers_thousands"),
    total_income_gbp_m  = col_vals("total_income_gbp_m"),
    tax_liability_gbp_m = col_vals("tax_liability_gbp_m"),
    average_rate_pct    = as_percent(col_vals("average_rate_pct")),
    average_tax_gbp     = col_vals("average_tax_gbp"),
    stringsAsFactors    = FALSE
  )
}

#' Latest outturn year named on the Contents sheet ("2023 to 2024 tax year is
#' outturn data ..."); NA if the sentence is not found.
#' @noRd
income_tax_outturn_year <- function(path) {
  if (!"Contents" %in% readODS::list_ods_sheets(path)) return(NA_character_)
  txt <- paste(unlist(read_sheet_raw(path, "Contents")), collapse = " ")
  m <- regmatches(txt, regexpr("\\d{4} to \\d{4} tax year is outturn", txt))
  if (length(m) == 0L) return(NA_character_)
  parse_tax_year(sub(" tax year is outturn", "", m))
}

#' Label years up to the outturn year as outturn, later years as projection.
#' Falls back to treating the earliest year as outturn.
#' @noRd
income_tax_estimate_type <- function(tax_year, outturn_year) {
  if (is.na(outturn_year)) outturn_year <- min(tax_year)
  ifelse(tax_year <= outturn_year, "outturn", "projection")
}
