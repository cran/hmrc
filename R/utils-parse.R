# utils-parse.R: shared helpers for reading HMRC spreadsheets
#
# HMRC reorders, relabels and inserts rows and columns between editions.
# Parsers therefore locate tables by their labels and columns by their
# header text, never by fixed position, and fail loudly (class
# "hmrc_error_schema") when an expected column is missing.

#' Read one sheet as an all-character data frame
#'
#' No header row, no type guessing, no name-repair messages. Columns are
#' renamed X1, X2, ... so row subsetting never trips over empty names.
#' @noRd
read_sheet_raw <- function(path, sheet, publication = "HMRC table") {
  is_excel <- tolower(tools::file_ext(path)) %in% c("xlsx", "xls")
  sheets <- if (is_excel) readxl::excel_sheets(path) else readODS::list_ods_sheets(path)
  if (!sheet %in% sheets) {
    abort_schema(publication, paste0("sheet \"", sheet, "\""),
                 found = paste(sheets, collapse = ", "))
  }

  raw <- if (is_excel) {
    readxl::read_excel(path, sheet = sheet, col_names = FALSE,
                       col_types = "text", .name_repair = "minimal")
  } else {
    readODS::read_ods(path, sheet = sheet, col_names = FALSE,
                      col_types = NA, as_tibble = FALSE,
                      .name_repair = "minimal")
  }
  names(raw) <- paste0("X", seq_len(ncol(raw)))
  as.data.frame(raw, stringsAsFactors = FALSE)
}

#' Abort with a classed error when a table no longer has the expected shape
#' @noRd
abort_schema <- function(publication, what, found = NULL) {
  msg <- c(
    "{publication}: could not find {what}.",
    "i" = "HMRC may have changed the table layout. Please report it at {.url https://github.com/charlescoverdale/hmrc/issues}."
  )
  if (!is.null(found)) msg <- c(msg, "i" = "Found: {found}")
  cli::cli_abort(msg, class = c("hmrc_error_schema", "hmrc_error"), call = NULL)
}

#' Convert HMRC cell text to numbers
#'
#' Strips thousands separators, pound signs and percent signs. Suppression
#' and availability markers (`[x]`, `[c]`, `[z]`, `[Unavailable]`, `N/A`,
#' `[no estimate]`) and censored values such as `<0.1` become `NA`.
#' @noRd
parse_num <- function(x) {
  x <- trimws(as.character(x))
  x <- gsub("[,\u00a3%[:space:]]", "", x)
  x[grepl("^\\[|^N/?A$|^-+$|^\\.+$|^[<>]|noestimate", x, ignore.case = TRUE)] <-
    NA_character_
  suppressWarnings(as.numeric(x))
}

#' Rescale a proportion column to per cent
#'
#' HMRC stores some rates as proportions (0.179) with percent formatting.
#' Columns ending in `_pct` are returned in per cent. The rescale is applied
#' only when every value is within `[-1, 1]`, so a column already in per cent
#' is left alone.
#' @noRd
as_percent <- function(x) {
  if (all(is.na(x))) return(x)
  if (max(abs(x), na.rm = TRUE) <= 1) round(x * 100, 10) else x
}

#' Parse "January 2025" style labels to the first of the month
#'
#' Uses the English month names in `month.name` rather than `%B`, which
#' follows the user's LC_TIME locale and fails in, for example, French or
#' German sessions. Trailing bracketed notes such as `[provisional]` are
#' ignored.
#' @noRd
parse_month_year <- function(x) {
  lab <- trimws(sub("\\s*\\[.*$", "", trimws(as.character(x))))
  m   <- regmatches(lab, regexec("^([A-Za-z]+)\\.?\\s+(\\d{4})$", lab))
  days <- vapply(m, function(p) {
    if (length(p) != 3L) return(NA_real_)
    mon <- match(tolower(p[2]), tolower(month.name))
    if (is.na(mon) && nchar(p[2]) <= 4L) {
      mon <- match(tolower(substr(p[2], 1L, 3L)), tolower(month.abb))
    }
    if (is.na(mon)) return(NA_real_)
    as.numeric(as.Date(sprintf("%s-%02d-01", p[3], mon)))
  }, numeric(1))
  as.Date(days, origin = "1970-01-01")
}

#' Normalise tax-year labels to "YYYY-YY"
#'
#' Accepts "2023-24", "2023 to 2024", "2023-2024" and "2023/24", with or
#' without trailing notes such as `[Note 2]` or `(projection)`.
#' @noRd
parse_tax_year <- function(x) {
  x <- trimws(as.character(x))
  x <- trimws(gsub("\\s*(\\[[^]]*\\]|\\([^)]*\\))", "", x, perl = TRUE))
  m <- regmatches(x, regexec("^(\\d{4})\\s*(?:to|-|/)\\s*(\\d{2}|\\d{4})$",
                             x, perl = TRUE))
  vapply(m, function(p) {
    if (length(p) != 3L) return(NA_character_)
    paste0(p[2], "-", substr(p[3], nchar(p[3]) - 1L, nchar(p[3])))
  }, character(1))
}

#' Text inside a trailing parenthesis, e.g. "2023-24 (projection)" -> "projection"
#' @noRd
row_label_note <- function(x) {
  x   <- trimws(as.character(x))
  out <- rep(NA_character_, length(x))
  has <- grepl("\\(([^)]+)\\)\\s*$", x)
  out[has] <- tolower(trimws(sub("^.*\\(([^)]+)\\)\\s*$", "\\1", x[has])))
  out
}

#' Clean header cells: collapse whitespace and drop `[Note n]` markers
#' @noRd
clean_header <- function(header) {
  h <- trimws(gsub("\\s+", " ", as.character(header)))
  h <- trimws(gsub("\\s*\\[[^]]*\\]", "", h, perl = TRUE))
  h[is.na(h)] <- ""
  h
}

#' Map column keys to positions by header text
#'
#' @param header Character vector of header cells.
#' @param spec Named character vector of case-insensitive regexes.
#' @param optional Keys that may be absent (returned as `NA`).
#' @return Named integer vector of column positions.
#' @noRd
match_columns <- function(header, spec, publication, optional = character()) {
  h <- clean_header(header)
  idx <- vapply(spec, function(p) {
    hit <- which(grepl(p, h, ignore.case = TRUE, perl = TRUE))
    if (length(hit)) hit[[1L]] else NA_integer_
  }, integer(1))
  missing <- setdiff(names(spec)[is.na(idx)], optional)
  if (length(missing)) {
    abort_schema(publication,
                 paste0("the expected column", if (length(missing) > 1) "s",
                        " ", paste0("\"", missing, "\"", collapse = ", ")),
                 found = paste(h[nzchar(h)], collapse = " | "))
  }
  idx
}

#' Rows whose first-column text matches a pattern
#' @noRd
find_row <- function(raw, pattern, col = 1L) {
  x <- trimws(as.character(raw[[col]]))
  which(grepl(pattern, x, ignore.case = TRUE, perl = TRUE))
}

#' Locate a monthly table in a sheet
#'
#' Finds the rows whose first cell is a "Month YYYY" label and the header
#' row directly above them (the nearest row with text in two or more
#' columns). Works for sheets that stack financial-year, calendar-year and
#' monthly tables one below another.
#' @return A list with `header`, `rows`, `dates` and `provisional`.
#' @noRd
read_monthly_block <- function(raw, publication) {
  labels <- as.character(raw[[1]])
  dates  <- parse_month_year(labels)
  rows   <- which(!is.na(dates))
  if (!length(rows)) abort_schema(publication, "a monthly table")

  hdr <- NA_integer_
  for (i in rev(seq_len(rows[1] - 1L))) {
    cells <- trimws(as.character(unlist(raw[i, -1L])))
    text  <- cells[!is.na(cells) & nzchar(cells) &
                     is.na(suppressWarnings(as.numeric(cells)))]
    if (length(text) >= 2L) {
      hdr <- i
      break
    }
  }
  if (is.na(hdr)) abort_schema(publication, "the monthly table header")

  list(
    header      = as.character(unlist(raw[hdr, ])),
    rows        = rows,
    dates       = dates[rows],
    provisional = grepl("provisional", labels[rows], ignore.case = TRUE)
  )
}

#' snake_case identifier from a header label
#' @noRd
snake_case <- function(x) {
  x <- tolower(gsub("[^A-Za-z0-9]+", "_", x))
  gsub("^_+|_+$", "", x)
}
