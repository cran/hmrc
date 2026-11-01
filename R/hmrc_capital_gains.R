#' Download HMRC Capital Gains Tax statistics
#'
#' Downloads and tidies HMRC Table 1 of the Capital Gains Tax statistics
#' bulletin: estimated number of CGT taxpayers, amounts of gains, and tax
#' liabilities by year of disposal. Data runs from 1987-88 onwards and is
#' published annually each summer.
#'
#' @param tax_year Character vector or `NULL` (default = all years).
#'   Filter to specific tax years, e.g. `"2022-23"`.
#' @param measure Character vector or `NULL` (default = all measures).
#'   Valid values: `"taxpayers_total_thousands"`,
#'   `"taxpayers_individuals_thousands"`, `"taxpayers_trusts_thousands"`,
#'   `"males_pct"`, `"females_pct"`,
#'   `"gains_individuals_gbp_m"`, `"gains_trusts_gbp_m"`,
#'   `"gains_total_gbp_m"`, `"tax_individuals_gbp_m"`,
#'   `"tax_trusts_gbp_m"`, `"tax_total_gbp_m"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` (long format) with columns `tax_year`, `measure`,
#'   `value`, and `status` (`"provisional"` for the years HMRC marks as
#'   provisional, otherwise `NA`). Numbers of taxpayers are in thousands;
#'   amounts in millions of pounds; percentages in per cent. Suppressed
#'   cells return `NA`.
#'
#' @details
#' Gains are after the deduction of taper relief and losses plus attributed
#' gains, but before deduction of the Annual Exempt Amount. Trusts include
#' personal representatives of the deceased. Statistics for the latest tax
#' years are provisional and are revised in subsequent publications as late
#' returns arrive.
#'
#' @source
#' <https://www.gov.uk/government/statistics/capital-gains-tax-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   cgt <- hmrc_capital_gains(measure = "tax_total_gbp_m")
#'   tail(cgt)
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_capital_gains <- function(tax_year = NULL,
                               measure  = NULL,
                               cache    = TRUE) {

  valid_measures <- names(CGT_T1_COLS)
  if (!is.null(measure)) {
    bad <- setdiff(measure, valid_measures)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown measure{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_measures}}"
      ))
    }
  }

  slug <- "capital-gains-tax-statistics"
  loc  <- resolve_govuk_attachment(slug, "Table_1_.*Taxpayer_numbers.*\\.ods")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_cgt_table1(path)

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
  if (!is.null(measure)) out <- out[out$measure %in% measure, ]
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "capital_gains_tax_annual",
    hmrc_publication = "Capital Gains Tax statistics (Table 1)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "liabilities",
    frequency        = "annual",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------
#
# CGT Table 1: one row per year of disposal ("1987 to 1988", with "[Note n]"
# markers on some years) under a "Year of disposal" header row. Columns are
# matched by header text. Suppressed cells ("[Unavailable]") become NA.

CGT_T1_COLS <- c(
  taxpayers_individuals_thousands = "^number of individuals",
  males_pct                       = "^males as",
  females_pct                     = "^females as",
  gains_individuals_gbp_m         = "^amounts? of gains for individuals",
  tax_individuals_gbp_m           = "^amounts? of tax for individuals",
  taxpayers_trusts_thousands      = "^number of trusts",
  gains_trusts_gbp_m              = "^amounts? of gains for trusts",
  tax_trusts_gbp_m                = "^amounts? of tax for trusts",
  taxpayers_total_thousands       = "^total taxpayers",
  gains_total_gbp_m               = "^total amounts? of gains",
  tax_total_gbp_m                 = "^total amounts? of tax"
)

parse_cgt_table1 <- function(path) {
  pub <- "Capital Gains Tax statistics"
  raw <- read_sheet_raw(path, "Table_1", pub)

  hdr <- find_row(raw, "^year of disposal$")[1]
  if (is.na(hdr)) abort_schema(pub, "the Table 1 header row")
  idx <- match_columns(unlist(raw[hdr, ]), CGT_T1_COLS, pub)

  years <- parse_tax_year(raw[[1]])
  rows  <- which(!is.na(years) & seq_along(years) > hdr)
  if (length(rows) == 0L) abort_schema(pub, "any year-of-disposal rows")

  first_prov <- cgt_first_provisional_year(raw[seq_len(hdr - 1L), , drop = FALSE])
  status <- if (is.na(first_prov)) {
    rep(NA_character_, length(rows))
  } else {
    ifelse(years[rows] >= first_prov, "provisional", NA_character_)
  }

  out <- do.call(rbind, lapply(names(CGT_T1_COLS), function(k) {
    data.frame(
      tax_year = years[rows],
      measure  = k,
      value    = parse_num(raw[[idx[[k]]]][rows]),
      status   = status,
      stringsAsFactors = FALSE
    )
  }))
  out <- out[order(out$measure, out$tax_year), ]
  rownames(out) <- NULL
  out
}

#' First provisional year from the note "The statistics for tax years 2022 to
#' 2023 onwards are provisional."; NA if there is no such note.
#' @noRd
cgt_first_provisional_year <- function(notes) {
  txt <- paste(unlist(notes), collapse = " ")
  m <- regmatches(txt, regexpr("\\d{4} to \\d{4} onwards are provisional", txt))
  if (length(m) == 0L) return(NA_character_)
  parse_tax_year(sub(" onwards are provisional", "", m))
}
