#' Download HMRC Corporation Tax receipts by type
#'
#' Downloads and tidies the HMRC Corporation Tax Statistics annual
#' publication, reporting receipts broken down by tax type for the
#' most recent six financial years. Published annually in September.
#'
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `tax_year`, `type`, `description`,
#'   `receipts_gbp_m`.
#'
#' @details
#' Some levies (e.g. Residential Property Developer Tax, Electricity
#' Generators Levy) were introduced mid-series and have `NA` values for
#' earlier years.
#'
#' @source
#' <https://www.gov.uk/government/collections/analyses-of-corporation-tax-receipts-and-liabilities>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_corporation_tax()
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_corporation_tax <- function(cache = TRUE) {

  current_year <- as.integer(format(Sys.Date(), "%Y"))
  loc <- NULL
  for (yr in seq(current_year, current_year - 3L)) {
    slug <- paste0("corporation-tax-statistics-", yr)
    loc <- tryCatch(
      resolve_govuk_attachment(slug, "Corporation_Tax"),
      error = function(e) NULL
    )
    if (!is.null(loc)) break
  }
  if (is.null(loc)) {
    cli::cli_abort(c(
      "Could not find Corporation Tax statistics on GOV.UK.",
      "i" = "Tried slugs for {current_year} back to {current_year - 3L}.",
      "i" = "Check {.url https://www.gov.uk/government/collections/analyses-of-corporation-tax-receipts-and-liabilities}"
    ))
  }
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_corporation_tax_table(path)
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "corporation_tax_annual",
    hmrc_publication = "Corporation Tax statistics",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = loc$slug,
    cell_methods     = "cash",
    frequency        = "annual"
  )
}

# ── Internal parser ────────────────────────────────────────────────────────────

parse_corporation_tax_table <- function(path) {
  raw <- readODS::read_ods(path, sheet = "Table_1A",
                           col_names = FALSE, as_tibble = FALSE)

  header_row <- as.character(unlist(raw[5, ]))
  year_cols  <- which(grepl("^20\\d{2}-\\d{2}$", trimws(header_row)))

  if (length(year_cols) == 0) {
    cli::cli_abort("Could not locate year columns in Corporation Tax table. Please file an issue.")
  }

  years <- trimws(header_row[year_cols])

  data_rows <- raw[6:nrow(raw), ]
  type_raw  <- trimws(as.character(data_rows[[1]]))
  valid     <- nzchar(type_raw) & !grepl("End of|^NA$", type_raw)
  data_rows <- data_rows[valid, ]
  type_raw  <- type_raw[valid]

  classify_type <- function(lbl) {
    l <- tolower(lbl)
    if (grepl("all corporate", l))                                    return("all_corporate_taxes")
    if (grepl("total.*onshore.*offshore|total.*corporation", l))      return("total_ct")
    if (grepl("onshore", l))                                          return("onshore_ct")
    if (grepl("offshore", l))                                         return("offshore_ct")
    if (grepl("bank levy|^bl$", l))                                   return("bank_levy")
    if (grepl("bank surcharge|^bs$", l))                              return("bank_surcharge")
    if (grepl("residential property developer|rpdt", l))              return("rpdt")
    if (grepl("energy profits levy|epl", l))                          return("energy_profits_levy")
    if (grepl("electricity generator", l))                            return("electricity_generators_levy")
    tolower(gsub("[^a-zA-Z0-9]+", "_", lbl))
  }

  results <- list()
  for (i in seq_len(nrow(data_rows))) {
    lbl <- type_raw[i]
    key <- classify_type(lbl)

    for (j in seq_along(year_cols)) {
      col_idx <- year_cols[j]
      if (col_idx > ncol(data_rows)) next
      val <- suppressWarnings(as.numeric(as.character(data_rows[i, col_idx])))
      results[[length(results) + 1]] <- data.frame(
        tax_year       = years[j],
        type           = key,
        description    = lbl,
        receipts_gbp_m = val,
        stringsAsFactors = FALSE
      )
    }
  }

  out <- do.call(rbind, results)
  out <- out[order(out$type, out$tax_year), ]
  rownames(out) <- NULL
  out
}
