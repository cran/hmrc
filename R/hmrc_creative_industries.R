#' Download HMRC Creative Industries tax relief statistics
#'
#' Downloads and tidies Table 1 (annual time series) of the HMRC Creative
#' Industries Statistics for each of the eight creative-industries reliefs:
#' Film, High-end TV, Animation, Children's TV, Video Games, Theatre,
#' Orchestra, and Museums and Galleries Exhibition. Published annually
#' each August.
#'
#' @param sector Character vector or `NULL` (default = all sectors).
#'   Valid values: `"film"`, `"high_end_tv"`, `"animation"`,
#'   `"childrens_tv"`, `"video_games"`, `"theatre"`, `"orchestra"`,
#'   `"museum"`.
#' @param tax_year Character vector or `NULL` (default = all years).
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns:
#'   \describe{
#'     \item{sector}{Character. Creative-industries sector identifier.}
#'     \item{tax_year}{Character. Tax year, e.g. `"2023-24"`.}
#'     \item{companies}{Numeric. Number of companies (where reported).}
#'     \item{claims}{Numeric. Number of claims (where reported).}
#'     \item{productions}{Numeric. Number of productions (films, games,
#'       etc., where reported).}
#'     \item{relief_gbp_m}{Numeric. Amount of relief paid, GBP million.}
#'     \item{status}{Character. HMRC revision status (e.g. `"Unchanged"`,
#'       `"Provisional"`).}
#'   }
#'
#' @details
#' Creative Industries reliefs are paid on an accruals basis. The latest
#' tax year in each sector's table is provisional and uplifted by HMRC for
#' claims not yet received; status is recorded in the `status` column.
#' Sector tables differ slightly in their column set (films track
#' `productions`, video games track `productions`, theatre tracks
#' `claims`/`productions`, museums track exhibitions, etc.); columns absent
#' from a sector's table are returned as `NA`.
#'
#' @source
#' <https://www.gov.uk/government/collections/creative-industries-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_creative_industries(sector = "film")
#' hmrc_creative_industries(tax_year = "2023-24")
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_creative_industries <- function(sector   = NULL,
                                     tax_year = NULL,
                                     cache    = TRUE) {

  valid_sectors <- names(CREATIVE_SECTOR_SHEETS)
  if (!is.null(sector)) {
    bad <- setdiff(sector, valid_sectors)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown sector{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_sectors}}"
      ))
    }
  }

  # The publication slug includes the month: try latest-year August + September
  current_year <- as.integer(format(Sys.Date(), "%Y"))
  loc <- NULL
  candidates <- character(0)
  for (yr in seq(current_year, current_year - 2L)) {
    candidates <- c(candidates,
                    paste0("creative-industries-statistics-august-", yr),
                    paste0("creative-industries-statistics-september-", yr),
                    paste0("creative-industries-statistics-", yr))
  }
  for (slug in candidates) {
    loc <- tryCatch(
      resolve_govuk_attachment(slug, "Creative_industries_tables"),
      error = function(e) NULL
    )
    if (!is.null(loc)) break
  }
  if (is.null(loc)) {
    cli::cli_abort(c(
      "Could not find Creative Industries statistics on GOV.UK.",
      "i" = "Tried slugs spanning {current_year - 2L} to {current_year}.",
      "i" = "Check {.url https://www.gov.uk/government/collections/creative-industries-statistics}"
    ))
  }
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_creative_industries(path)

  if (!is.null(sector))   out <- out[out$sector   %in% sector,   ]
  if (!is.null(tax_year)) out <- out[out$tax_year %in% tax_year, ]
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "creative_industries_reliefs",
    hmrc_publication = "Creative Industries tax relief statistics (Table 1)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = loc$slug,
    cell_methods     = "counts/cash",
    frequency        = "annual"
  )
}

# ── Internal parser ────────────────────────────────────────────────────────────

CREATIVE_SECTOR_SHEETS <- c(
  film         = "Table_1_Film",
  high_end_tv  = "Table_1_High-end_TV",
  animation    = "Table_1_Animation",
  childrens_tv = "Table_1_Childrens_TV",
  video_games  = "Table_1_Video_games",
  theatre      = "Table_1_Theatre",
  orchestra    = "Table_1_Orchestra",
  museum       = "Table_1_Museum"
)

CREATIVE_HEADER_PATTERNS <- list(
  companies   = "number of companies",
  claims      = "number of claims",
  productions = "number of (films|games|productions|exhibitions|tours|orchestral concerts|theatrical productions)",
  relief_gbp_m= "amount of relief",
  status      = "^status$"
)

parse_creative_industries <- function(path) {
  available <- readODS::list_ods_sheets(path)

  results <- list()
  for (sec in names(CREATIVE_SECTOR_SHEETS)) {
    sheet <- CREATIVE_SECTOR_SHEETS[[sec]]
    if (!sheet %in% available) next

    raw <- readODS::read_ods(path, sheet = sheet,
                             col_names = FALSE, as_tibble = FALSE)

    # Header row: col 1 == "Year"
    hdr_row <- NA_integer_
    for (i in seq_len(nrow(raw))) {
      cell <- trimws(as.character(raw[i, 1]))
      if (identical(tolower(cell), "year")) {
        hdr_row <- i
        break
      }
    }
    if (is.na(hdr_row)) next

    header_row <- tolower(trimws(as.character(unlist(raw[hdr_row, ]))))
    data_rows  <- raw[(hdr_row + 1L):nrow(raw), ]

    yr_raw    <- trimws(as.character(data_rows[[1]]))
    is_year   <- grepl("^\\d{4}-\\d{2}$", yr_raw)
    data_rows <- data_rows[is_year, ]
    yr_raw    <- yr_raw[is_year]
    if (length(yr_raw) == 0L) next

    parse_num <- function(x) {
      x <- gsub(",", "", trimws(as.character(x)))
      x[grepl("\\[", x)] <- NA_character_
      suppressWarnings(as.numeric(x))
    }

    pick_col <- function(pattern) {
      idx <- which(grepl(pattern, header_row, perl = TRUE))
      if (length(idx) == 0L) return(NA_integer_)
      idx[[1L]]
    }

    col_companies   <- pick_col(CREATIVE_HEADER_PATTERNS$companies)
    col_claims      <- pick_col(CREATIVE_HEADER_PATTERNS$claims)
    col_productions <- pick_col(CREATIVE_HEADER_PATTERNS$productions)
    col_relief      <- pick_col(CREATIVE_HEADER_PATTERNS$relief_gbp_m)
    col_status      <- pick_col(CREATIVE_HEADER_PATTERNS$status)

    take_num <- function(idx) {
      if (is.na(idx) || idx > ncol(data_rows)) return(rep(NA_real_, nrow(data_rows)))
      parse_num(data_rows[[idx]])
    }
    take_chr <- function(idx) {
      if (is.na(idx) || idx > ncol(data_rows)) return(rep(NA_character_, nrow(data_rows)))
      trimws(as.character(data_rows[[idx]]))
    }

    results[[length(results) + 1L]] <- data.frame(
      sector       = sec,
      tax_year     = yr_raw,
      companies    = take_num(col_companies),
      claims       = take_num(col_claims),
      productions  = take_num(col_productions),
      relief_gbp_m = take_num(col_relief),
      status       = take_chr(col_status),
      stringsAsFactors = FALSE
    )
  }

  if (length(results) == 0L) {
    cli::cli_abort("No Creative Industries sector tables parsed. Please file an issue.")
  }

  out <- do.call(rbind, results)
  out <- out[order(out$sector, out$tax_year), ]
  rownames(out) <- NULL
  out
}
