#' Clear the local HMRC data cache
#'
#' Deletes locally cached data files downloaded by the hmrc package.
#' By default, all cached files are removed. Use `max_age_days` to
#' remove only files older than a given number of days.
#'
#' @param max_age_days Numeric or `NULL`. If `NULL` (default), all cached files
#'   are removed. If a number, only files last modified more than that many
#'   days ago are removed.
#'
#' @return Invisibly returns the number of files deleted.
#'
#' @examples
#' \donttest{
#' # Remove all cached files
#' clear_cache()
#'
#' # Remove files older than 30 days
#' clear_cache(max_age_days = 30)
#' }
#'
#' @export
clear_cache <- function(max_age_days = NULL) {
  if (!is.null(max_age_days)) {
    if (!is.numeric(max_age_days) || length(max_age_days) != 1 || max_age_days < 0) {
      cli::cli_abort("{.arg max_age_days} must be a non-negative number.")
    }
  }

  cache_dir <- tools::R_user_dir("hmrc", "cache")

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
    mtime     <- file.mtime(files)
    age_days  <- as.numeric(difftime(Sys.time(), mtime, units = "days"))
    files     <- files[age_days > max_age_days]
  }

  if (length(files) == 0) {
    cli::cli_inform("No files older than {max_age_days} day{?s} found.")
    return(invisible(0L))
  }

  unlink(files)
  cli::cli_inform("Deleted {length(files)} cached file{?s}.")
  invisible(length(files))
}
