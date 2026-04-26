#' HMRC dataset catalogue
#'
#' A data frame describing every HMRC dataset known to the package, including
#' those exposed by an `hmrc_*` function and those on the development roadmap
#' (where `function_name` is `NA`). Use [hmrc_search()] for keyword search and
#' [hmrc_publications()] for a tidy index.
#'
#' @format A data frame with columns:
#'   \describe{
#'     \item{dataset}{Character. Short identifier.}
#'     \item{publication}{Character. GOV.UK publication name.}
#'     \item{function_name}{Character. Exporting function (or `NA`).}
#'     \item{frequency}{Character. `monthly`, `quarterly`, `annual`, etc.}
#'     \item{start}{Character. First period of the published series.}
#'     \item{publisher}{Character. Usually `"HMRC"`.}
#'     \item{slug}{Character. GOV.UK statistics slug.}
#'     \item{url}{Character. URL of the publication landing page.}
#'     \item{description}{Character. One-line description.}
#'     \item{tags}{Character. Space-separated keywords searched by
#'       [hmrc_search()].}
#'   }
"catalogue"

#' Search the HMRC dataset catalogue
#'
#' Fuzzy keyword search across publication name, description, tags, and
#' dataset identifier. Returns a tidy table of matching rows so users can
#' discover what the package exposes (and what is on the roadmap).
#'
#' @param query Character. Keyword or regex pattern. Case-insensitive.
#'   Matches anywhere in `dataset`, `publication`, `description`, or `tags`.
#'   If `NULL` or empty, the full catalogue is returned.
#' @param implemented Logical or `NULL`. If `TRUE`, only rows with a
#'   working `function_name` are returned. If `FALSE`, only roadmap rows.
#'   `NULL` (default) returns both.
#' @param frequency Optional character vector to filter by frequency
#'   (e.g. `"monthly"`, `"annual"`).
#' @return A data frame, sorted with implemented datasets first.
#'
#' @examples
#' # Everything mentioning VAT
#' hmrc_search("vat")
#'
#' # Only annual publications already implemented
#' hmrc_search(implemented = TRUE, frequency = "annual")
#'
#' # Roadmap items mentioning capital gains
#' hmrc_search("capital gains", implemented = FALSE)
#'
#' @family infrastructure
#' @export
hmrc_search <- function(query = NULL, implemented = NULL, frequency = NULL) {
  cat <- catalogue
  out <- cat

  if (!is.null(query)) {
    if (!is.character(query) || length(query) != 1L) {
      cli::cli_abort("{.arg query} must be a single character string.")
    }
    if (nzchar(query)) {
      hay <- paste(out$dataset, out$publication, out$description, out$tags,
                   sep = " | ")
      hits <- grepl(query, hay, ignore.case = TRUE, perl = TRUE)
      out  <- out[hits, , drop = FALSE]
    }
  }

  if (!is.null(implemented)) {
    if (!is.logical(implemented) || length(implemented) != 1L) {
      cli::cli_abort("{.arg implemented} must be `TRUE`, `FALSE`, or `NULL`.")
    }
    has_fn <- !is.na(out$function_name)
    out    <- out[if (implemented) has_fn else !has_fn, , drop = FALSE]
  }

  if (!is.null(frequency)) {
    bad <- setdiff(frequency, unique(cat$frequency))
    if (length(bad) > 0) {
      cli::cli_warn(c(
        "Frequenc{?y/ies} not in catalogue: {.val {bad}}",
        "i" = "Available: {.val {sort(unique(cat$frequency))}}"
      ))
    }
    out <- out[out$frequency %in% frequency, , drop = FALSE]
  }

  # Implemented rows first, then alphabetical
  ord <- order(is.na(out$function_name), out$dataset)
  out <- out[ord, c("dataset", "publication", "function_name",
                    "frequency", "start", "description"), drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Index of HMRC publications known to the package
#'
#' Tidy roster of HMRC publications, marking which are exposed via an
#' `hmrc_*` function and which are on the development roadmap. Useful for
#' planning analyses, citing the package, and tracking coverage over time.
#'
#' @param status One of `"all"` (default), `"implemented"`, or `"planned"`.
#' @return A data frame with one row per publication and a `status` column
#'   (`"implemented"` or `"planned"`).
#'
#' @examples
#' # Everything in the catalogue
#' hmrc_publications()
#'
#' # Only roadmap items
#' hmrc_publications("planned")
#'
#' @family infrastructure
#' @export
hmrc_publications <- function(status = c("all", "implemented", "planned")) {
  status <- match.arg(status)

  out <- catalogue
  out$status <- ifelse(is.na(out$function_name), "planned", "implemented")

  if (status != "all") {
    out <- out[out$status == status, , drop = FALSE]
  }

  out <- out[, c("status", "dataset", "publication", "function_name",
                 "frequency", "start", "publisher", "url", "description"),
             drop = FALSE]
  ord <- order(out$status != "implemented", out$publication)
  out <- out[ord, , drop = FALSE]
  rownames(out) <- NULL
  out
}
