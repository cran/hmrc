#' Download HMRC Creative Industries tax relief statistics
#'
#' Downloads and tidies Table 1 (annual time series) of the HMRC Creative
#' Industries Statistics for each of the eight creative-industries reliefs:
#' Film, High-end TV, Animation, Children's TV, Video Games, Theatre,
#' Orchestra, and Museums and Galleries Exhibition. Published annually
#' in August or September.
#'
#' @param sector Character vector or `NULL` (default = all sectors).
#'   Valid values: `"film"`, `"high_end_tv"`, `"animation"`,
#'   `"childrens_tv"`, `"video_games"`, `"theatre"`, `"orchestra"`,
#'   `"museum"`. Any relief HMRC adds to the release later as its own
#'   `Table_1_*` sheet is included when `sector = NULL`, keyed by a
#'   snake_case version of its sheet name.
#' @param tax_year Character vector or `NULL` (default = all years).
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns:
#'   \describe{
#'     \item{sector}{Character. Creative-industries sector identifier.}
#'     \item{tax_year}{Character. Tax year, e.g. `"2023-24"`.}
#'     \item{companies}{Numeric. Number of companies (where reported).}
#'     \item{claims}{Numeric. Number of claims (where reported).}
#'     \item{productions}{Numeric. Number of productions (films,
#'       programmes, games, exhibitions, etc., where reported).}
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
#' From the September 2026 edition the film, TV, animation and video games
#' tables report the legacy tax relief alongside the expenditure credits that
#' replace it: the Audio-Visual Expenditure Credit (AVEC), the Independent
#' Film Tax Credit (IFTC) and the Video Games Expenditure Credit (VGEC). For
#' those sectors this function returns HMRC's "total" columns, which cover
#' the legacy relief and the credits together and are the columns HMRC says
#' to use when comparing years. The split by relief type is not returned.
#'
#' @source
#' <https://www.gov.uk/government/collections/creative-industries-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   film <- hmrc_creative_industries(sector = "film")
#'   tail(film)
#' })
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

  if (!is.null(sector)) out <- out[out$sector %in% sector, ]
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
    cell_methods     = "accruals",
    frequency        = "annual",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

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

CREATIVE_COLS <- c(
  companies    = "^number of companies",
  claims       = "^number of claims",
  productions  = "^number of (films|programmes|games|productions|exhibitions|tours|orchestral concerts|theatrical productions|concerts)",
  relief_gbp_m = "^amount of relief",
  status       = "^status$"
)

parse_creative_industries <- function(path) {
  pub <- "Creative Industries statistics"
  available <- readODS::list_ods_sheets(path)

  # Known sectors keep their keys; any other "Table_1_*" sheet is a relief
  # HMRC has added since, keyed from its sheet name.
  extra  <- setdiff(grep("^Table_1_", available, value = TRUE), CREATIVE_SECTOR_SHEETS)
  sheets <- c(CREATIVE_SECTOR_SHEETS[CREATIVE_SECTOR_SHEETS %in% available],
              stats_names(extra, snake_case(sub("^Table_1_", "", extra))))

  results <- list()
  for (sec in names(sheets)) {
    raw <- read_sheet_raw(path, sheets[[sec]], pub)

    hdr <- find_row(raw, "^year$")[1]
    if (is.na(hdr)) next
    idx <- match_columns(creative_total_header(unlist(raw[hdr, ])),
                         CREATIVE_COLS, pub,
                         optional = c("companies", "claims", "productions", "status"))

    years <- parse_tax_year(raw[[1]])
    rows  <- which(!is.na(years) & seq_along(years) > hdr)
    if (length(rows) == 0L) next

    take_num <- function(key) {
      if (is.na(idx[[key]])) return(rep(NA_real_, length(rows)))
      parse_num(raw[[idx[[key]]]][rows])
    }
    status <- if (is.na(idx[["status"]])) {
      rep(NA_character_, length(rows))
    } else {
      trimws(as.character(raw[[idx[["status"]]]][rows]))
    }

    results[[length(results) + 1L]] <- data.frame(
      sector       = sec,
      tax_year     = years[rows],
      companies    = take_num("companies"),
      claims       = take_num("claims"),
      productions  = take_num("productions"),
      relief_gbp_m = take_num("relief_gbp_m"),
      status       = status,
      stringsAsFactors = FALSE
    )
  }

  if (length(results) == 0L) {
    abort_schema(pub, "any sector tables",
                 found = paste(available, collapse = ", "))
  }

  out <- do.call(rbind, results)
  out <- out[order(out$sector, out$tax_year), ]
  rownames(out) <- NULL
  out
}

#' Keep only the all-reliefs columns where a sheet splits by relief type
#'
#' Sheets that carry an expenditure credit repeat each measure per relief
#' ("Number of companies: tax relief", "...: AVEC", "...: total"). The
#' "total" columns are the comparable series, so the per-relief columns are
#' blanked before matching. Sheets without a split are returned unchanged.
#' @noRd
creative_total_header <- function(header) {
  h <- clean_header(header)
  if (!any(grepl(":\\s*total$", h, ignore.case = TRUE))) return(h)
  h[grepl(":", h, fixed = TRUE) & !grepl(":\\s*total$", h, ignore.case = TRUE)] <- ""
  h
}

#' Name a character vector (base equivalent of stats::setNames)
#' @noRd
stats_names <- function(x, nm) {
  names(x) <- nm
  x
}
