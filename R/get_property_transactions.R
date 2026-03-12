#' Download monthly UK property transaction counts
#'
#' Downloads and tidies the HMRC Monthly Property Transactions bulletin,
#' which counts residential and non-residential property transactions
#' (SDLT returns, LBTT in Scotland, LTT in Wales) for England, Scotland,
#' Wales, Northern Ireland, and the UK total. Data runs from April 2005
#' to the most recent completed month.
#'
#' @param type Character. One of `"all"` (default), `"residential"`, or
#'   `"non_residential"`.
#' @param nation Character vector or `NULL` (default = all nations).
#'   Valid values: `"uk"`, `"england"`, `"scotland"`, `"wales"`,
#'   `"northern_ireland"`.
#' @param start Character `"YYYY-MM"` or a `Date` object. Rows before this
#'   month are dropped.
#' @param end Character `"YYYY-MM"` or a `Date` object. Rows after this
#'   month are dropped.
#' @param cache Logical. If `TRUE` (default), the downloaded file is cached.
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{`Date`. The first day of the reference month.}
#'     \item{nation}{Character. One of `"uk"`, `"england"`, `"scotland"`,
#'       `"wales"`, or `"northern_ireland"`.}
#'     \item{type}{Character. `"residential"` or `"non_residential"`.}
#'     \item{transactions}{Numeric. Number of transactions.}
#'   }
#'
#' @source
#' <https://www.gov.uk/government/statistics/monthly-property-transactions-completed-in-the-uk-with-value-40000-or-above>
#'
#' @examples
#' \donttest{
#' # All nations, all types
#' get_property_transactions()
#'
#' # Residential only, England, since 2020
#' get_property_transactions(type = "residential", nation = "england",
#'                           start = "2020-01")
#' }
#'
#' @export
get_property_transactions <- function(type   = c("all", "residential", "non_residential"),
                                      nation = NULL,
                                      start  = NULL,
                                      end    = NULL,
                                      cache  = TRUE) {

  type <- match.arg(type)

  if (!is.null(start)) parse_month_arg(start, "start")
  if (!is.null(end))   parse_month_arg(end,   "end")

  valid_nations <- c("uk", "england", "scotland", "wales", "northern_ireland")
  if (!is.null(nation)) {
    bad <- setdiff(tolower(nation), valid_nations)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown nation{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_nations}}"
      ))
    }
    nation <- tolower(nation)
  }

  # ── Resolve + download ──
  slug <- "monthly-property-transactions-completed-in-the-uk-with-value-40000-or-above"
  url  <- resolve_govuk_url(slug, "MPT_Tab")
  path <- download_cached(url, cache = cache)

  # ── Parse ──
  cli::cli_progress_step("Parsing data")
  out <- parse_mpt_table(path)

  # ── Filter ──
  if (type != "all") {
    out <- out[out$type == type, ]
  }
  if (!is.null(nation)) {
    out <- out[out$nation %in% nation, ]
  }

  out <- filter_dates(out, start, end)

  cli::cli_progress_done()
  out
}

# ── Internal: parse the MPT ODS ───────────────────────────────────────────────

# The MPT file has separate sheets for residential and non-residential monthly data.
# Both sheets share the same structure:
#   Row 1-5: Description text
#   Row 6:   Column headers: "Month and year" | "England" | "Scotland" |
#                            "Wales" | "Northern Ireland" | "UK" | "UK (seasonally adjusted)"
#   Row 7+:  Data — dates as "April 2005", "May 2005", ...

MPT_SHEET_MAP <- c(
  residential     = "Residential_monthly",
  non_residential = "Non-residential_monthly"
)

MPT_NATION_COLS <- c(
  "England"          = "england",
  "Scotland"         = "scotland",
  "Wales"            = "wales",
  "Northern Ireland" = "northern_ireland",
  "UK"               = "uk"
)

parse_mpt_table <- function(path) {
  results <- list()

  for (type_key in names(MPT_SHEET_MAP)) {
    sheet <- MPT_SHEET_MAP[[type_key]]
    raw   <- readODS::read_ods(path, sheet = sheet,
                               col_names = FALSE, as_tibble = FALSE)

    header_row <- as.character(unlist(raw[6, ]))
    data_rows  <- raw[7:nrow(raw), ]

    dates_raw  <- trimws(as.character(data_rows[[1]]))
    dates      <- suppressWarnings(
      as.Date(paste0("01 ", dates_raw), format = "%d %B %Y")
    )

    valid      <- !is.na(dates)
    dates      <- dates[valid]
    data_rows  <- data_rows[valid, ]

    for (j in seq_along(header_row)) {
      hdr <- trimws(header_row[j])
      if (!hdr %in% names(MPT_NATION_COLS)) next

      nation_key <- MPT_NATION_COLS[[hdr]]
      vals       <- suppressWarnings(as.numeric(as.character(data_rows[[j]])))

      results[[length(results) + 1]] <- data.frame(
        date         = dates,
        nation       = nation_key,
        type         = type_key,
        transactions = vals,
        stringsAsFactors = FALSE
      )
    }
  }

  out <- do.call(rbind, results)
  out <- out[order(out$type, out$nation, out$date), ]
  rownames(out) <- NULL
  out
}
