# hmrc 0.4.0

## New data fetchers (Phase 2 of the v1.0.0 roadmap, partial)

* `hmrc_capital_gains()` — Table 1 of the Capital Gains Tax statistics:
  estimated number of CGT taxpayers, gains, and tax liabilities by year of
  disposal, in tidy long format (`tax_year`, `measure`, `value`). Series
  begins 1987-88; published annually each summer.
* `hmrc_inheritance_tax()` — Table 12.1a of the Inheritance Tax Liabilities
  Statistics: numbers of estates, tax due, average tax, and average
  effective tax rate by net-estate band, for the latest year of death.
  Annual cross-section (~3-year publication lag).
* `hmrc_patent_box()` — Table 1 of the Patent Box reliefs statistics:
  annual companies electing into the regime and total relief claimed.
  Series begins 2013-14; published annually in September.
* `hmrc_creative_industries()` — Table 1 of the Creative Industries
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
