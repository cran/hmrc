#' Download HMRC Patent Box relief statistics
#'
#' Downloads and tidies Table 1 of the HMRC Patent Box Relief Statistics:
#' annual number of companies electing into the Patent Box regime and the
#' total relief claimed (in GBP million). The Patent Box was introduced
#' from 1 April 2013; data runs from tax year 2013-14 to the most recent
#' published year (typically with a one-year provisional lag). Published
#' annually each September.
#'
#' @param tax_year Character vector or `NULL` (default = all years).
#'   Filter to specific tax years, e.g. `"2023-24"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns:
#'   \describe{
#'     \item{tax_year}{Character. Tax year, e.g. `"2023-24"`.}
#'     \item{companies}{Numeric. Number of companies electing into the regime
#'       (rounded to nearest 5 by HMRC).}
#'     \item{relief_gbp_m}{Numeric. Total relief in millions of pounds.}
#'     \item{status}{Character. HMRC's label for the year where it gives one
#'       (e.g. `"projection"` for the latest year), otherwise `NA`.}
#'   }
#'
#' @source
#' <https://www.gov.uk/government/statistics/patent-box-reliefs-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   hmrc_patent_box()
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_patent_box <- function(tax_year = NULL,
                            cache    = TRUE) {

  slug <- "patent-box-reliefs-statistics"
  loc  <- resolve_govuk_attachment(slug, "PB_publication_tables")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_patent_box_table1(path)

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
    dataset          = "patent_box",
    hmrc_publication = "Patent Box reliefs statistics (Table 1)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "counts/cash",
    frequency        = "annual",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

PB_COLS <- c(
  companies    = "^number of companies",
  relief_gbp_m = "^amount of relief"
)

parse_patent_box_table1 <- function(path) {
  pub <- "Patent Box reliefs statistics"
  raw <- read_sheet_raw(path, "Table_1", pub)

  hdr <- find_row(raw, "^year$")[1]
  if (is.na(hdr)) abort_schema(pub, "the Table 1 header row")
  idx <- match_columns(unlist(raw[hdr, ]), PB_COLS, pub)

  labels <- trimws(as.character(raw[[1]]))
  years  <- parse_tax_year(labels)
  rows   <- which(!is.na(years) & seq_along(years) > hdr)
  if (length(rows) == 0L) abort_schema(pub, "any year rows in Table 1")

  data.frame(
    tax_year     = years[rows],
    companies    = parse_num(raw[[idx[["companies"]]]][rows]),
    relief_gbp_m = parse_num(raw[[idx[["relief_gbp_m"]]]][rows]),
    status       = row_label_note(labels[rows]),
    stringsAsFactors = FALSE
  )
}
