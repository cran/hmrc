# utils-dates.R — shared date filtering helper

#' Filter a data frame by start/end month
#'
#' @param df Data frame with a `date` column (Date class).
#' @param start Character "YYYY-MM", Date, or NULL.
#' @param end   Character "YYYY-MM", Date, or NULL.
#' @return Filtered data frame.
#' @noRd
filter_dates <- function(df, start = NULL, end = NULL) {
  if (!is.null(start)) {
    start <- parse_month_arg(start, "start")
    df    <- df[df$date >= start, ]
  }
  if (!is.null(end)) {
    end <- parse_month_arg(end, "end")
    # Include the full end month
    end_last <- as.Date(format(end, "%Y-%m-01")) + 31
    end_last <- as.Date(format(end_last, "%Y-%m-01")) - 1
    df <- df[df$date <= end_last, ]
  }
  df
}

#' Parse a month argument to a Date (first of that month)
#' @noRd
parse_month_arg <- function(x, arg_name) {
  if (inherits(x, "Date")) return(as.Date(format(x, "%Y-%m-01")))
  if (is.character(x) && grepl("^\\d{4}-\\d{2}$", x)) {
    return(as.Date(paste0(x, "-01")))
  }
  cli::cli_abort(c(
    "{.arg {arg_name}} must be a {.cls Date} or a character string in {.val YYYY-MM} format.",
    "x" = "Got: {.val {x}}"
  ))
}
