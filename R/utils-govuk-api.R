# utils-govuk-api.R — internal helpers for GOV.UK Content API + caching

GOVUK_BASE              <- "https://www.gov.uk"
GOVUK_CONTENT_API       <- "https://www.gov.uk/api/content/government/statistics/"
GOVUK_PUBLICATION_PATH  <- "/government/statistics/"

#' Resolve the current download URL for a GOV.UK statistics attachment
#'
#' HMRC files are hosted on `assets.publishing.service.gov.uk` with a media
#' hash in the path that changes each publication cycle. This function queries
#' the GOV.UK Content API and returns a list with both the publication page
#' URL and the resolved attachment URL.
#'
#' @param slug GOV.UK statistics page slug.
#' @param filename_pattern Regex pattern to identify the correct attachment.
#' @return A list with `page_url`, `attachment_url`, `attachment_name`,
#'   `slug`, and (when present) `public_updated_at`.
#' @noRd
resolve_govuk_attachment <- function(slug, filename_pattern) {
  api_url <- paste0(GOVUK_CONTENT_API, slug)

  cli::cli_progress_step("Resolving download URL from GOV.UK Content API")

  resp <- tryCatch(
    httr2::request(api_url) |>
      httr2::req_user_agent("hmrc R package (https://github.com/charlescoverdale/hmrc)") |>
      httr2::req_throttle(rate = 5 / 10) |>
      httr2::req_timeout(30) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_error(is_error = function(r) FALSE) |>
      httr2::req_perform(),
    error = function(e) {
      cli::cli_abort(c(
        "Could not reach GOV.UK Content API.",
        "i" = "Check your internet connection.",
        "x" = conditionMessage(e)
      ))
    }
  )

  if (httr2::resp_status(resp) != 200L) {
    cli::cli_abort(c(
      "GOV.UK Content API returned HTTP {httr2::resp_status(resp)}.",
      "i" = "The publication slug may have changed: {.val {slug}}"
    ))
  }

  body        <- httr2::resp_body_json(resp)
  attachments <- body$details$attachments

  if (is.null(attachments) || length(attachments) == 0) {
    cli::cli_abort("No attachments found for GOV.UK slug: {.val {slug}}")
  }

  matches <- Filter(
    function(a) grepl(filename_pattern, a$filename %||% "", ignore.case = TRUE),
    attachments
  )

  if (length(matches) == 0) {
    filenames <- vapply(attachments, function(a) a$filename %||% "(unnamed)", character(1))
    cli::cli_abort(c(
      "No attachment matching {.val {filename_pattern}} found.",
      "i" = "Available files: {.val {filenames}}"
    ))
  }

  page_url <- paste0(GOVUK_BASE, GOVUK_PUBLICATION_PATH, slug)

  list(
    slug              = slug,
    page_url          = page_url,
    attachment_url    = matches[[1]]$url,
    attachment_name   = matches[[1]]$filename %||% NA_character_,
    public_updated_at = body$public_updated_at %||% NA_character_
  )
}

#' Backwards-compatible wrapper returning just the attachment URL.
#' @noRd
resolve_govuk_url <- function(slug, filename_pattern) {
  resolve_govuk_attachment(slug, filename_pattern)$attachment_url
}

#' Get the cache directory, respecting the `hmrc.cache_dir` option
#' @noRd
hmrc_cache_dir <- function() {
  getOption("hmrc.cache_dir", default = tools::R_user_dir("hmrc", "cache"))
}

#' Compute the cache filename for a URL
#' @noRd
hmrc_cache_path <- function(url, vintage_key = NULL) {
  cache_dir <- hmrc_cache_dir()
  ext       <- tools::file_ext(url)
  ext       <- if (nzchar(ext)) paste0(".", ext) else ""
  hash      <- digest_url(if (is.null(vintage_key)) url else paste0(url, "@", vintage_key))
  file.path(cache_dir, paste0(hash, ext))
}

#' Download a file with local caching
#'
#' @param url URL to download.
#' @param cache Logical: use cached file if available?
#' @param vintage_key Optional string mixed into the cache key so vintage
#'   downloads do not collide with the latest version.
#' @return Path to the local (cached) file.
#' @noRd
download_cached <- function(url, cache = TRUE, vintage_key = NULL) {
  cache_dir  <- hmrc_cache_dir()
  cache_file <- hmrc_cache_path(url, vintage_key = vintage_key)

  if (cache && file.exists(cache_file)) {
    cli::cli_progress_step("Using cached file")
    return(cache_file)
  }

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cli::cli_progress_step("Downloading data file")

  tryCatch(
    httr2::request(url) |>
      httr2::req_user_agent("hmrc R package (https://github.com/charlescoverdale/hmrc)") |>
      httr2::req_throttle(rate = 5 / 10) |>
      httr2::req_timeout(120) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_perform(path = cache_file),
    error = function(e) {
      if (file.exists(cache_file)) unlink(cache_file)
      cli::cli_abort(c(
        "Download failed.",
        "x" = conditionMessage(e)
      ))
    }
  )

  cache_file
}

#' Simple URL hash for cache filenames (no extra dependencies)
#' @noRd
digest_url <- function(url) {
  chars    <- utf8ToInt(url)
  weights  <- seq_along(chars)
  checksum <- sum(as.numeric(chars) * weights) %% (2^31 - 1)
  sprintf("%010.0f_%04d", as.numeric(checksum), nchar(url) %% 10000L)
}

#' Null coalescing operator
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x
