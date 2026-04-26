#' Inspect the local HMRC cache
#'
#' Returns a tidy table of files currently held in the package cache, with
#' size and age. Useful for understanding what is stored locally and deciding
#' when to clear stale files via [hmrc_clear_cache()].
#'
#' @return A data frame with columns `file`, `extension`, `size_bytes`,
#'   `size_mb`, `modified` (POSIXct), `age_days`, `path`. The data frame is
#'   empty (zero rows) if the cache directory does not exist or is empty.
#'   The cache directory itself is attached as the attribute `"cache_dir"`.
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' info <- hmrc_cache_info()
#' attr(info, "cache_dir")
#' options(op)
#' }
#'
#' @family infrastructure
#' @export
hmrc_cache_info <- function() {
  cache_dir <- hmrc_cache_dir()

  empty <- data.frame(
    file        = character(0),
    extension   = character(0),
    size_bytes  = numeric(0),
    size_mb     = numeric(0),
    modified    = as.POSIXct(character(0)),
    age_days    = numeric(0),
    path        = character(0),
    stringsAsFactors = FALSE
  )
  attr(empty, "cache_dir") <- cache_dir

  if (!dir.exists(cache_dir)) return(empty)

  files <- list.files(cache_dir, full.names = TRUE, no.. = TRUE)
  if (length(files) == 0) return(empty)

  info  <- file.info(files)
  bytes <- as.numeric(info$size)
  mtime <- info$mtime
  age   <- as.numeric(difftime(Sys.time(), mtime, units = "days"))

  out <- data.frame(
    file        = basename(files),
    extension   = tools::file_ext(files),
    size_bytes  = bytes,
    size_mb     = round(bytes / (1024 ^ 2), 3),
    modified    = mtime,
    age_days    = round(age, 2),
    path        = files,
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$size_bytes), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "cache_dir") <- cache_dir
  out
}
