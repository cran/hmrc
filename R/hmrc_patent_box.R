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
#'   }
#'
#' @source
#' <https://www.gov.uk/government/statistics/patent-box-reliefs-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_patent_box()
#' hmrc_patent_box(tax_year = "2022-23")
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
    frequency        = "annual"
  )
}

# ── Internal parser ────────────────────────────────────────────────────────────

parse_patent_box_table1 <- function(path) {
  raw <- readODS::read_ods(path, sheet = "Table_1",
                           col_names = FALSE, as_tibble = FALSE)

  # Find header row: col 1 == "Year"
  hdr_row <- NA_integer_
  for (i in seq_len(nrow(raw))) {
    cell <- trimws(as.character(raw[i, 1]))
    if (identical(tolower(cell), "year")) {
      hdr_row <- i
      break
    }
  }
  if (is.na(hdr_row)) {
    cli::cli_abort("Could not locate Patent Box Table 1 header row.")
  }

  data_rows <- raw[(hdr_row + 1L):nrow(raw), ]
  yr_raw    <- trimws(as.character(data_rows[[1]]))
  is_year   <- grepl("^\\d{4}-\\d{2}$", yr_raw)
  data_rows <- data_rows[is_year, ]
  yr_raw    <- yr_raw[is_year]

  parse_num <- function(x) {
    x <- gsub(",", "", trimws(as.character(x)))
    x[grepl("\\[", x)] <- NA_character_
    suppressWarnings(as.numeric(x))
  }

  data.frame(
    tax_year     = yr_raw,
    companies    = parse_num(data_rows[[2]]),
    relief_gbp_m = parse_num(data_rows[[3]]),
    stringsAsFactors = FALSE
  )
}
