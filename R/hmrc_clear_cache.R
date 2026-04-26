#' Clear the local HMRC data cache
#'
#' Deletes locally cached data files downloaded by the package. By default
#' all cached files are removed; pass `max_age_days` to remove only files
#' older than that.
#'
#' @param max_age_days Numeric or `NULL`. If `NULL` (default), every cached
#'   file is removed. If a number, only files modified more than that many
#'   days ago are removed.
#'
#' @return Invisibly returns the number of files deleted.
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_clear_cache()
#' hmrc_clear_cache(max_age_days = 30)
#' options(op)
#' }
#'
#' @family infrastructure
#' @export
hmrc_clear_cache <- function(max_age_days = NULL) {
  if (!is.null(max_age_days)) {
    if (!is.numeric(max_age_days) || length(max_age_days) != 1L || max_age_days < 0) {
      cli::cli_abort("{.arg max_age_days} must be a non-negative number.")
    }
  }

  cache_dir <- hmrc_cache_dir()

  if (!dir.exists(cache_dir)) {
    cli::cli_inform("No cache directory found \u2014 nothing to clear.")
    return(invisible(0L))
  }

  files <- list.files(cache_dir, full.names = TRUE)

  if (length(files) == 0) {
    cli::cli_inform("Cache is already empty.")
    return(invisible(0L))
  }

  if (!is.null(max_age_days)) {
    mtime    <- file.mtime(files)
    age_days <- as.numeric(difftime(Sys.time(), mtime, units = "days"))
    files    <- files[age_days > max_age_days]
  }

  if (length(files) == 0) {
    cli::cli_inform("No files older than {max_age_days} day{?s} found.")
    return(invisible(0L))
  }

  unlink(files)
  cli::cli_inform("Deleted {length(files)} cached file{?s}.")
  invisible(length(files))
}
