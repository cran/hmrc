#' Download HMRC Corporation Tax receipts by type
#'
#' Downloads and tidies the HMRC Corporation Tax Statistics annual
#' publication, reporting receipts broken down by tax type for the
#' most recent six financial years. Published annually in September.
#'
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{tax_year}{Character. Financial year, e.g. `"2023-24"`.}
#'     \item{type}{Character. Tax type identifier.}
#'     \item{description}{Character. Plain-English label.}
#'     \item{receipts_gbp_m}{Numeric. Receipts in millions of pounds.}
#'   }
#'
#' @details
#' Note that some levies (e.g. Residential Property Developer Tax,
#' Electricity Generators Levy) were introduced mid-series and will
#' have `NA` values for earlier years.
#'
#' @source
#' <https://www.gov.uk/government/collections/analyses-of-corporation-tax-receipts-and-liabilities>
#'
#' @examples
#' \donttest{
#' get_corporation_tax()
#' }
#'
#' @export
get_corporation_tax <- function(cache = TRUE) {

  # The CT statistics page URL changes each year (e.g. corporation-tax-statistics-2025)
  # Use the collection page to find the current publication
  slug <- "corporation-tax-statistics-2025"
  url  <- tryCatch(
    resolve_govuk_url(slug, "Corporation_Tax"),
    error = function(e) {
      # Try previous year if current year slug not found
      resolve_govuk_url("corporation-tax-statistics-2024", "Corporation_Tax")
    }
  )
  path <- download_cached(url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_corporation_tax_table(path)

  cli::cli_progress_done()
  out
}

# ── Internal parser ────────────────────────────────────────────────────────────

parse_corporation_tax_table <- function(path) {
  raw <- readODS::read_ods(path, sheet = "Table_1A",
                           col_names = FALSE, as_tibble = FALSE)

  # Transposed layout: row 5 = sub-table label + year headers in cols B+
  # Rows 6–14 = one row per tax type
  # Col 1 = tax type labels; cols 2+ = financial years

  header_row <- as.character(unlist(raw[5, ]))
  # Financial year columns: find cols matching "20XX-XX" pattern
  year_cols <- which(grepl("^20\\d{2}-\\d{2}$", trimws(header_row)))

  if (length(year_cols) == 0) {
    cli::cli_abort("Could not locate year columns in Corporation Tax table. Please file an issue.")
  }

  years <- trimws(header_row[year_cols])

  # Tax type rows: rows 6 to end (before "End of worksheet")
  data_rows <- raw[6:nrow(raw), ]
  type_raw  <- trimws(as.character(data_rows[[1]]))
  valid     <- nzchar(type_raw) & !grepl("End of|^NA$", type_raw)
  data_rows <- data_rows[valid, ]
  type_raw  <- type_raw[valid]

  # Map raw labels to identifiers (patterns matched case-insensitively via grepl)
  # Labels vary across publication years so we match by keyword
  classify_type <- function(lbl) {
    l <- tolower(lbl)
    if (grepl("all corporate", l))                    return("all_corporate_taxes")
    if (grepl("total.*onshore.*offshore|total.*corporation", l)) return("total_ct")
    if (grepl("onshore", l))                          return("onshore_ct")
    if (grepl("offshore", l))                         return("offshore_ct")
    if (grepl("bank levy|^bl$", l))                   return("bank_levy")
    if (grepl("bank surcharge|^bs$", l))              return("bank_surcharge")
    if (grepl("residential property developer|rpdt", l)) return("rpdt")
    if (grepl("energy profits levy|epl", l))          return("energy_profits_levy")
    if (grepl("electricity generator", l))            return("electricity_generators_levy")
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
