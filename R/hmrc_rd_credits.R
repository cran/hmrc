#' Download HMRC R&D tax credit statistics
#'
#' Downloads and tidies the HMRC Research and Development Tax Credits
#' Statistics publication, covering the SME R&D Relief and Research and
#' Development Expenditure Credit (RDEC) schemes and, from 2024-25, the merged
#' scheme and Enhanced R&D Intensive Support (ERIS). Annual data runs from
#' 2016-17 to the most recent financial year, published annually in September.
#'
#' @param scheme Character vector or `NULL` (default = all schemes).
#'   Valid values: `"sme"`, `"rdec"`, `"total"`.
#' @param measure Character vector or `NULL` (default = all measures).
#'   Valid values: `"claims"`, `"amount_gbp_m"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `tax_year`, `scheme`, `description`,
#'   `measure`, `value`, and `status` (HMRC's revision label, e.g.
#'   `"Unchanged"`, `"Provisional, Revised"`, `"Provisional, Uplifted"`).
#'
#' @details
#' Figures for the most recent years are provisional and subject to revision
#' as late claims are processed; the `status` column carries HMRC's label.
#'
#' For accounting periods beginning on or after 1 April 2024 the SME and RDEC
#' schemes were replaced by the merged scheme and ERIS. HMRC reports these
#' inside the existing groupings, so the series stay comparable over time:
#' `sme` is HMRC's "SME Total" column, which includes SME intensives and
#' ERIS; `rdec` is HMRC's "RDEC & Merged RDEC Total" column ("LC & RDEC
#' Total" in editions before September 2026), which includes merged-scheme
#' claims by large companies and SMEs; and `total` is HMRC's all-schemes
#' total. The merged scheme and ERIS are not yet returned as separate
#' schemes.
#'
#' @source
#' <https://www.gov.uk/government/statistics/corporate-tax-research-and-development-tax-credit>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   rd <- hmrc_rd_credits(measure = "amount_gbp_m")
#'   tail(rd)
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_rd_credits <- function(scheme  = NULL,
                            measure = NULL,
                            cache   = TRUE) {

  valid_schemes  <- c("sme", "rdec", "total")
  valid_measures <- c("claims", "amount_gbp_m")

  if (!is.null(scheme)) {
    bad <- setdiff(scheme, valid_schemes)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown scheme{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_schemes}}"
      ))
    }
  }
  if (!is.null(measure)) {
    bad <- setdiff(measure, valid_measures)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown measure{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_measures}}"
      ))
    }
  }

  slug <- "corporate-tax-research-and-development-tax-credit"
  loc  <- resolve_govuk_attachment(slug, "rd_tax_credits_main")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_rd_credits_table(path)

  if (!is.null(scheme))  out <- out[out$scheme  %in% scheme,  ]
  if (!is.null(measure)) out <- out[out$measure %in% measure, ]
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "rd_credits_annual",
    hmrc_publication = "R&D Tax Credits Statistics",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "counts/cash",
    frequency        = "annual",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

# The RDEC total was headed "LC & RDEC Total" until the September 2026
# edition, which added the merged scheme: "RDEC & Merged RDEC Total".
RD_RDEC_TOTAL <- "^(lc (&|and) rdec|rdec (&|and) merged rdec) total$"

RD_DESC <- c(
  sme   = "SME R&D Relief and ERIS",
  rdec  = "R&D Expenditure Credit (RDEC) and merged scheme",
  total = "All R&D schemes"
)

RD_SHEETS <- list(
  claims = list(
    sheet = "RD1",
    cols  = c(status = "^status$", sme = "^sme total$",
              rdec = RD_RDEC_TOTAL, total = "^total claims$")
  ),
  amount_gbp_m = list(
    sheet = "RD2",
    cols  = c(status = "^status$", sme = "^sme total$",
              rdec = RD_RDEC_TOTAL, total = "^total cost")
  )
)

parse_rd_credits_table <- function(path) {
  pub <- "R&D Tax Credits statistics"

  results <- lapply(names(RD_SHEETS), function(measure) {
    spec <- RD_SHEETS[[measure]]
    raw  <- read_sheet_raw(path, spec$sheet, pub)

    hdr <- find_row(raw, "^financial year$")[1]
    if (is.na(hdr)) abort_schema(pub, paste0("the ", spec$sheet, " header row"))
    idx <- match_columns(unlist(raw[hdr, ]), spec$cols, pub)

    years <- parse_tax_year(raw[[1]])
    rows  <- which(!is.na(years) & seq_along(years) > hdr)
    if (length(rows) == 0L) abort_schema(pub, paste0("year rows in ", spec$sheet))
    status <- trimws(as.character(raw[[idx[["status"]]]][rows]))

    do.call(rbind, lapply(names(RD_DESC), function(k) {
      data.frame(
        tax_year    = years[rows],
        scheme      = k,
        description = RD_DESC[[k]],
        measure     = measure,
        value       = parse_num(raw[[idx[[k]]]][rows]),
        status      = status,
        stringsAsFactors = FALSE
      )
    }))
  })

  out <- do.call(rbind, results)
  out <- out[order(out$scheme, out$measure, out$tax_year), ]
  rownames(out) <- NULL
  out
}
