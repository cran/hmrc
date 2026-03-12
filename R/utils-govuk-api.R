# utils-govuk-api.R — internal helpers for GOV.UK Content API + caching

GOVUK_CONTENT_API <- "https://www.gov.uk/api/content/government/statistics/"

#' Resolve the current download URL for a GOV.UK statistics attachment
#'
#' HMRC data files are hosted on assets.publishing.service.gov.uk with a
#' random media hash in the path that changes each publication cycle. This
#' function queries the GOV.UK Content API to find the current URL.
#'
#' @param slug GOV.UK statistics page slug (the path after /government/statistics/)
#' @param filename_pattern Regex pattern to identify the correct attachment
#' @return Character string: current download URL
#' @noRd
resolve_govuk_url <- function(slug, filename_pattern) {
  api_url <- paste0(GOVUK_CONTENT_API, slug)

  cli::cli_progress_step("Resolving download URL from GOV.UK Content API")

  resp <- tryCatch(
    httr2::request(api_url) |>
      httr2::req_timeout(30) |>
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

  matches[[1]]$url
}

#' Download a file with local caching
#'
#' @param url URL to download
#' @param cache Logical: use cached file if available?
#' @return Path to the local (cached) file
#' @noRd
download_cached <- function(url, cache = TRUE) {
  cache_dir  <- tools::R_user_dir("hmrc", "cache")
  # Use a hash of the URL as the cache filename, preserving extension
  ext        <- tools::file_ext(url)
  ext        <- if (nzchar(ext)) paste0(".", ext) else ""
  cache_file <- file.path(cache_dir, paste0(digest_url(url), ext))

  if (cache && file.exists(cache_file)) {
    cli::cli_progress_step("Using cached file")
    return(cache_file)
  }

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cli::cli_progress_step("Downloading data file")

  tryCatch(
    httr2::request(url) |>
      httr2::req_timeout(120) |>
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
  # Weighted checksum — collision-resistant enough for a local cache
  chars    <- utf8ToInt(url)
  weights  <- seq_along(chars)
  checksum <- sum(as.numeric(chars) * weights) %% (2^31 - 1)
  sprintf("%010.0f_%04d", as.numeric(checksum), nchar(url) %% 10000L)
}

#' Null coalescing operator
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x
