#' Download HMRC stamp duty receipts
#'
#' Downloads and tidies the HMRC Annual Stamp Tax Statistics, covering
#' Stamp Duty Land Tax (SDLT), Stamp Duty Reserve Tax (SDRT) on shares,
#' and other stamp duties. Annual data from 2003-04 to the most recent
#' financial year, published each December.
#'
#' @param type Character vector or `NULL` (default = all types).
#'   Valid values: `"sdlt_property"` (SDLT on property excluding new
#'   leases), `"sdlt_leases"` (SDLT on new leases), `"sdlt_total"`
#'   (all SDLT), `"sdrt"` (Stamp Duty Reserve Tax on shares),
#'   `"stamp_duty"` (Stamp Duty on documents), `"total"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{tax_year}{Character. Financial year, e.g. `"2023-24"`.}
#'     \item{type}{Character. Stamp duty type identifier.}
#'     \item{description}{Character. Plain-English label.}
#'     \item{receipts_gbp_m}{Numeric. Receipts in millions of pounds,
#'       rounded to nearest £5m.}
#'   }
#'
#' @source
#' <https://www.gov.uk/government/statistics/uk-stamp-tax-statistics>
#'
#' @examples
#' \donttest{
#' # All stamp duty types
#' get_stamp_duty()
#'
#' # SDLT only
#' get_stamp_duty(type = "sdlt_total")
#' }
#'
#' @export
get_stamp_duty <- function(type  = NULL,
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
  url  <- resolve_govuk_url(slug, "Annual_Stamps")
  path <- download_cached(url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_stamp_duty_table(path)

  if (!is.null(type)) out <- out[out$type %in% type, ]

  cli::cli_progress_done()
  out
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

  # Header at row 7, data rows 8+
  # Col 1: financial year; cols 2–7: duty types
  header_row <- as.character(unlist(raw[7, ]))
  data_rows  <- raw[8:nrow(raw), ]

  # Parse financial year from col 1
  years_raw <- trimws(as.character(data_rows[[1]]))
  valid     <- grepl("^\\d{4}-\\d{2}$", years_raw)
  years     <- years_raw[valid]
  data_rows <- data_rows[valid, ]

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
