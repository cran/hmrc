# hmrc-tbl.R — S3 class with provenance metadata

#' Construct an `hmrc_tbl` object
#'
#' Internal constructor used by every `hmrc_*` data fetcher to attach
#' provenance metadata to the returned data frame. Not exported.
#'
#' @param x A data frame holding the parsed dataset.
#' @param dataset Short identifier (matches a row of [hmrc_publications()]).
#' @param hmrc_publication Human-readable publication name.
#' @param source_url URL of the GOV.UK publication page.
#' @param attachment_url Direct URL of the parsed attachment.
#' @param slug GOV.UK statistics slug.
#' @param cell_methods Either `"cash"`, `"accruals"`, `"liabilities"`, or
#'   `"counts"`. Helps downstream users avoid mixing apples and oranges.
#' @param frequency `"monthly"`, `"quarterly"`, `"annual"`, or `"point_in_time"`.
#' @param vintage_date `Date` of the as-of vintage; `NA` for the latest
#'   published version.
#' @return An `hmrc_tbl` (subclass of `data.frame`).
#' @noRd
new_hmrc_tbl <- function(x,
                         dataset          = NA_character_,
                         hmrc_publication = NA_character_,
                         source_url       = NA_character_,
                         attachment_url   = NA_character_,
                         slug             = NA_character_,
                         cell_methods     = NA_character_,
                         frequency        = NA_character_,
                         vintage_date     = as.Date(NA)) {
  stopifnot(is.data.frame(x))

  attr(x, "hmrc_meta") <- list(
    dataset          = dataset,
    hmrc_publication = hmrc_publication,
    source_url       = source_url,
    attachment_url   = attachment_url,
    slug             = slug,
    cell_methods     = cell_methods,
    frequency        = frequency,
    vintage_date     = vintage_date,
    fetched_at       = Sys.time(),
    package_version  = as.character(utils::packageVersion("hmrc"))
  )

  if (!inherits(x, "hmrc_tbl")) {
    class(x) <- c("hmrc_tbl", class(x))
  }
  x
}

#' Provenance metadata of an `hmrc_tbl`
#'
#' Returns the provenance list attached to a result from any `hmrc_*` data
#' fetcher: source URL, fetch time, vintage, cell methods, and so on. Useful
#' for citation, audit trails, and reproducibility.
#'
#' @param x An object returned by an `hmrc_*` data function.
#' @return A named list, or `NULL` if `x` has no metadata.
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' tr <- hmrc_tax_receipts(tax = "vat", start = "2024-01")
#' hmrc_meta(tr)
#' options(op)
#' }
#'
#' @family infrastructure
#' @export
hmrc_meta <- function(x) {
  attr(x, "hmrc_meta")
}

#' @export
print.hmrc_tbl <- function(x, ...) {
  m <- attr(x, "hmrc_meta")
  if (!is.null(m)) {
    pub <- m$hmrc_publication %||% "HMRC dataset"
    cat("# ", pub, "\n", sep = "")
    if (!is.na(m$source_url) && nzchar(m$source_url)) {
      cat("# Source: ", m$source_url, "\n", sep = "")
    }
    fetched <- if (inherits(m$fetched_at, "POSIXt")) {
      format(m$fetched_at, "%Y-%m-%d %H:%M:%S %Z", tz = "UTC")
    } else {
      "unknown"
    }
    vintage <- if (is.na(m$vintage_date)) "latest" else as.character(m$vintage_date)
    bits <- c(
      paste0("Fetched ", fetched),
      paste0("Vintage: ", vintage),
      if (!is.na(m$cell_methods)) paste0("Cells: ", m$cell_methods),
      if (!is.na(m$frequency))    paste0("Freq: ",  m$frequency),
      paste0(format(nrow(x), big.mark = ","), " rows x ", ncol(x), " cols")
    )
    cat("# ", paste(bits, collapse = " | "), "\n", sep = "")
    cat("\n")
  }
  NextMethod()
}

#' @export
format.hmrc_tbl <- function(x, ...) {
  NextMethod()
}

#' @export
as.data.frame.hmrc_tbl <- function(x, ...) {
  attr(x, "hmrc_meta") <- NULL
  class(x) <- setdiff(class(x), "hmrc_tbl")
  x
}

# Subsetting drops to plain data.frame if rows or columns are removed —
# provenance no longer reflects the full dataset.
#' @export
`[.hmrc_tbl` <- function(x, i, j, ..., drop = TRUE) {
  out <- NextMethod()
  if (is.data.frame(out)) {
    attr(out, "hmrc_meta") <- attr(x, "hmrc_meta")
    if (!inherits(out, "hmrc_tbl")) class(out) <- c("hmrc_tbl", class(out))
  }
  out
}
