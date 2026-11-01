#' Download HMRC tax gap estimates
#'
#' Downloads and tidies the HMRC Measuring Tax Gaps tables: estimates of the
#' difference between the tax that should in theory be paid and the tax
#' actually collected, by tax, taxpayer type and component. Since the 2026
#' edition HMRC publishes a consistent time series from 2005-06, and every
#' edition revises earlier years. Published annually in June.
#'
#' @param tax Character vector or `NULL` (default = all taxes). Filter on the
#'   `tax` column: `"VAT"`, `"Excise duty"`,
#'   `"Income Tax, NICs, Capital Gains Tax"`, `"Corporation Tax"`,
#'   `"Other taxes"`, `"Total tax gap"`.
#' @param tax_year Character vector, `"latest"`, or `NULL` (default = all
#'   years). Filter to specific tax years, e.g. `"2024-25"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns:
#'   \describe{
#'     \item{tax_year}{Character. Tax year, e.g. `"2024-25"`.}
#'     \item{tax}{Character. Tax group, e.g. `"VAT"`, `"Corporation Tax"`.}
#'     \item{type}{Character. Sub-group, e.g. `"Self Assessment"`,
#'       `"Tobacco duty"`, or the group total.}
#'     \item{component}{Character. Taxpayer group or duty, e.g.
#'       `"Small businesses"`, `"Cigarette duty"`.}
#'     \item{gap_pct}{Numeric. Tax gap as a per cent of theoretical
#'       liabilities (Table 1.1).}
#'     \item{gap_gbp_bn}{Numeric. Tax gap in GBP billion (Table 1.2).}
#'   }
#'
#' @details
#' Rows that appear only in the GBP table (avoidance and hidden economy
#' components) have `gap_pct` of `NA`. Estimates HMRC shows as `<0.1` (below
#' GBP 0.05bn) are returned as `NA`. Each June edition revises the whole
#' series, so results change between editions; [hmrc_meta()] records the
#' edition's publication date.
#'
#' @source
#' <https://www.gov.uk/government/statistics/measuring-tax-gaps>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   gap <- hmrc_tax_gap(tax = "Total tax gap")
#'   tail(gap)
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_tax_gap <- function(tax      = NULL,
                         tax_year = NULL,
                         cache    = TRUE) {

  slug <- "measuring-tax-gaps-tables"
  loc  <- resolve_govuk_attachment(slug, "Measuring_tax_gap_online")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_tax_gap_tables(path)

  if (!is.null(tax)) {
    bad <- setdiff(tax, unique(out$tax))
    if (length(bad) > 0) {
      cli::cli_warn(c(
        "Tax type{?s} not found: {.val {bad}}",
        "i" = "Available values: {.val {unique(out$tax)}}"
      ))
    }
    out <- out[out$tax %in% tax, ]
  }
  if (!is.null(tax_year)) {
    if (identical(tax_year, "latest")) tax_year <- max(out$tax_year)
    bad <- setdiff(tax_year, unique(out$tax_year))
    if (length(bad) > 0) {
      cli::cli_warn(c(
        "Tax year{?s} not found: {.val {bad}}",
        "i" = "Available years: {.val {range(out$tax_year)}}"
      ))
    }
    out <- out[out$tax_year %in% tax_year, ]
  }
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "tax_gap_annual",
    hmrc_publication = "Measuring Tax Gaps",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "estimates",
    frequency        = "annual",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

# Read one wide Measuring Tax Gaps table ("Tax | Type | Component | years")
# into long format.
read_tax_gap_table <- function(path, sheet) {
  pub <- "Measuring tax gaps tables"
  raw <- read_sheet_raw(path, sheet, pub)

  hdr <- find_row(raw, "^tax$")[1]
  if (is.na(hdr)) abort_schema(pub, paste0("the ", sheet, " header row"))
  header <- clean_header(unlist(raw[hdr, ]))
  idx    <- match_columns(header, c(tax = "^tax$", type = "^type$",
                                    component = "^component$"), pub)
  ycols  <- which(grepl("^\\d{4}-\\d{2}$", header))
  if (length(ycols) == 0L) abort_schema(pub, paste0("year columns in ", sheet))

  tax_col <- trimws(as.character(raw[[idx[["tax"]]]]))
  rows <- which(seq_along(tax_col) > hdr & !is.na(tax_col) & nzchar(tax_col))
  # Stop at the first gap: notes and blank rows follow the table
  if (length(rows) > 1L) {
    breaks <- which(diff(rows) > 1L)
    if (length(breaks)) rows <- rows[seq_len(breaks[1])]
  }
  if (length(rows) == 0L) abort_schema(pub, paste0("data rows in ", sheet))

  do.call(rbind, lapply(ycols, function(j) {
    data.frame(
      tax       = tax_col[rows],
      type      = trimws(as.character(raw[[idx[["type"]]]][rows])),
      component = trimws(as.character(raw[[idx[["component"]]]][rows])),
      tax_year  = header[j],
      value     = parse_num(raw[[j]][rows]),
      stringsAsFactors = FALSE
    )
  }))
}

parse_tax_gap_tables <- function(path) {
  pct <- read_tax_gap_table(path, "Table 1.1")
  gbp <- read_tax_gap_table(path, "Table 1.2")

  # Table 1.2 closes with liability and percentage totals, which are not gaps
  gbp <- gbp[!grepl("theoretical tax liability|percentage tax gap",
                    gbp$tax, ignore.case = TRUE), ]

  pct$value <- as_percent(pct$value)
  names(pct)[names(pct) == "value"] <- "gap_pct"
  names(gbp)[names(gbp) == "value"] <- "gap_gbp_bn"

  keys <- c("tax", "type", "component", "tax_year")
  out  <- merge(pct[, c(keys, "gap_pct")], gbp[, c(keys, "gap_gbp_bn")],
                by = keys, all = TRUE)

  # Order rows as HMRC does (Table 1.2 is the fuller table), then by year
  row_key  <- paste(out$tax, out$type, out$component, sep = "\r")
  gbp_keys <- unique(paste(gbp$tax, gbp$type, gbp$component, sep = "\r"))
  pct_keys <- unique(paste(pct$tax, pct$type, pct$component, sep = "\r"))
  all_keys <- c(gbp_keys, setdiff(pct_keys, gbp_keys))
  out <- out[order(match(row_key, all_keys), out$tax_year), ]

  out <- out[, c("tax_year", "tax", "type", "component", "gap_pct", "gap_gbp_bn")]
  rownames(out) <- NULL
  out
}
