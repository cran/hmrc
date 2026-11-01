# utils-govuk-api.R: internal helpers for the GOV.UK Content API and caching

GOVUK_BASE              <- "https://www.gov.uk"
GOVUK_CONTENT_API       <- "https://www.gov.uk/api/content/government/statistics/"
GOVUK_PUBLICATION_PATH  <- "/government/statistics/"

#' User agent sent with every request
#' @noRd
hmrc_user_agent <- function() {
  paste0("hmrc R package ", utils::packageVersion("hmrc"),
         " (https://github.com/charlescoverdale/hmrc)")
}

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
      httr2::req_user_agent(hmrc_user_agent()) |>
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
      ), class = c("hmrc_error_network", "hmrc_error"))
    }
  )

  if (httr2::resp_status(resp) != 200L) {
    cli::cli_abort(c(
      "GOV.UK Content API returned HTTP {httr2::resp_status(resp)}.",
      "i" = "The publication slug may have changed: {.val {slug}}"
    ), class = c("hmrc_error_upstream", "hmrc_error"))
  }

  body        <- httr2::resp_body_json(resp)
  attachments <- body$details$attachments

  if (is.null(attachments) || length(attachments) == 0) {
    cli::cli_abort("No attachments found for GOV.UK slug: {.val {slug}}",
                   class = c("hmrc_error_upstream", "hmrc_error"))
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
    ), class = c("hmrc_error_upstream", "hmrc_error"))
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

#' Get the cache directory, respecting the `hmrc.cache_dir` option
#' @noRd
hmrc_cache_dir <- function() {
  getOption("hmrc.cache_dir", default = tools::R_user_dir("hmrc", "cache"))
}

#' Cache file name for a URL
#'
#' GOV.UK asset URLs have the form `.../media/<media id>/<filename>`. The
#' media id changes with every edition, so `<media id>_<filename>` is unique
#' per file and readable. Other URLs fall back to their sanitised path.
#' @noRd
hmrc_cache_key <- function(url, vintage_key = NULL) {
  path <- sub("^[a-z]+://[^/]+/", "", url)
  path <- sub("^media/", "", path)
  path <- sub("[?#].*$", "", path)
  key  <- gsub("[^A-Za-z0-9._-]+", "_", path)
  if (!is.null(vintage_key)) {
    ext <- tools::file_ext(key)
    key <- paste0(tools::file_path_sans_ext(key), "@", vintage_key,
                  if (nzchar(ext)) paste0(".", ext))
    key <- gsub("[^A-Za-z0-9._@-]+", "_", key)
  }
  if (nchar(key) > 180L) key <- substring(key, nchar(key) - 179L)
  key
}

#' Compute the cache path for a URL
#' @noRd
hmrc_cache_path <- function(url, vintage_key = NULL) {
  file.path(hmrc_cache_dir(), hmrc_cache_key(url, vintage_key = vintage_key))
}

#' Download a file with local caching
#'
#' Downloads to a temporary file in the cache directory, checks that
#' spreadsheet files are real zip containers, then renames into place, so an
#' interrupted or failed download never leaves a truncated file in the cache.
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

  ext <- tools::file_ext(cache_file)
  tmp <- tempfile("download-", tmpdir = cache_dir,
                  fileext = if (nzchar(ext)) paste0(".", ext) else "")
  on.exit(unlink(tmp), add = TRUE)

  tryCatch(
    httr2::request(url) |>
      httr2::req_user_agent(hmrc_user_agent()) |>
      httr2::req_throttle(rate = 5 / 10) |>
      httr2::req_timeout(120) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_perform(path = tmp),
    error = function(e) {
      cli::cli_abort(c(
        "Download failed.",
        "x" = conditionMessage(e)
      ), class = c("hmrc_error_network", "hmrc_error"))
    }
  )

  if (tolower(ext) %in% c("ods", "xlsx") && !is_zip_file(tmp)) {
    cli::cli_abort(c(
      "The downloaded file is not a valid spreadsheet.",
      "i" = "GOV.UK may have returned an error page. Try again later.",
      "x" = "URL: {.url {url}}"
    ), class = c("hmrc_error_upstream", "hmrc_error"))
  }

  if (!file.rename(tmp, cache_file)) {
    file.copy(tmp, cache_file, overwrite = TRUE)
  }
  cache_file
}

#' Does a file start with the zip signature? (ODS and XLSX are zip files)
#' @noRd
is_zip_file <- function(path) {
  sig <- tryCatch(readBin(path, "raw", n = 2L), error = function(e) raw(0))
  length(sig) == 2L && identical(sig, charToRaw("PK"))
}

#' Parse a GOV.UK timestamp such as "2026-08-21T07:00:03+01:00" to POSIXct UTC
#' @noRd
parse_govuk_time <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(as.POSIXct(NA))
  x <- sub("([+-]\\d{2}):(\\d{2})$", "\\1\\2", x)
  x <- sub("Z$", "+0000", x)
  out <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC")
  if (is.na(out)) as.POSIXct(NA) else out
}

#' Null coalescing operator
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x
