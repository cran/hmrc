#' Download HMRC Inheritance Tax liabilities by estate band
#'
#' Downloads and tidies HMRC Table 12.1a of the Inheritance Tax Liabilities
#' Statistics: numbers of estates, tax due, average tax, and average
#' effective tax rate, broken down by net-estate band, for the latest
#' published year of death. Published annually in July, ~3 years after the
#' year of death due to the administration window.
#'
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` (long format) with columns:
#'   \describe{
#'     \item{tax_year}{Character. Year of death, e.g. `"2022-23"`.}
#'     \item{estate_band_lower_gbp}{Numeric. Lower limit of the net-estate
#'       band in pounds.}
#'     \item{estate_band}{Character. Plain-English label, e.g.
#'       `"GBP 0-100k"`, `"Total"`.}
#'     \item{measure}{Character. One of `"number_not_taxed"`,
#'       `"number_taxed"`, `"tax_due_gbp_m"`, `"avg_tax_gbp"`,
#'       `"effective_rate_pct"`.}
#'     \item{value}{Numeric. Value, with `[z]` (no tax due to NRB) and
#'       `[c]` (disclosure suppression) returned as `NA`.}
#'   }
#'
#' @source
#' <https://www.gov.uk/government/statistics/inheritance-tax-liabilities-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_inheritance_tax()
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_inheritance_tax <- function(cache = TRUE) {

  slug <- "inheritance-tax-liabilities-statistics"
  loc  <- resolve_govuk_attachment(slug, "table_12_1\\.ods")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_iht_12_1a(path)
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "inheritance_tax_annual",
    hmrc_publication = "Inheritance Tax liabilities statistics (Table 12.1a)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "liabilities",
    frequency        = "annual"
  )
}

# ── Internal parser ────────────────────────────────────────────────────────────
#
# IHT 12_1a layout (annual cross-section, ~3yr publication lag):
#   Sheet "12_1a"
#   Row 5 = headers, e.g. "Net estate (lower limits) [Note 1]" |
#           "2022 to 2023 number not taxed" | "2022 to 2023 number taxed" |
#           "2022 to 2023 tax due (£ million) [Note 2]" |
#           "2022 to 2023 average tax (£)" |
#           "2022 to 2023 average effective tax rate of taxpaying estates (per cent)"
#   Row 6+ = data: net-estate lower-limit GBP (0, 100000, ..., 10000000) +
#                  totals row "Total estates notified".
# Suppressed cells: "[z]" = no tax (estate below NRB), "[c]" = disclosure.

IHT_MEASURE_PATTERNS <- c(
  number_not_taxed   = "number not taxed",
  number_taxed       = "number taxed",
  tax_due_gbp_m      = "tax due",
  avg_tax_gbp        = "average tax",
  effective_rate_pct = "average effective tax rate"
)

parse_iht_12_1a <- function(path) {
  raw <- readODS::read_ods(path, sheet = "12_1a",
                           col_names = FALSE, as_tibble = FALSE)

  # Find header row: cell A* contains "Net estate (lower limits)"
  hdr_row <- NA_integer_
  for (i in seq_len(nrow(raw))) {
    cell <- trimws(as.character(raw[i, 1]))
    if (grepl("^Net estate", cell, ignore.case = TRUE)) {
      hdr_row <- i
      break
    }
  }
  if (is.na(hdr_row)) {
    cli::cli_abort("Could not locate IHT Table 12.1a header row. Please file an issue.")
  }

  header_row <- as.character(unlist(raw[hdr_row, ]))

  # Extract tax_year from any of the value-column headers
  tax_year <- NA_character_
  for (h in header_row[-1L]) {
    if (is.na(h)) next
    m <- regmatches(h, regexpr("\\d{4}\\s+to\\s+\\d{4}", h))
    if (length(m) == 1L && nzchar(m)) {
      yrs <- regmatches(m, gregexpr("\\d{4}", m))[[1]]
      tax_year <- paste0(yrs[1], "-", substr(yrs[2], 3, 4))
      break
    }
  }
  if (is.na(tax_year)) tax_year <- "unknown"

  # Map each value column to a measure key by header pattern
  col_measure <- rep(NA_character_, length(header_row))
  for (j in seq_along(header_row)) {
    h <- tolower(header_row[j] %||% "")
    for (key in names(IHT_MEASURE_PATTERNS)) {
      if (grepl(IHT_MEASURE_PATTERNS[[key]], h)) {
        col_measure[j] <- key
        break
      }
    }
  }

  data_rows <- raw[(hdr_row + 1L):nrow(raw), ]
  band_raw  <- trimws(as.character(data_rows[[1]]))

  total_idx <- grep("^Total estates", band_raw, ignore.case = TRUE)
  numeric_idx <- grep("^[0-9]", band_raw)
  keep_idx <- sort(unique(c(numeric_idx, total_idx)))
  if (length(keep_idx) == 0) {
    cli::cli_abort("No data rows found in IHT 12_1a.")
  }
  data_rows <- data_rows[keep_idx, ]
  band_raw  <- band_raw[keep_idx]

  is_total <- grepl("^Total", band_raw, ignore.case = TRUE)
  estate_band_lower_gbp <- suppressWarnings(as.numeric(band_raw))
  # Total row: keep NA lower limit, label "Total"
  estate_band_lower_gbp[is_total] <- NA_real_

  fmt_band <- function(low, total) {
    if (total) return("Total")
    if (is.na(low)) return(NA_character_)
    if (low == 0)       return("GBP 0-100k")
    if (low ==   100000) return("GBP 100k-200k")
    if (low ==   200000) return("GBP 200k-300k")
    if (low ==   300000) return("GBP 300k-400k")
    if (low ==   400000) return("GBP 400k-500k")
    if (low ==   500000) return("GBP 500k-600k")
    if (low ==   600000) return("GBP 600k-700k")
    if (low ==   700000) return("GBP 700k-800k")
    if (low ==   800000) return("GBP 800k-900k")
    if (low ==   900000) return("GBP 900k-1m")
    if (low ==  1000000) return("GBP 1m-1.5m")
    if (low ==  1500000) return("GBP 1.5m-2m")
    if (low ==  2000000) return("GBP 2m-3m")
    if (low ==  3000000) return("GBP 3m-4m")
    if (low ==  4000000) return("GBP 4m-5m")
    if (low ==  5000000) return("GBP 5m-7.5m")
    if (low ==  7500000) return("GBP 7.5m-10m")
    if (low == 10000000) return("GBP 10m+")
    paste0("GBP ", format(low, big.mark = ","), "+")
  }
  estate_band <- mapply(fmt_band, estate_band_lower_gbp, is_total,
                        USE.NAMES = FALSE)

  parse_num <- function(x) {
    x <- gsub(",", "", trimws(as.character(x)))
    x[grepl("\\[", x)] <- NA_character_
    suppressWarnings(as.numeric(x))
  }

  results <- list()
  for (j in seq_along(col_measure)) {
    if (is.na(col_measure[j])) next
    if (j > ncol(data_rows)) next
    results[[length(results) + 1L]] <- data.frame(
      tax_year              = tax_year,
      estate_band_lower_gbp = estate_band_lower_gbp,
      estate_band           = estate_band,
      measure               = col_measure[j],
      value                 = parse_num(data_rows[[j]]),
      stringsAsFactors      = FALSE
    )
  }

  if (length(results) == 0) {
    cli::cli_abort("No measure columns recognised in IHT 12_1a.")
  }

  out <- do.call(rbind, results)
  ord <- order(
    is.na(out$estate_band_lower_gbp),
    out$estate_band_lower_gbp,
    out$measure
  )
  out <- out[ord, ]
  rownames(out) <- NULL
  out
}
