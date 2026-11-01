# hmrc 0.4.1

HMRC changed the layout or file names of several publications between June
and August 2026. This release repairs every fetcher against the current
editions, fixes value errors that were returned without warning, and
removes the example error reported by CRAN's `--run-donttest` check.

## Fixes that change returned values

* `hmrc_stamp_duty()`: `type = "total"` returned the "All shares" column
  (GBP 4,320m in 2024-25) instead of total stamp receipts (GBP 18,205m). It
  now returns the true total. A new type, `"shares_total"`, returns
  stamp taxes on shares.
* `hmrc_tax_gap()` returned unusable values after HMRC moved the Measuring
  Tax Gaps tables to a time series in June 2026. It is rewritten to return
  every year from 2005-06, with columns `tax_year`, `tax`, `type`,
  `component`, `gap_pct` and `gap_gbp_bn`, and gains a `tax_year` argument
  (`"latest"` is accepted). The `taxpayer_type` column is now `type`, and
  `uncertainty` is dropped because HMRC no longer publishes it in these
  tables.
* `hmrc_income_tax_stats()`: `average_rate_pct` held proportions (0.179)
  rather than per cent (17.9). It is now in per cent. A new `estimate`
  column marks outturn and projected years.
* `hmrc_inheritance_tax()`: `effective_rate_pct` is now in per cent.
* `hmrc_capital_gains()` no longer drops years whose label carries a
  footnote marker (2008-09 was missing).
* `hmrc_patent_box()` keeps the latest projected year and adds a `status`
  column.
* `hmrc_creative_industries()` now returns `productions` for high-end TV,
  animation and children's TV, which label the column "Number of
  programmes".
* `hmrc_creative_industries()`: the September 2026 edition splits the film,
  high-end TV, animation, children's TV and video games tables into the
  legacy tax relief and the expenditure credits that replace it (AVEC, the
  Independent Film Tax Credit and VGEC). The function now returns HMRC's
  "total" columns for those sectors. Without this it would have returned
  the legacy relief alone (GBP 131m for film in 2024-25 against a total of
  GBP 702m).
* Monthly fetchers (`hmrc_tax_receipts()`, `hmrc_vat()`,
  `hmrc_fuel_duties()`, `hmrc_tobacco_duties()`,
  `hmrc_property_transactions()`) returned no rows in sessions with a
  non-English time locale (for example French or German), because month
  names were parsed with the locale. Month names are now matched in
  English whatever the locale.

## Fixes for upstream changes

* `hmrc_fuel_duties()` failed because HMRC retitled the monthly table.
  Columns are now matched by header, so petrol and diesel come from HMRC's
  own totals rather than a positional sum.
* `hmrc_inheritance_tax()` failed because HMRC renamed the file to
  `table_12_1_final.ods`.
* Every parser now locates tables by their labels and columns by their
  header text instead of fixed rows and positions, and fails with a
  classed `hmrc_error_schema` error naming the missing column when HMRC
  changes a layout.
* `hmrc_rd_credits()` reads the September 2026 edition, the first to cover
  the merged scheme and Enhanced R&D Intensive Support (ERIS). HMRC renamed
  the RDEC total to "RDEC & Merged RDEC Total" and cut the tables back to
  start in 2016-17 (previously 2000-01). `rdec` now includes merged-scheme
  claims and `sme` includes ERIS, as HMRC reports them, and the
  `description` labels say so. The merged scheme and ERIS are not yet
  returned as separate schemes.
* `hmrc_tax_receipts()`: HMRC relabelled "Electricity Generators Levy" as
  "Electricity Generator Levy" in the September 2026 bulletin. The series
  keeps its `electricity_generators_levy` identifier.

## Additions

* `hmrc_fuel_duties()`, `hmrc_tobacco_duties()` and
  `hmrc_property_transactions()` gain a logical `provisional` column.
* `hmrc_rd_credits()` and `hmrc_capital_gains()` gain a `status` column.
* `hmrc_tax_receipts()` returns `total_paid_over`. New series HMRC adds to
  the bulletin (Vaping Products Duty is due from October 2026) are returned
  under a snake_case `tax_head` with a one-off message instead of being
  dropped.
* `hmrc_meta()` now records `published_at`, the GOV.UK publication time of
  the edition the data came from.

## Internals

* Cache files are named `<media id>_<filename>`. The previous checksum key
  could give two different files the same name and silently serve the
  wrong one. Files cached by earlier versions are no longer used;
  `hmrc_clear_cache()` removes them.
* Downloads are written to a temporary file, checked to be a valid
  spreadsheet, then moved into the cache, so an interrupted download no
  longer leaves a truncated file behind.
* readODS no longer prints "New names" messages for every sheet read.
* Network errors carry the classes `hmrc_error_network` and
  `hmrc_error_upstream`.
* Examples run inside `try()` and cache to a subdirectory of `tempdir()`.
* Tests check values as well as structure, including internal totals, and
  never touch the user's cache.

## Documentation

* Monthly tax receipts start in April 2017 (HMRC's table is a rolling
  window), not April 2008 as previously documented. The catalogue's start
  years, dead links and descriptions are corrected, and README outputs are
  regenerated from live data.

# hmrc 0.4.0

## New data fetchers (Phase 2 of the v1.0.0 roadmap, partial)

* `hmrc_capital_gains()`: Table 1 of the Capital Gains Tax statistics:
  estimated number of CGT taxpayers, gains, and tax liabilities by year of
  disposal, in tidy long format (`tax_year`, `measure`, `value`). Series
  begins 1987-88; published annually each summer.
* `hmrc_inheritance_tax()`: Table 12.1a of the Inheritance Tax Liabilities
  Statistics: numbers of estates, tax due, average tax, and average
  effective tax rate by net-estate band, for the latest year of death.
  Annual cross-section (~3-year publication lag).
* `hmrc_patent_box()`: Table 1 of the Patent Box reliefs statistics:
  annual companies electing into the regime and total relief claimed.
  Series begins 2013-14; published annually in September.
* `hmrc_creative_industries()`: Table 1 of the Creative Industries
  statistics for all eight sector reliefs (Film, High-end TV, Animation,
  Children's TV, Video Games, Theatre, Orchestra, Museums and Galleries).
  Annual time series back to the relief introduction date for each sector.

The catalogue (`catalogue` data, `hmrc_search()`, `hmrc_publications()`)
now reflects 14 implemented datasets (out of 23 known publications).

## Architecture refresh (Phase 1 of the v1.0.0 roadmap)

This release brings the package up to feature parity with sibling Coverdale
packages (`boe`, `fred`, `ons`, `obr`) on infrastructure: a provenance-aware
S3 class, a searchable dataset catalogue, and cache inspection.

### New: `hmrc_tbl` S3 class with provenance metadata

* All `hmrc_*` data fetchers now return an `hmrc_tbl` (a subclass of
  `data.frame`) with a `"hmrc_meta"` attribute containing the source URL,
  attachment URL, fetch time, vintage, cell methods (cash / accruals /
  liabilities / counts), frequency, and package version.
* New generic `print.hmrc_tbl()` shows a 2-line provenance header followed
  by the data, e.g. `Source:`, `Fetched: ... | Vintage: latest | Cells:
  cash | Freq: monthly | 1,234 rows x 4 cols`.
* New helper `hmrc_meta()` extracts the metadata list for citation, audit
  trails, and reproducibility.
* `as.data.frame()` strips the class and metadata cleanly for downstream
  tidyverse use; subsetting via `[` preserves the class and provenance.

### New: dataset catalogue and discovery

* New exported data frame `catalogue` describes every HMRC dataset known
  to the package, including those on the development roadmap (where
  `function_name` is `NA`).
* New `hmrc_search(query, implemented, frequency)` for fuzzy keyword search
  across publication name, description, tags, and dataset identifier.
* New `hmrc_publications(status)` returns a tidy index of implemented
  versus planned publications.

### New: cache inspection

* New `hmrc_cache_info()` returns a tidy table of cached files with size,
  modified time, and age in days. The cache directory is attached as the
  `"cache_dir"` attribute.

### Renamed: `get_*` -> `hmrc_*`

All exported data functions adopt the `hmrc_*` prefix to match sibling
packages and improve discoverability:

| Before                       | After                          |
|------------------------------|--------------------------------|
| `get_tax_receipts()`         | `hmrc_tax_receipts()`          |
| `get_vat()`                  | `hmrc_vat()`                   |
| `get_fuel_duties()`          | `hmrc_fuel_duties()`           |
| `get_tobacco_duties()`       | `hmrc_tobacco_duties()`        |
| `get_corporation_tax()`      | `hmrc_corporation_tax()`       |
| `get_stamp_duty()`           | `hmrc_stamp_duty()`            |
| `get_property_transactions()`| `hmrc_property_transactions()` |
| `get_income_tax_stats()`     | `hmrc_income_tax_stats()`      |
| `get_rd_credits()`           | `hmrc_rd_credits()`            |
| `get_tax_gap()`              | `hmrc_tax_gap()`               |
| `list_tax_heads()`           | `hmrc_list_tax_heads()`        |
| `clear_cache()`              | `hmrc_clear_cache()`           |

The old `get_*` and `clear_cache()` / `list_tax_heads()` names continue
to work but emit a one-time-per-session deprecation warning via
`lifecycle::deprecate_warn()`. They will be removed in v0.6.0.

### Citation infrastructure

* New `inst/CITATION` so `citation("hmrc")` returns a structured
  citation.
* New `CITATION.cff` at the repo root for the GitHub citation widget and
  Zenodo DOI deposit.

### Internals

* `resolve_govuk_url()` is now a thin wrapper around new
  `resolve_govuk_attachment()`, which returns both the publication page
  URL and the attachment URL plus public-update timestamp. This enables
  every `hmrc_*` function to record a stable source URL on every result.
* New `Imports`: `lifecycle` (for deprecation warnings), `utils`.

# hmrc 0.3.3

* `get_corporation_tax()` now dynamically detects the latest publication year
  instead of using a hardcoded slug. This prevents the function from breaking
  when HMRC publishes a new annual edition.

# hmrc 0.3.2

* Removed non-existent pkgdown URL from DESCRIPTION.

# hmrc 0.3.1

* Examples now cache to `tempdir()` instead of the user's home directory,
  fixing CRAN policy compliance for `\donttest` examples.
* Cache directory is now configurable via `options(hmrc.cache_dir = ...)`.

# hmrc 0.3.0

* Added `get_income_tax_stats()`: annual Income Tax liabilities by income range,
  including taxpayer counts, total income, tax liabilities, and average tax rates
  (Table 2.5).

# hmrc 0.2.0

* Added `get_vat()`: monthly VAT receipts by component (payments, repayments,
  import VAT, home VAT) from April 1973.
* Added `get_fuel_duties()`: monthly hydrocarbon oil duty receipts by fuel type
  (petrol, diesel, other) from January 1990.
* Added `get_tobacco_duties()`: monthly tobacco duty receipts by product
  (cigarettes, cigars, hand-rolling, other) from January 1991.
* Added `get_corporation_tax()`: annual Corporation Tax receipts by levy type
  (onshore, offshore, Bank Levy, Bank Surcharge, RPDT, EPL, EGL) from 2019-20.
* Added `get_stamp_duty()`: annual stamp duty receipts by type (SDLT, SDRT,
  stamp duty on documents) from 2003-04.
* Added `get_rd_credits()`: annual R&D tax credit claims and cost by scheme
  (SME R&D Relief and RDEC) from 2000-01.
* Added `get_tax_gap()`: cross-sectional tax gap estimates by tax type,
  taxpayer group, and behaviour component for the most recent year.
* Updated DESCRIPTION to reflect full package scope.
* Updated vignette to cover all functions.

# hmrc 0.1.0

* Initial release.
* `get_tax_receipts()`: monthly cash receipts for 41 tax heads, April 2016
  to present.
* `list_tax_heads()`: catalogue of available tax head identifiers.
* `get_property_transactions()`: monthly residential and non-residential
  property transaction counts by UK nation, April 2005 to present.
* `clear_cache()`: delete locally cached HMRC files.
