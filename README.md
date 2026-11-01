# hmrc

[![CRAN status](https://www.r-pkg.org/badges/version/hmrc)](https://CRAN.R-project.org/package=hmrc) [![CRAN downloads](https://cranlogs.r-pkg.org/badges/hmrc)](https://cran.r-project.org/package=hmrc) [![Total Downloads](https://cranlogs.r-pkg.org/badges/grand-total/hmrc)](https://CRAN.R-project.org/package=hmrc) [![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

An R package for accessing statistical data published by [HM Revenue and Customs](https://www.gov.uk/government/organisations/hm-revenue-customs).

## What is HMRC?

HM Revenue and Customs is the UK government department responsible for collecting taxes, paying certain forms of state support, and enforcing customs rules. It is the single largest gatherer of government revenue: in 2025-26, HMRC collected GBP 938bn in taxes and duties, roughly three-quarters of public sector current receipts.

The distinction between HMRC and the OBR matters for anyone working with UK fiscal data. HM Treasury *sets* fiscal policy: it decides tax rates and spending plans. The OBR *forecasts* fiscal outcomes independently. HMRC *reports* what actually came in, the cash receipts against which those plans and forecasts are measured. If you want to know what the government intended to raise, use the OBR. If you want to know what it actually raised, use HMRC.

HMRC publishes monthly receipts data covering every major tax and duty (Income Tax, VAT, NICs, Corporation Tax, fuel duties, stamp duties, alcohol and tobacco duties, and more) and annual statistics on liabilities, reliefs, and the tax gap. This is some of the most closely watched economic data published by the UK government. It moves markets, informs fiscal policy debates, and is widely cited in journalism, think-tank analysis, and parliamentary briefings.

---

## Why does this package exist?

HMRC's statistical data is freely available at [gov.uk](https://www.gov.uk/government/organisations/hm-revenue-customs/about/statistics). The problem is how it is available.

Almost every file is an ODS spreadsheet. Every file's download URL contains a random media hash that changes with each publication cycle, meaning hardcoded URLs stop working every month. There is no API. Getting the data into R requires knowing the right URL pattern, navigating the GOV.UK publication pages manually, reading an ODS file with non-standard headers, pivoting wide-format sheets into long format, and standardising column names. You do this every month.

This package does all of that automatically. Download URLs are resolved at runtime via the GOV.UK Content API, so data is always current. One function call returns a clean, tidy data frame. Files are cached locally, so a publication is only downloaded once per edition. Every result is returned as an `hmrc_tbl` carrying provenance metadata (source URL, fetch time, vintage, cell methods) for reproducible fiscal research.

```r
library(hmrc)
hmrc_tax_receipts()
```

---

## Installation

```r
install.packages("hmrc")

# Or install the development version from GitHub
# install.packages("devtools")
devtools::install_github("charlescoverdale/hmrc")
```

---

## Functions

### Data fetchers

| Function | Description | Time series |
|---|---|---|
| `hmrc_tax_receipts()` | Monthly cash receipts for 42 series (Income Tax, NICs, VAT, CT, duties, etc.) | Apr 2017 onwards (rolling window) |
| `hmrc_vat()` | Monthly VAT receipts (payments, repayments, import VAT, home VAT) | Apr 1973 onwards |
| `hmrc_fuel_duties()` | Monthly hydrocarbon oil duty receipts (petrol, diesel, other) | Jan 1990 onwards |
| `hmrc_tobacco_duties()` | Monthly tobacco duty receipts (cigarettes, cigars, hand-rolling, other) | Jan 1991 onwards |
| `hmrc_corporation_tax()` | Annual CT receipts by levy (onshore, offshore, Bank Levy, RPDT, EPL, EGL) | 2020-21 onwards (rolling six years) |
| `hmrc_stamp_duty()` | Annual stamp duty receipts (SDLT, SDRT, stamp duty on documents) | 2003-04 onwards |
| `hmrc_rd_credits()` | Annual R&D tax credit claims and cost (SME and RDEC schemes, including ERIS and the merged scheme) | 2016-17 onwards |
| `hmrc_tax_gap()` | Tax gap by tax and taxpayer group, as a per cent of liabilities and GBP bn | 2005-06 onwards |
| `hmrc_income_tax_stats()` | Income Tax liabilities by income range (Table 2.5), outturn and projections | Latest outturn year plus projections |
| `hmrc_property_transactions()` | Monthly residential and non-residential transactions by UK nation | Apr 2005 onwards |
| `hmrc_capital_gains()` | Annual CGT taxpayers, gains, and tax liabilities (Table 1) | 1987-88 onwards |
| `hmrc_inheritance_tax()` | IHT estates, tax due, average tax, and effective rate by net-estate band | Latest year of death |
| `hmrc_patent_box()` | Annual companies electing into the Patent Box and total relief | 2013-14 onwards |
| `hmrc_creative_industries()` | Annual reliefs across eight creative-industries sectors | Sector-dependent |

### Discovery and infrastructure

| Function | Description |
|---|---|
| `hmrc_search()` | Keyword search of the dataset catalogue |
| `hmrc_publications()` | Index of implemented and planned publications |
| `hmrc_list_tax_heads()` | Lookup table of 42 tax-receipts identifiers (no download required) |
| `hmrc_meta()` | Extract provenance metadata from any `hmrc_tbl` result |
| `hmrc_cache_info()` | Inspect locally cached files |
| `hmrc_clear_cache()` | Delete locally cached files |

The pre-0.4.0 `get_*` names continue to work as deprecated aliases; they emit a one-time-per-session warning and will be removed in v0.6.0.

---

## Examples

Outputs below are from a live run on 30 September 2026. Every result also prints a short provenance header, shown once in the first example and omitted after that.

### `hmrc_tax_receipts()`: monthly tax head receipts

```r
library(hmrc)

hmrc_tax_receipts(tax = "vat", start = "2026-04")
#> # HMRC tax receipts and NICs (monthly bulletin)
#> # Source: https://www.gov.uk/government/statistics/hmrc-tax-and-nics-receipts-for-the-uk
#> # Fetched 2026-11-01 08:47:48 UTC | Vintage: latest | Cells: cash | Freq: monthly | 6 rows x 4 cols
#> 
#>        date tax_head     description receipts_gbp_m
#>  2026-04-01      vat Value Added Tax          18310
#>  2026-05-01      vat Value Added Tax          15950
#>  2026-06-01      vat Value Added Tax          10276
#>  2026-07-01      vat Value Added Tax          20233
#>  2026-08-01      vat Value Added Tax          15874
#>  2026-09-01      vat Value Added Tax           9853

# Latest month's receipts, ranked by size
receipts <- hmrc_tax_receipts()
latest   <- receipts[receipts$date == max(receipts$date), c("date", "tax_head", "receipts_gbp_m")]
head(latest[order(-latest$receipts_gbp_m), ], 6)
#> # HMRC tax receipts and NICs (monthly bulletin)
#> # Source: https://www.gov.uk/government/statistics/hmrc-tax-and-nics-receipts-for-the-uk
#> # Fetched 2026-11-01 08:47:48 UTC | Vintage: latest | Cells: cash | Freq: monthly | 6 rows x 3 cols
#> 
#>        date        tax_head receipts_gbp_m
#>  2026-09-01  total_receipts          75778
#>  2026-09-01 total_paid_over          75000
#>  2026-09-01      income_tax          22927
#>  2026-09-01 corporation_tax          17969
#>  2026-09-01      nics_total          16731
#>  2026-09-01   nics_employer          12123
```

---

### `hmrc_meta()`: provenance metadata

Every fetcher returns an `hmrc_tbl` carrying the source URL, the GOV.UK publication time of the edition used, fetch time, cell methods, and frequency:

```r
receipts <- hmrc_tax_receipts(tax = "vat", start = "2024-01")
m <- hmrc_meta(receipts)
m[c("dataset", "source_url", "published_at", "cell_methods", "frequency")]
#> $dataset
#> [1] "tax_receipts_monthly"
#> 
#> $source_url
#> [1] "https://www.gov.uk/government/statistics/hmrc-tax-and-nics-receipts-for-the-uk"
#> 
#> $published_at
#> [1] "2026-10-21 06:00:02 UTC"
#> 
#> $cell_methods
#> [1] "cash"
#> 
#> $frequency
#> [1] "monthly"
```

`as.data.frame()` strips the metadata for downstream tidyverse use; subsetting with `[` preserves it.

---

### `hmrc_search()`: discover datasets

```r
# Anything in the catalogue mentioning capital gains
hmrc_search("capital gains")

# Only annual datasets already implemented
hmrc_search(implemented = TRUE, frequency = "annual")

# Roadmap items not yet exposed by an hmrc_* function
hmrc_search(implemented = FALSE)
```

---

### `hmrc_list_tax_heads()`: available tax head identifiers

```r
head(hmrc_list_tax_heads()[, c("tax_head", "category", "available_from")])
#>             tax_head category available_from
#>       total_receipts    total           2017
#>      total_paid_over    total           2017
#>           income_tax   income           2017
#>    capital_gains_tax   income           2017
#>      inheritance_tax   income           2017
#>  apprenticeship_levy   income           2017
```

---

### `hmrc_vat()`: monthly VAT receipts

```r
# Repayments are recorded as negative receipts
vat <- hmrc_vat(measure = c("total", "repayments"), start = "2025-01")
head(vat[vat$measure == "repayments", c("date", "receipts_gbp_m")], 4)
#> # VAT annual statistics (monthly receipts)
#> # Source: https://www.gov.uk/government/statistics/value-added-tax-vat-annual-statistics
#> # Fetched 2026-11-01 08:47:48 UTC | Vintage: latest | Cells: cash | Freq: monthly | 4 rows x 2 cols
#> 
#>        date receipts_gbp_m
#>  2025-01-01          -9010
#>  2025-02-01         -10200
#>  2025-03-01          -8460
#>  2025-04-01          -9100
```

---

### `hmrc_fuel_duties()`: monthly hydrocarbon oil duty

```r
fuel <- hmrc_fuel_duties(fuel = "total", start = "2019-01", end = "2025-12")
fuel$year <- format(fuel$date, "%Y")
# 2020 is the COVID dip: lockdowns meant far less driving
aggregate(receipts_gbp_m ~ year, data = fuel, FUN = function(x) round(sum(x)))
#>  year receipts_gbp_m
#>  2019          27798
#>  2020          22631
#>  2021          24808
#>  2022          24879
#>  2023          24905
#>  2024          24349
#>  2025          24486
```

---

### `hmrc_tobacco_duties()`: monthly tobacco duty by product

```r
tobacco <- hmrc_tobacco_duties(product = c("cigarettes", "hand_rolling"),
                               start = "2015-01", end = "2025-12")
tobacco$year <- format(tobacco$date, "%Y")
agg <- aggregate(receipts_gbp_m ~ year + product, data = tobacco,
                 FUN = function(x) round(sum(x)))
agg[agg$year %in% c("2015", "2025"), ]   # hand-rolling up, cigarettes down
#>  year      product receipts_gbp_m
#>  2015   cigarettes           8032
#>  2025   cigarettes           5859
#>  2015 hand_rolling           1134
#>  2025 hand_rolling           1759
```

---

### `hmrc_capital_gains()`: annual CGT taxpayers, gains, liabilities

```r
cgt <- hmrc_capital_gains(measure = "tax_total_gbp_m")
tail(cgt[, c("tax_year", "value", "status")], 5)
#> # Capital Gains Tax statistics (Table 1)
#> # Source: https://www.gov.uk/government/statistics/capital-gains-tax-statistics
#> # Fetched 2026-11-01 08:47:50 UTC | Vintage: latest | Cells: liabilities | Freq: annual | 5 rows x 3 cols
#> 
#>  tax_year value      status
#>   2020-21 14561        <NA>
#>   2021-22 17035        <NA>
#>   2022-23 14681 provisional
#>   2023-24 12773 provisional
#>   2024-25 24169 provisional
```

---

### `hmrc_inheritance_tax()`: IHT estates by net-estate band

```r
iht <- hmrc_inheritance_tax()
iht[iht$estate_band == "Total", c("tax_year", "measure", "value")]
#> # Inheritance Tax liabilities statistics (Table 12.1a)
#> # Source: https://www.gov.uk/government/statistics/inheritance-tax-liabilities-statistics
#> # Fetched 2026-11-01 08:47:50 UTC | Vintage: latest | Cells: liabilities | Freq: annual | 5 rows x 3 cols
#> 
#>  tax_year            measure  value
#>   2023-24        avg_tax_gbp 231000
#>   2023-24 effective_rate_pct     13
#>   2023-24   number_not_taxed  38000
#>   2023-24       number_taxed  30400
#>   2023-24      tax_due_gbp_m   7030
```

---

### `hmrc_patent_box()`: Patent Box elections and relief

```r
tail(hmrc_patent_box(), 4)
#> # Patent Box reliefs statistics (Table 1)
#> # Source: https://www.gov.uk/government/statistics/patent-box-reliefs-statistics
#> # Fetched 2026-11-01 08:47:50 UTC | Vintage: latest | Cells: counts/cash | Freq: annual | 4 rows x 4 cols
#> 
#>  tax_year companies relief_gbp_m     status
#>   2021-22      1635         1317       <NA>
#>   2022-23      1645         1428       <NA>
#>   2023-24      1695         1857       <NA>
#>   2024-25      1735         2283 projection
```

---

### `hmrc_creative_industries()`: film, TV, games, theatre, etc.

```r
film <- hmrc_creative_industries(sector = "film")
tail(film[, c("tax_year", "companies", "productions", "relief_gbp_m", "status")], 4)
#> # Creative Industries tax relief statistics (Table 1)
#> # Source: https://www.gov.uk/government/statistics/creative-industries-statistics-september-2026
#> # Fetched 2026-11-01 08:47:51 UTC | Vintage: latest | Cells: accruals | Freq: annual | 4 rows x 5 cols
#> 
#>  tax_year companies productions relief_gbp_m               status
#>   2021-22       725         880          521              Revised
#>   2022-23       810         995          550              Revised
#>   2023-24       815         990          504 Provisional, revised
#>   2024-25       885        1025          702          Provisional
```

From 2023-24 the film, TV, animation and video games figures are HMRC's totals across the legacy tax relief and the expenditure credits that replace it (AVEC, the Independent Film Tax Credit and VGEC).

---

### `hmrc_stamp_duty()`: annual stamp duty receipts

```r
sd <- hmrc_stamp_duty(type = c("sdlt_total", "shares_total", "total"))
# 2020-21 is the SDLT holiday; in 2021-22 it tapers off and transactions boom
sd[sd$tax_year %in% c("2020-21", "2021-22", "2024-25"), c("tax_year", "type", "receipts_gbp_m")]
#> # UK Stamp Tax statistics
#> # Source: https://www.gov.uk/government/statistics/uk-stamp-tax-statistics
#> # Fetched 2026-11-01 08:47:51 UTC | Vintage: latest | Cells: cash | Freq: annual | 9 rows x 3 cols
#> 
#>  tax_year         type receipts_gbp_m
#>   2020-21   sdlt_total           8670
#>   2021-22   sdlt_total          14100
#>   2024-25   sdlt_total          13885
#>   2020-21 shares_total           3675
#>   2021-22 shares_total           4370
#>   2024-25 shares_total           4320
#>   2020-21        total          12345
#>   2021-22        total          18465
#>   2024-25        total          18205
```

---

### `hmrc_corporation_tax()`: annual CT receipts by levy type

```r
ct <- hmrc_corporation_tax()
ct[ct$tax_year == "2024-25", c("type", "receipts_gbp_m")]
#> # Corporation Tax statistics
#> # Source: https://www.gov.uk/government/statistics/corporation-tax-statistics-2026
#> # Fetched 2026-11-01 08:47:51 UTC | Vintage: latest | Cells: cash | Freq: annual | 9 rows x 2 cols
#> 
#>                         type receipts_gbp_m
#>          all_corporate_taxes     96917.4772
#>                    bank_levy      1319.9804
#>               bank_surcharge       973.8726
#>  electricity_generators_levy       748.8566
#>          energy_profits_levy      2857.1898
#>                  offshore_ct      1962.1107
#>                   onshore_ct     88953.0274
#>                         rpdt       102.4398
#>                     total_ct     90915.1381
```

---

### `hmrc_rd_credits()`: R&D tax credit claims and cost

```r
rd <- hmrc_rd_credits(measure = "amount_gbp_m", scheme = c("sme", "rdec"))
# SME rates were cut from April 2023. From 2024-25, RDEC includes the merged
# scheme and SME includes ERIS.
rd[rd$tax_year %in% c("2022-23", "2023-24", "2024-25"), c("tax_year", "scheme", "value", "status")]
#> # R&D Tax Credits Statistics
#> # Source: https://www.gov.uk/government/statistics/corporate-tax-research-and-development-tax-credit
#> # Fetched 2026-11-01 08:47:52 UTC | Vintage: latest | Cells: counts/cash | Freq: annual | 6 rows x 4 cols
#> 
#>  tax_year scheme value                status
#>   2022-23   rdec  3245  Provisional, Revised
#>   2023-24   rdec  4605  Provisional, Revised
#>   2024-25   rdec  5925 Provisional, Uplifted
#>   2022-23    sme  4515  Provisional, Revised
#>   2023-24    sme  3190  Provisional, Revised
#>   2024-25    sme  2275 Provisional, Uplifted
```

Accounting periods from 1 April 2024 fall under the merged scheme and ERIS. HMRC reports the merged scheme within its RDEC total and ERIS within its SME total, so `rdec` and `sme` remain comparable across the change.

---

### `hmrc_tax_gap()`: tax gap estimates

```r
gap <- hmrc_tax_gap(tax = "Total tax gap")
tail(gap[, c("tax_year", "gap_pct", "gap_gbp_bn")], 5)
#> # Measuring Tax Gaps
#> # Source: https://www.gov.uk/government/statistics/measuring-tax-gaps-tables
#> # Fetched 2026-11-01 08:47:52 UTC | Vintage: latest | Cells: estimates | Freq: annual | 5 rows x 3 cols
#> 
#>  tax_year gap_pct gap_gbp_bn
#>   2020-21     5.7       36.9
#>   2021-22     6.0       44.6
#>   2022-23     6.6       55.3
#>   2023-24     6.0       52.8
#>   2024-25     6.4       59.2

hmrc_tax_gap(tax = "VAT", tax_year = "latest")
#> # Measuring Tax Gaps
#> # Source: https://www.gov.uk/government/statistics/measuring-tax-gaps-tables
#> # Fetched 2026-11-01 08:47:52 UTC | Vintage: latest | Cells: estimates | Freq: annual | 1 rows x 6 cols
#> 
#>  tax_year tax      type component gap_pct gap_gbp_bn
#>   2024-25 VAT Total VAT Total VAT     6.6       12.1
```

---

### `hmrc_income_tax_stats()`: Income Tax liabilities by income range

```r
it <- hmrc_income_tax_stats(tax_year = "2023-24")
it[, c("income_range", "taxpayers_thousands", "tax_liability_gbp_m", "average_rate_pct")]
#> # Income Tax liabilities by income range (Table 2.5)
#> # Source: https://www.gov.uk/government/statistics/income-tax-liabilities-by-income-range
#> # Fetched 2026-11-01 08:47:52 UTC | Vintage: latest | Cells: liabilities | Freq: annual | 12 rows x 4 cols
#> 
#>  income_range taxpayers_thousands tax_liability_gbp_m average_rate_pct
#>         12570                2850                 590              1.5
#>         15000                5530                4640              4.8
#>         20000               10200               22700              9.0
#>         30000               10800               51200             12.3
#>         50000                5710               70800             18.9
#>        100000                 878               30600             29.2
#>        150000                 294               17200             34.0
#>        200000                 311               33900             37.9
#>        500000                  54               14700             40.6
#>       1000000                  18                9570             40.3
#>      2000000+                   9               18100             39.3
#>    All Ranges               36700              274000             17.9
```

2023-24 is outturn from the Survey of Personal Incomes; later years in the same table are HMRC projections, marked in the `estimate` column.

---

### `hmrc_property_transactions()`: monthly transaction counts

```r
mpt <- hmrc_property_transactions(type = "residential", nation = "england",
                                  start = "2021-01", end = "2021-12")
mpt[mpt$date %in% as.Date(c("2021-03-01", "2021-06-01", "2021-10-01")),
    c("date", "transactions")]
#> # Monthly UK property transactions
#> # Source: https://www.gov.uk/government/statistics/monthly-property-transactions-completed-in-the-uk-with-value-40000-or-above
#> # Fetched 2026-11-01 08:47:53 UTC | Vintage: latest | Cells: counts | Freq: monthly | 3 rows x 2 cols
#> 
#>        date transactions
#>  2021-03-01       151850
#>  2021-06-01       191300
#>  2021-10-01        67790
```

---

## Caching

All downloads are cached in your user cache directory. Each call makes one small request to the GOV.UK Content API to find the current file, then reuses the cached copy unless HMRC has published a new edition.

```r
# Force a fresh download by setting cache = FALSE
hmrc_tax_receipts(cache = FALSE)

# Inspect the local cache
hmrc_cache_info()

# Remove files older than 30 days
hmrc_clear_cache(max_age_days = 30)

# Remove all cached files
hmrc_clear_cache()
```

---

## How URL resolution works

HMRC data files are hosted on `assets.publishing.service.gov.uk` with a random media hash in the path that changes every publication cycle. This makes hardcoding URLs impossible.

This package queries the [GOV.UK Content API](https://content-api.publishing.service.gov.uk/) at runtime to discover the current download URL for each publication, then caches the file locally. This means:

- Data is always current: the day HMRC publishes a new edition, the next call to a fetcher downloads it.
- No manual maintenance is needed to handle URL rotation.
- A network connection is needed on every call to check for a new edition; the file itself is only downloaded once per edition.
- If HMRC changes a table's layout, the fetcher stops with an error naming the missing column rather than returning misaligned data.

---

## Limitations

- **Provisional figures.** Recent years in the CGT, R&D, Patent Box and Creative Industries series, and recent months in the monthly bulletins, are provisional and are revised in later publications. The `status` and `provisional` columns carry HMRC's labels.
- **Suppressed cells.** HMRC suppresses cells where small sample sizes risk identifying taxpayers (`[c]`) or where the value is structurally absent (`[z]` for IHT estates below the nil-rate band). These return `NA`.
- **Rolling windows.** HMRC's monthly receipts table is a rolling window (currently April 2017 onwards) and the Corporation Tax table covers the latest six years. Older periods drop out when HMRC rolls the window forward.
- **Publication lag.** Inheritance Tax statistics are published about two years after the year of death (latest is 2023-24 deaths, published July 2026). This package returns the latest published year; older years are not exposed.
- **Slug churn.** A handful of HMRC publications change their landing-page slug on each release (e.g. `corporation-tax-statistics-2026`, `creative-industries-statistics-september-2026`). The package sweeps recent candidate slugs; if HMRC moves to a substantially different naming scheme the package will fail loudly until updated.
- **Network on every call.** Fetchers need an internet connection to check the GOV.UK Content API for the current edition, even when the file is already cached.
- **Scope.** This package wraps published HMRC tabular statistics. It does not provide microdata access (the Survey of Personal Incomes public use tape is distributed by the [UK Data Service](https://ukdataservice.ac.uk/)) and does not implement microsimulation (see UKMOD or PolicyEngine UK).

---

## Citation

```r
citation("hmrc")
```

A `CITATION.cff` file is also provided at the repo root for the GitHub citation widget and Zenodo deposits.

---

## Related packages

| Package | Description |
|---|---|
| [`ons`](https://github.com/charlescoverdale/ons) | UK Office for National Statistics data |
| [`obr`](https://github.com/charlescoverdale/obr) | Office for Budget Responsibility fiscal forecasts |
| [`boe`](https://github.com/charlescoverdale/boe) | Bank of England data |
| [`ukhousing`](https://github.com/charlescoverdale/ukhousing) | UK Land Registry, EPC, and planning data |
| [`ato`](https://github.com/charlescoverdale/ato) | Australian Taxation Office data (counterpart) |
| [`inflateR`](https://github.com/charlescoverdale/inflateR) | Inflation adjustment for UK price series |
| [`inflationkit`](https://github.com/charlescoverdale/inflationkit) | Inflation analysis (decomposition, persistence, Phillips curve) |
| [`inequality`](https://github.com/charlescoverdale/inequality) | Inequality and poverty measurement |

---

## Issues

Please report bugs or requests at <https://github.com/charlescoverdale/hmrc/issues>.

---

## Keywords

HMRC, UK tax data, tax revenue, VAT, income tax, corporation tax, capital gains tax, inheritance tax, patent box, creative industries, R&D tax credits, stamp duty, tobacco duty, fuel duty, R package, UK government data, fiscal data
