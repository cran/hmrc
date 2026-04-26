#' Download HMRC tax receipts and National Insurance contributions
#'
#' Downloads and tidies the monthly HMRC Tax Receipts and National Insurance
#' Contributions bulletin published on GOV.UK. The bulletin covers all major
#' UK taxes and duties from April 2008 to the most recent month (monthly
#' granularity), updated on approximately the 15th working day of each month.
#'
#' @param tax Character vector of tax head identifiers, or `NULL` (default)
#'   to return all available series. Use [hmrc_list_tax_heads()] to see valid
#'   values and descriptions.
#' @param start Character `"YYYY-MM"` or a `Date` object. If provided, rows
#'   before this month are dropped.
#' @param end Character `"YYYY-MM"` or a `Date` object. If provided, rows
#'   after this month are dropped.
#' @param cache Logical. If `TRUE` (default), the downloaded file is cached
#'   locally and reused on subsequent calls. Use [hmrc_clear_cache()] to
#'   reset.
#'
#' @return An `hmrc_tbl` (subclass of `data.frame`) with columns:
#'   \describe{
#'     \item{date}{`Date`. The first day of the reference month.}
#'     \item{tax_head}{Character. Tax or duty identifier (see
#'       [hmrc_list_tax_heads()]).}
#'     \item{description}{Character. Plain-English series label.}
#'     \item{receipts_gbp_m}{Numeric. Cash receipts in millions of pounds (GBP).}
#'   }
#'   Provenance metadata (source URL, fetch time, vintage) is attached as
#'   the `"hmrc_meta"` attribute and can be inspected with [hmrc_meta()].
#'
#' @source
#' <https://www.gov.uk/government/statistics/hmrc-tax-and-nics-receipts-for-the-uk>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_tax_receipts()
#' hmrc_tax_receipts(tax = c("income_tax", "vat"))
#' hmrc_tax_receipts(start = "2020-04")
#' hmrc_tax_receipts(tax = "vat", start = "2019-01", end = "2024-12")
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_tax_receipts <- function(tax = NULL, start = NULL, end = NULL, cache = TRUE) {

  if (!is.null(tax)) {
    valid <- tax_heads$tax_head
    bad   <- setdiff(tax, valid)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown tax head{?s}: {.val {bad}}",
        "i" = "Run {.fn hmrc_list_tax_heads} to see valid values."
      ))
    }
  }
  if (!is.null(start)) parse_month_arg(start, "start")
  if (!is.null(end))   parse_month_arg(end,   "end")

  slug <- "hmrc-tax-and-nics-receipts-for-the-uk"
  loc  <- resolve_govuk_attachment(slug, "NS_Table\\.ods")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  raw <- parse_ns_table(path)

  if (!is.null(tax)) {
    raw <- raw[raw$tax_head %in% tax, ]
  }
  raw <- filter_dates(raw, start, end)
  rownames(raw) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    raw,
    dataset          = "tax_receipts_monthly",
    hmrc_publication = "HMRC tax receipts and NICs (monthly bulletin)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "cash",
    frequency        = "monthly"
  )
}

# ── Internal: parse the NS_Table.ods ──────────────────────────────────────────

# Column header label → snake_case identifier mapping
# Only top-level series (no "(included within ...)" sub-components)
NS_COL_MAP <- c(
  "Total HMRC Receipts"               = "total_receipts",
  "Income Tax"                        = "income_tax",
  "Capital Gains Tax"                 = "capital_gains_tax",
  "Apprenticeship Levy"               = "apprenticeship_levy",
  "National Insurance Contributions"  = "nics_total",
  "PAYE NIC1 (EMP'er)"                = "nics_employer",
  "PAYE NIC1 (EMP'ee)"                = "nics_employee",
  "SA NIC2&4"                         = "nics_self_employed",
  "Value Added Tax"                   = "vat",
  "Corporation Tax"                   = "corporation_tax",
  "Bank Levy"                         = "bank_levy",
  "Bank Surcharge"                    = "bank_surcharge",
  "Diverted Profits Tax"              = "diverted_profits_tax",
  "Digital Services Tax"              = "digital_services_tax",
  "Residential Property Developer Tax"= "residential_property_developer_tax",
  "Energy Profits Levy"               = "energy_profits_levy",
  "Electricity Generators Levy"       = "electricity_generators_levy",
  "Economic Crime Levy"               = "economic_crime_levy",
  "Bank payroll tax"                  = "bank_payroll_tax",
  "Petroleum Revenue Tax"             = "petroleum_revenue_tax",
  "Hydrocarbon Oil (Fuel duties)"     = "fuel_duty",
  "Inheritance Tax"                   = "inheritance_tax",
  "Stamp Duty Shares"                 = "stamp_duty_shares",
  "Stamp Duty Land Tax"               = "sdlt",
  "Annual Tax on Enveloped Dwellings" = "ated",
  "Tobacco Duties"                    = "tobacco_duty",
  "Spirits Duties"                    = "spirits_duty",
  "Beer Duties"                       = "beer_duty",
  "Wines Duties"                      = "wine_duty",
  "Cider Duties"                      = "cider_duty",
  "Betting & Gaming"                  = "gambling_duties",
  "Air Passenger Duty"                = "air_passenger_duty",
  "Insurance Premium Tax"             = "insurance_premium_tax",
  "Landfill Tax"                      = "landfill_tax",
  "Climate Change Levy"               = "climate_change_levy",
  "Aggregates Levy"                   = "aggregates_levy",
  "Soft Drinks Industry Levy"         = "soft_drinks_levy",
  "Plastic Packaging Tax"             = "plastic_packaging_tax",
  "Customs Duties"                    = "customs_duties",
  "Misc"                              = "miscellaneous",
  "Penalties"                         = "penalties"
)

parse_ns_table <- function(path) {
  raw <- readODS::read_ods(path, sheet = "Receipts_Monthly",
                           col_names = FALSE, as_tibble = FALSE)

  header_row <- as.character(unlist(raw[6, ]))
  data_rows  <- raw[7:nrow(raw), ]

  dates_raw <- trimws(as.character(data_rows[[1]]))
  dates     <- suppressWarnings(
    as.Date(paste0("01 ", dates_raw), format = "%d %B %Y")
  )

  valid     <- !is.na(dates)
  dates     <- dates[valid]
  data_rows <- data_rows[valid, ]

  results <- list()

  for (j in seq_along(header_row)) {
    hdr <- trimws(header_row[j])
    if (j == 1) next
    if (grepl("included within", hdr, ignore.case = TRUE)) next
    if (!hdr %in% names(NS_COL_MAP)) next

    key  <- NS_COL_MAP[[hdr]]
    desc <- tax_heads$description[match(key, tax_heads$tax_head)]
    if (is.na(desc)) desc <- hdr

    vals <- suppressWarnings(as.numeric(as.character(data_rows[[j]])))

    results[[length(results) + 1]] <- data.frame(
      date           = dates,
      tax_head       = key,
      description    = desc,
      receipts_gbp_m = vals,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, results)
  out <- out[order(out$tax_head, out$date), ]
  rownames(out) <- NULL
  out
}
