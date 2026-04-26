# hmrc

[![CRAN status](https://www.r-pkg.org/badges/version/hmrc)](https://CRAN.R-project.org/package=hmrc) [![CRAN downloads](https://cranlogs.r-pkg.org/badges/hmrc)](https://cran.r-project.org/package=hmrc) [![Total Downloads](https://cranlogs.r-pkg.org/badges/grand-total/hmrc)](https://CRAN.R-project.org/package=hmrc) [![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

An R package for accessing statistical data published by [HM Revenue and Customs](https://www.gov.uk/government/organisations/hm-revenue-customs).

## What is HMRC?

HM Revenue and Customs is the UK government department responsible for collecting taxes, paying certain forms of state support, and enforcing customs rules. It is the single largest gatherer of government revenue: in 2023-24, HMRC collected around GBP 830bn in taxes and duties, roughly 90% of all government receipts.

The distinction between HMRC and the OBR matters for anyone working with UK fiscal data. HM Treasury *sets* fiscal policy: it decides tax rates and spending plans. The OBR *forecasts* fiscal outcomes independently. HMRC *reports* what actually came in, the cash receipts against which those plans and forecasts are measured. If you want to know what the government intended to raise, use the OBR. If you want to know what it actually raised, use HMRC.

HMRC publishes monthly receipts data covering every major tax and duty (Income Tax, VAT, NICs, Corporation Tax, fuel duties, stamp duties, alcohol and tobacco duties, and more) and annual statistics on liabilities, reliefs, and the tax gap. This is some of the most closely watched economic data published by the UK government. It moves markets, informs fiscal policy debates, and is widely cited in journalism, think-tank analysis, and parliamentary briefings.

---

## Why does this package exist?

HMRC's statistical data is freely available at [gov.uk](https://www.gov.uk/government/organisations/hm-revenue-customs/about/statistics). The problem is how it is available.

Every file is an ODS spreadsheet. Every file's download URL contains a random media hash that changes with each publication cycle, meaning hardcoded URLs stop working every month. There is no API. Getting the data into R requires knowing the right URL pattern, navigating the GOV.UK publication pages manually, reading an ODS file with non-standard headers, pivoting wide-format sheets into long format, and standardising column names. You do this every month.

This package does all of that automatically. Download URLs are resolved at runtime via the GOV.UK Content API, so data is always current. One function call returns a clean, tidy data frame. Data is cached locally so subsequent calls are instant. Every result is returned as an `hmrc_tbl` carrying provenance metadata (source URL, fetch time, vintage, cell methods) for reproducible fiscal research.

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
| `hmrc_tax_receipts()` | Monthly cash receipts for 41 tax heads (Income Tax, NICs, VAT, CT, duties, etc.) | Apr 2008 onwards |
| `hmrc_vat()` | Monthly VAT receipts (payments, repayments, import VAT, home VAT) | Apr 1973 onwards |
| `hmrc_fuel_duties()` | Monthly hydrocarbon oil duty receipts (petrol, diesel, other) | Jan 1990 onwards |
| `hmrc_tobacco_duties()` | Monthly tobacco duty receipts (cigarettes, cigars, hand-rolling, other) | Jan 1991 onwards |
| `hmrc_corporation_tax()` | Annual CT receipts by levy (onshore, offshore, Bank Levy, RPDT, EPL, EGL) | 2019-20 onwards |
| `hmrc_stamp_duty()` | Annual stamp duty receipts (SDLT, SDRT, stamp duty on documents) | 2003-04 onwards |
| `hmrc_rd_credits()` | Annual R&D tax credit claims and cost (SME and RDEC schemes) | 2000-01 onwards |
| `hmrc_tax_gap()` | Cross-sectional tax gap estimates by tax type, taxpayer group, behaviour | Most recent year |
| `hmrc_income_tax_stats()` | Annual Income Tax liabilities by income range (Table 2.5) | 2022-23 onwards |
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
| `hmrc_list_tax_heads()` | Lookup table of 41 tax-receipts identifiers (no download required) |
| `hmrc_meta()` | Extract provenance metadata from any `hmrc_tbl` result |
| `hmrc_cache_info()` | Inspect locally cached files |
| `hmrc_clear_cache()` | Delete locally cached files |

The pre-0.4.0 `get_*` names continue to work as deprecated aliases; they emit a one-time-per-session warning and will be removed in v0.6.0.

---

## Examples

### `hmrc_tax_receipts()` — monthly tax head receipts

```r
library(hmrc)

# Most recent month's receipts, ranked by size
receipts <- hmrc_tax_receipts()
latest   <- receipts[receipts$date == max(receipts$date), c("tax_head", "receipts_gbp_m")]
latest   <- latest[order(-latest$receipts_gbp_m), ]
head(latest, 6)
#>           tax_head receipts_gbp_m
#>     total_receipts          79432
#>         income_tax          24819
#>         nics_total          14237
#>                vat          13461
#>    corporation_tax           9147
#>          fuel_duty           2094
```

---

### `hmrc_meta()` — provenance metadata

Every fetcher returns an `hmrc_tbl` carrying source URL, fetch time, vintage, cell methods, and frequency:

```r
receipts <- hmrc_tax_receipts(tax = "vat", start = "2024-01")
hmrc_meta(receipts)
#> $dataset
#> [1] "tax_receipts_monthly"
#> $source_url
#> [1] "https://www.gov.uk/government/statistics/hmrc-tax-and-nics-receipts-for-the-uk"
#> $cell_methods
#> [1] "cash"
#> $frequency
#> [1] "monthly"
#> $fetched_at
#> [1] "2026-04-26 09:00:00 UTC"
```

`as.data.frame()` strips the metadata for downstream tidyverse use; subsetting with `[` preserves it.

---

### `hmrc_search()` — discover datasets

```r
# Anything in the catalogue mentioning capital gains
hmrc_search("capital gains")

# Only annual datasets already implemented
hmrc_search(implemented = TRUE, frequency = "annual")

# Roadmap items not yet exposed by an hmrc_* function
hmrc_search(implemented = FALSE)
```

---

### `hmrc_list_tax_heads()` — available tax head identifiers

```r
# See all 41 series available in hmrc_tax_receipts()
hmrc_list_tax_heads()
#>               tax_head                                    description   category available_from
#>         total_receipts                            Total HMRC receipts      total           2016
#>             income_tax         Income Tax (PAYE and Self Assessment)     income           2016
#>      capital_gains_tax                              Capital Gains Tax     income           2016
#>        inheritance_tax                              Inheritance Tax      income           2016
#>     apprenticeship_levy                           Apprenticeship Levy     income           2017
#>             nics_total  National Insurance Contributions (all classes)   nics           2016
#>  ...
```

---

### `hmrc_vat()` — monthly VAT receipts

```r
# VAT receipts vs repayments since 2020
vat <- hmrc_vat(measure = c("total", "repayments"), start = "2020-01")

# Monthly net VAT: repayments reduce the total
head(vat[vat$measure == "repayments", c("date", "receipts_gbp_m")], 4)
#>         date receipts_gbp_m
#>   2020-01-01          -9823   # repayments are negative
#>   2020-02-01          -8941
#>   2020-03-01          -9107
#>   2020-04-01          -7234   # repayments fell during lockdown
```

---

### `hmrc_fuel_duties()` — monthly hydrocarbon oil duty

```r
# Total fuel duty since 2010, a slow structural decline
fuel <- hmrc_fuel_duties(fuel = "total", start = "2010-01")

# Aggregate to annual
fuel$year <- format(fuel$date, "%Y")
annual <- aggregate(receipts_gbp_m ~ year, data = fuel, FUN = sum)
tail(annual, 6)
#>   year receipts_gbp_m
#>   2019          27832
#>   2020          22145   # COVID lockdowns, far less driving
#>   2021          24917
#>   2022          24601
#>   2023          23884
#>   2024          23012
```

---

### `hmrc_tobacco_duties()` — monthly tobacco duty by product

```r
tobacco <- hmrc_tobacco_duties(
  product = c("cigarettes", "hand_rolling"),
  start   = "2015-01"
)

# Annual totals: hand-rolling has grown as cigarettes decline
tobacco$year <- format(tobacco$date, "%Y")
agg <- aggregate(receipts_gbp_m ~ year + product, data = tobacco, FUN = sum)
agg[agg$year == "2024", ]
#>   year      product receipts_gbp_m
#>   2024  cigarettes           6941
#>   2024 hand_rolling          1298
```

---

### `hmrc_capital_gains()` — annual CGT taxpayers, gains, liabilities

```r
# Total CGT receipts in recent years
cgt <- hmrc_capital_gains(measure = "tax_total_gbp_m")
tail(cgt[, c("tax_year", "value")], 5)
#>   tax_year  value
#>    2019-20   9803
#>    2020-21  14282
#>    2021-22  16672
#>    2022-23  14391
#>    2023-24  13316
```

---

### `hmrc_inheritance_tax()` — IHT estates by net-estate band

```r
# Number of taxpaying estates by band, latest year of death
iht <- hmrc_inheritance_tax()
iht[iht$measure == "number_taxed" & iht$estate_band != "Total",
    c("estate_band", "value")]
#>      estate_band value
#>     GBP 0-100k        0
#>   GBP 100k-200k      32
#>   ...
#>      GBP 10m+        42
```

---

### `hmrc_patent_box()` — Patent Box elections and relief

```r
hmrc_patent_box()
#>   tax_year companies relief_gbp_m
#>    2013-14       710          365
#>    2014-15       925          376
#>    ...
#>    2022-23      1735         1469
```

---

### `hmrc_creative_industries()` — film, TV, games, theatre, etc.

```r
# Film tax relief over time
hmrc_creative_industries(sector = "film")

# All eight sectors in the latest year
hmrc_creative_industries(tax_year = "2023-24")
```

---

### `hmrc_stamp_duty()` — annual stamp duty receipts

```r
sd <- hmrc_stamp_duty()
sd[sd$tax_year %in% c("2019-20", "2020-21", "2021-22", "2022-23", "2023-24") &
   sd$type == "sdlt_total", c("tax_year", "receipts_gbp_m")]
#>   tax_year receipts_gbp_m
#>    2019-20          11689
#>    2020-21           8670   # SDLT holiday (less tax paid on property)
#>    2021-22          15312   # holiday tapering off, boom in transactions
#>    2022-23          15381
#>    2023-24          11628   # higher rates cooling the market
```

---

### `hmrc_corporation_tax()` — annual CT receipts by levy type

```r
ct <- hmrc_corporation_tax()
ct[ct$tax_year == "2024-25", c("type", "receipts_gbp_m")]
#>                          type receipts_gbp_m
#>           all_corporate_taxes          94765
#>                     bank_levy           1520
#>                bank_surcharge           2891
#>   electricity_generators_levy            340
#>           energy_profits_levy           2645
#>                   offshore_ct           3210
#>                    onshore_ct          81440
#>                          rpdt            415
#>                      total_ct          88095
```

---

### `hmrc_rd_credits()` — R&D tax credit claims and cost

```r
# Cost of R&D tax credits by scheme: SME vs RDEC
rd <- hmrc_rd_credits(measure = "amount_gbp_m")
rd[rd$tax_year %in% c("2019-20", "2020-21", "2021-22", "2022-23", "2023-24"), ]
#>   tax_year scheme description     measure value
#>    2019-20    sme  SME R&D Relief amount_gbp_m  4385
#>    2020-21    sme  SME R&D Relief amount_gbp_m  4690
#>    2021-22    sme  SME R&D Relief amount_gbp_m  4620
#>    2022-23    sme  SME R&D Relief amount_gbp_m  4440
#>    2023-24    sme  SME R&D Relief amount_gbp_m  3145   # reform impact
```

---

### `hmrc_tax_gap()` — tax gap estimates

```r
gap <- hmrc_tax_gap()

# Largest gaps by absolute value
gap_sorted <- gap[order(-gap$gap_gbp_bn), c("tax", "component", "gap_gbp_bn", "uncertainty")]
head(gap_sorted, 6)
```

---

### `hmrc_income_tax_stats()` — Income Tax liabilities by income range

```r
it <- hmrc_income_tax_stats(tax_year = "2023-24")
it[, c("income_range", "taxpayers_thousands", "tax_liability_gbp_m", "average_rate_pct")]
#>   income_range taxpayers_thousands tax_liability_gbp_m average_rate_pct
#>          12570                2960                 627              1.5
#>          15000                5490                4640              4.9
#>          20000               10200               22500              9.0
#>          30000               10600               50200             12.4
#>          50000                5800               71300             18.7
#>         100000                 922               32000             29.1
#>         150000                 315               18400             34.0
#>         200000                 312               33900             38.0
#>         500000                  54               14700             40.6
#>        1000000                  18                9840             40.7
#>       2000000+                   9               19400             39.6
#>     All Ranges               36600              277000             18.1
```

---

### `hmrc_property_transactions()` — monthly transaction counts

```r
sdlt <- hmrc_property_transactions(
  type   = "residential",
  nation = "england",
  start  = "2021-01",
  end    = "2022-06"
)
sdlt[sdlt$date %in% as.Date(c("2021-03-01", "2021-06-01", "2021-10-01")),
     c("date", "transactions")]
#>         date transactions
#>   2021-03-01       147390   # rush before first SDLT-holiday deadline
#>   2021-06-01       192510   # rush before extended deadline
#>   2021-10-01        78200   # holiday ends, volumes normalise
```

---

## Caching

All downloads are cached locally in your user cache directory. Subsequent calls return the cached copy instantly with no network request.

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

- Data is always current: the day HMRC publishes a new monthly bulletin, the next call to a fetcher will download the updated file.
- No manual maintenance is needed to handle URL rotation.
- A network connection is required for the first call; subsequent calls use the cache.

---

## Limitations

- **Provisional vintages.** The latest one or two tax years in CGT, R&D, and Creative Industries series are flagged provisional by HMRC and are revised in subsequent publications as late returns and claims arrive. The `status` column on Creative Industries carries the HMRC revision label.
- **Suppressed cells.** HMRC suppresses cells where small sample sizes risk identifying taxpayers (`[c]`) or where the value is structurally absent (`[z]` for IHT estates below the nil-rate band). These return `NA`.
- **Publication lag.** Inheritance Tax statistics carry a roughly three-year administrative lag (latest is 2022-23 deaths, published 2025). This package returns the latest published vintage; older years are not exposed.
- **Slug churn.** A handful of HMRC publications change their landing-page slug on each release (e.g. `corporation-tax-statistics-2025`, `creative-industries-statistics-august-2025`). The package sweeps recent candidate slugs; if HMRC moves to a substantially different naming scheme the package will fail loudly until updated.
- **Network at first call.** Fetchers require an internet connection on first call to resolve the GOV.UK Content API and download the file. Subsequent calls in the same session use the cache.
- **Scope.** This package wraps published HMRC tabular statistics. It does not provide microdata access (see the [`taxstats`](https://github.com/HughParsonage/taxstats) package for SPI microdata) and does not implement microsimulation (see the UKMOD framework). There is no equivalent Python package on PyPI as of April 2026.

---

## Citation

```r
citation("hmrc")
```

A `CITATION.cff` file is also provided at the repo root for the GitHub citation widget and Zenodo deposits.

---

## Related packages

This package is part of a suite of R packages for economic, financial, and policy data. They share a consistent interface (named functions, tidy data frames, local caching, provenance metadata) and are designed to work together.

**Data access:**

| Package | Source |
|---|---|
| [`ons`](https://github.com/charlescoverdale/ons) | UK Office for National Statistics |
| [`boe`](https://github.com/charlescoverdale/boe) | Bank of England |
| [`obr`](https://github.com/charlescoverdale/obr) | Office for Budget Responsibility |
| [`ukhousing`](https://github.com/charlescoverdale/ukhousing) | UK Land Registry, EPC, Planning |
| [`fred`](https://github.com/charlescoverdale/fred) | US Federal Reserve (FRED) |
| [`readecb`](https://github.com/charlescoverdale/readecb) | European Central Bank |
| [`readoecd`](https://github.com/charlescoverdale/readoecd) | OECD |
| [`readnoaa`](https://github.com/charlescoverdale/readnoaa) | NOAA Climate Data |
| [`readaec`](https://github.com/charlescoverdale/readaec) | Australian Electoral Commission |
| [`comtrade`](https://github.com/charlescoverdale/comtrade) | UN Comtrade |
| [`carbondata`](https://github.com/charlescoverdale/carbondata) | Carbon markets (EU ETS, UK ETS, voluntary registries) |

**Analytical toolkits:**

| Package | Purpose |
|---|---|
| [`inflateR`](https://github.com/charlescoverdale/inflateR) | Inflation adjustment for price series |
| [`inflationkit`](https://github.com/charlescoverdale/inflationkit) | Inflation analysis (decomposition, persistence, Phillips curve) |
| [`yieldcurves`](https://github.com/charlescoverdale/yieldcurves) | Yield curve fitting (Nelson-Siegel, Svensson) |
| [`debtkit`](https://github.com/charlescoverdale/debtkit) | Debt sustainability analysis |
| [`nowcast`](https://github.com/charlescoverdale/nowcast) | Economic nowcasting |
| [`predictset`](https://github.com/charlescoverdale/predictset) | Conformal prediction |
| [`climatekit`](https://github.com/charlescoverdale/climatekit) | Climate indices |
| [`inequality`](https://github.com/charlescoverdale/inequality) | Inequality and poverty measurement |

---

## Issues

Please report bugs or requests at <https://github.com/charlescoverdale/hmrc/issues>.

---

## Keywords

HMRC, UK tax data, tax revenue, VAT, income tax, corporation tax, capital gains tax, inheritance tax, patent box, creative industries, R&D tax credits, stamp duty, alcohol duty, tobacco duty, fuel duty, R package, UK government data, fiscal data
