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
#' @param start Character `"YYYY-MM"` or a `Date` object.
#' @param end Character `"YYYY-MM"` or a `Date` object.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `date`, `nation`, `type`,
#'   `transactions`.
#'
#' @source
#' <https://www.gov.uk/government/statistics/monthly-property-transactions-completed-in-the-uk-with-value-40000-or-above>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_property_transactions()
#' hmrc_property_transactions(type = "residential", nation = "england",
#'                            start = "2020-01")
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_property_transactions <- function(type   = c("all", "residential", "non_residential"),
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

  slug <- "monthly-property-transactions-completed-in-the-uk-with-value-40000-or-above"
  loc  <- resolve_govuk_attachment(slug, "MPT_Tab")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_mpt_table(path)

  if (type != "all") {
    out <- out[out$type == type, ]
  }
  if (!is.null(nation)) {
    out <- out[out$nation %in% nation, ]
  }

  out <- filter_dates(out, start, end)
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "property_transactions_monthly",
    hmrc_publication = "Monthly UK property transactions",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "counts",
    frequency        = "monthly"
  )
}

# ── Internal parser ────────────────────────────────────────────────────────────

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

    valid     <- !is.na(dates)
    dates     <- dates[valid]
    data_rows <- data_rows[valid, ]

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
