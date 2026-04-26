#' Download HMRC stamp duty receipts
#'
#' Downloads and tidies the HMRC Annual Stamp Tax Statistics, covering
#' Stamp Duty Land Tax (SDLT), Stamp Duty Reserve Tax (SDRT) on shares,
#' and other stamp duties. Annual data from 2003-04 to the most recent
#' financial year, published each December.
#'
#' @param type Character vector or `NULL` (default = all types).
#'   Valid values: `"sdlt_property"`, `"sdlt_leases"`, `"sdlt_total"`,
#'   `"sdrt"`, `"stamp_duty"`, `"total"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `tax_year`, `type`, `description`,
#'   `receipts_gbp_m` (rounded to nearest GBP 5m by HMRC).
#'
#' @source
#' <https://www.gov.uk/government/statistics/uk-stamp-tax-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_stamp_duty()
#' hmrc_stamp_duty(type = "sdlt_total")
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_stamp_duty <- function(type  = NULL,
                            cache = TRUE) {

  valid_types <- c("sdlt_property", "sdlt_leases", "sdlt_total",
                   "sdrt", "stamp_duty", "total")
  if (!is.null(type)) {
    bad <- setdiff(type, valid_types)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown type{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_types}}"
      ))
    }
  }

  slug <- "uk-stamp-tax-statistics"
  loc  <- resolve_govuk_attachment(slug, "Annual_Stamps")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_stamp_duty_table(path)

  if (!is.null(type)) out <- out[out$type %in% type, ]
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "stamp_duty_annual",
    hmrc_publication = "UK Stamp Tax statistics",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "cash",
    frequency        = "annual"
  )
}

# ── Internal parser ────────────────────────────────────────────────────────────

STAMP_COLS <- c(
  "sdlt_property" = "SDLT on property (excl. new leases)",
  "sdlt_leases"   = "SDLT on new leases",
  "sdlt_total"    = "SDLT total",
  "sdrt"          = "Stamp Duty Reserve Tax (shares)",
  "stamp_duty"    = "Stamp Duty on documents",
  "total"         = "Total stamp taxes"
)

parse_stamp_duty_table <- function(path) {
  raw <- readODS::read_ods(path, sheet = "Table_1a",
                           col_names = FALSE, as_tibble = FALSE)

  data_rows  <- raw[8:nrow(raw), ]
  years_raw  <- trimws(as.character(data_rows[[1]]))
  valid      <- grepl("^\\d{4}-\\d{2}$", years_raw)
  years      <- years_raw[valid]
  data_rows  <- data_rows[valid, ]

  col_keys  <- names(STAMP_COLS)
  col_descs <- unname(STAMP_COLS)

  results <- list()
  for (j in seq_along(col_keys)) {
    col_idx <- j + 1
    if (col_idx > ncol(data_rows)) break
    vals <- suppressWarnings(as.numeric(as.character(data_rows[[col_idx]])))
    results[[j]] <- data.frame(
      tax_year       = years,
      type           = col_keys[j],
      description    = col_descs[j],
      receipts_gbp_m = vals,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, results)
  out <- out[order(out$type, out$tax_year), ]
  rownames(out) <- NULL
  out
}
