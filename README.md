# hmrc

[![R-CMD-check](https://github.com/charlescoverdale/hmrc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/charlescoverdale/hmrc/actions/workflows/R-CMD-check.yaml) [![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)

An R package for accessing statistical data published by [HM Revenue and Customs](https://www.gov.uk/government/organisations/hm-revenue-customs).

## What is HMRC?

HM Revenue and Customs is the UK government department responsible for collecting taxes, paying certain forms of state support, and enforcing customs rules. It is the single largest gatherer of government revenue: in 2023-24, HMRC collected around £830bn in taxes and duties — roughly 90% of all government receipts.

The distinction between HMRC and the OBR matters for anyone working with UK fiscal data. HM Treasury *sets* fiscal policy: it decides tax rates and spending plans. The OBR *forecasts* fiscal outcomes independently. HMRC *reports* what actually came in — the cash receipts against which those plans and forecasts are measured. If you want to know what the government intended to raise, use the OBR. If you want to know what it actually raised, use HMRC.

HMRC publishes monthly receipts data covering every major tax and duty — Income Tax, VAT, NICs, Corporation Tax, fuel duties, stamp duties, alcohol and tobacco duties, and more. This is some of the most closely watched economic data published by the UK government. It moves markets, informs fiscal policy debates, and is widely cited in journalism, think-tank analysis, and parliamentary briefings.

---

## Why does this package exist?

HMRC's statistical data is freely available at [gov.uk](https://www.gov.uk/government/organisations/hm-revenue-customs/about/statistics). The problem is how it is available.

Every file is an ODS spreadsheet. Every file's download URL contains a random media hash that changes with each publication cycle — meaning hardcoded URLs stop working every month. There is no API. Getting the data into R requires knowing the right URL pattern, navigating the GOV.UK publication pages manually, reading an ODS file with non-standard headers, pivoting wide-format sheets into long format, and standardising column names. You do this every month.

This package does all of that automatically. Download URLs are resolved at runtime via the GOV.UK Content API, so data is always current. One function call returns a clean, tidy data frame. Data is cached locally so subsequent calls are instant.

```r
# Without this package
url  <- # ... navigate gov.uk, find the ODS link with the rotating hash ...
path <- tempfile(fileext = ".ods")
download.file(url, path)
raw  <- readODS::read_ods(path, sheet = "Receipts_Monthly", col_names = FALSE)
hdr  <- as.character(unlist(raw[6, ]))
data <- raw[7:nrow(raw), ]
# ... pivot, parse dates, rename columns, filter ...

# With this package
library(hmrc)
get_tax_receipts()
```

---

## Installation

```r
install.packages("hmrc")
```

Or install the development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("charlescoverdale/hmrc")
```

---

## Functions

| Function | Description | Time series |
|---|---|---|
| `get_tax_receipts()` | Monthly cash receipts for 41 tax heads (Income Tax, NICs, VAT, CT, duties, and more) | Apr 2016 – present |
| `list_tax_heads()` | Catalogue of all tax head identifiers — no download needed | — |
| `get_vat()` | Monthly VAT receipts broken down into payments, repayments, import VAT, and home VAT | Apr 1973 – present |
| `get_fuel_duties()` | Monthly hydrocarbon oil duty receipts by fuel type (petrol, diesel, other) | Jan 1990 – present |
| `get_tobacco_duties()` | Monthly tobacco duty receipts by product (cigarettes, cigars, hand-rolling, other) | Jan 1991 – present |
| `get_corporation_tax()` | Annual Corporation Tax receipts by levy (onshore, offshore, bank levy, RPDT, EGL, EPL) | 2019-20 – present |
| `get_stamp_duty()` | Annual stamp duty receipts by type (SDLT on property, SDRT on shares, stamp duty on documents) | 2003-04 – present |
| `get_rd_credits()` | Annual R&D tax credit claims and cost by scheme (SME R&D Relief and RDEC) | 2000-01 – present |
| `get_tax_gap()` | Cross-sectional tax gap estimates by tax type, taxpayer group, and behaviour component | Most recent year |
| `get_income_tax_stats()` | Annual Income Tax liabilities by income range — taxpayer counts, total income, tax liabilities, and average rates | 2022-23 – present |
| `get_property_transactions()` | Monthly residential and non-residential property transactions by UK nation | Apr 2005 – present |
| `clear_cache()` | Delete locally cached HMRC files | — |

---

## Examples

### `get_tax_receipts()` — monthly tax head receipts

```r
library(hmrc)

# Most recent month's receipts, ranked by size
receipts <- get_tax_receipts()
latest   <- receipts[receipts$date == max(receipts$date), c("tax_head", "receipts_gbp_m")]
latest   <- latest[order(-latest$receipts_gbp_m), ]
head(latest, 6)
#>           tax_head receipts_gbp_m
#>     total_receipts          79432
#>         income_tax          24819
#>         nics_total          14237
#>                vat          13461
#>    corporation_tax           9147
#>         fuel_duty            2094
```

---

### `list_tax_heads()` — available tax head identifiers

```r
# See all 41 series available in get_tax_receipts()
list_tax_heads()
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

### `get_vat()` — monthly VAT receipts

```r
# VAT receipts vs repayments since 2020
vat <- get_vat(measure = c("total", "repayments"), start = "2020-01")

# Monthly net VAT: repayments reduce the total
head(vat[vat$measure == "repayments", c("date", "receipts_gbp_m")], 4)
#>         date receipts_gbp_m
#>   2020-01-01          -9823   # repayments are negative
#>   2020-02-01          -8941
#>   2020-03-01          -9107
#>   2020-04-01          -7234   # ← repayments also fell in lockdown
```

---

### `get_fuel_duties()` — monthly hydrocarbon oil duty

```r
# Total fuel duty since 2010 — a slow structural decline
fuel <- get_fuel_duties(fuel = "total", start = "2010-01")

# Aggregate to annual
fuel$year <- format(fuel$date, "%Y")
annual <- aggregate(receipts_gbp_m ~ year, data = fuel, FUN = sum)
tail(annual, 6)
#>   year receipts_gbp_m
#>   2019          27832
#>   2020          22145   # ← COVID lockdowns, far less driving
#>   2021          24917
#>   2022          24601
#>   2023          23884
#>   2024          23012
```

---

### `get_tobacco_duties()` — monthly tobacco duty by product

```r
# Cigarette vs hand-rolling tobacco duty since 2015
tobacco <- get_tobacco_duties(
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

### `get_stamp_duty()` — annual stamp duty receipts

```r
# All stamp duty types since 2010
sd <- get_stamp_duty()
sd[sd$tax_year %in% c("2019-20", "2020-21", "2021-22", "2022-23", "2023-24") &
   sd$type == "sdlt_total", c("tax_year", "receipts_gbp_m")]
#>   tax_year receipts_gbp_m
#>    2019-20          11689
#>    2020-21           8670   # ← SDLT holiday (less tax paid on property)
#>    2021-22          15312   # ← holiday tapering off, boom in transactions
#>    2022-23          15381
#>    2023-24          11628   # ← higher rates cooling the market
```

---

### `get_corporation_tax()` — annual CT receipts by levy type

```r
# CT receipts breakdown: onshore vs offshore vs surcharges
ct <- get_corporation_tax()
ct[ct$tax_year == "2024-25", c("type", "receipts_gbp_m")]
#>                             type receipts_gbp_m
#>                  all_corporate_taxes         94765
#>                         bank_levy            1520
#>                     bank_surcharge           2891
#>          electricity_generators_levy           340
#>             energy_profits_levy          2645
#>                        offshore_ct           3210
#>                         onshore_ct          81440
#>                             rpdt            415
#>                         total_ct          88095
```

---

### `get_rd_credits()` — R&D tax credit claims and cost

```r
# Cost of R&D tax credits by scheme — SME vs RDEC
rd <- get_rd_credits(measure = "amount_gbp_m")
rd[rd$tax_year %in% c("2019-20", "2020-21", "2021-22", "2022-23", "2023-24"), ]
#>   tax_year scheme description         measure  value
#>    2019-20    sme SME R&D Relief  amount_gbp_m   4385
#>    2020-21    sme SME R&D Relief  amount_gbp_m   4690
#>    2021-22    sme SME R&D Relief  amount_gbp_m   4620
#>    2022-23    sme SME R&D Relief  amount_gbp_m   4440
#>    2023-24    sme SME R&D Relief  amount_gbp_m   3145   # ← reform impact
#>    2019-20   rdec RDEC            amount_gbp_m   2515
#>    ...
```

---

### `get_tax_gap()` — tax gap estimates

```r
# Full tax gap breakdown for the most recent year
gap <- get_tax_gap()

# Largest gaps by absolute value
gap_sorted <- gap[order(-gap$gap_gbp_bn), c("tax", "component", "gap_gbp_bn", "uncertainty")]
head(gap_sorted, 6)
#>                               tax                  component gap_gbp_bn uncertainty
#>                    Corporation Tax            Small businesses       14.7      Medium
#>  Income Tax, NICs, Capital Gains Tax  Business taxpayers (SA)        5.8      Medium
#>                                  VAT                Total VAT        8.9      Medium
#>                    Corporation Tax          Total Corporation Tax   18.6         NA
#>  Income Tax, NICs, Capital Gains Tax    Total Income Tax, NICs...  14.4         NA
#>                       Excise duty           Total excise duty        3.1         NA
```

---

### `get_income_tax_stats()` — Income Tax liabilities by income range

```r
# Who pays Income Tax? Taxpayer counts and liabilities by income band
it <- get_income_tax_stats(tax_year = "2023-24")
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

### `get_property_transactions()` — monthly property transaction counts

```r
# Residential transactions in England: boom and bust around SDLT holiday
sdlt <- get_property_transactions(
  type   = "residential",
  nation = "england",
  start  = "2021-01",
  end    = "2022-06"
)
sdlt[sdlt$date %in% as.Date(c("2021-03-01", "2021-06-01", "2021-10-01")),
     c("date", "transactions")]
#>         date transactions
#>   2021-03-01       147390   # ← rush before first deadline
#>   2021-06-01       192510   # ← rush before extended deadline
#>   2021-10-01        78200   # ← holiday ends, volumes normalise
```

---

### `clear_cache()` — manage local cache

```r
# Remove files older than 30 days
clear_cache(max_age_days = 30)

# Remove everything
clear_cache()
```

---

## Caching

All downloads are cached locally in your user cache directory. Subsequent calls return the cached copy instantly — no network request is made.

```r
# Force a fresh download by setting cache = FALSE
get_tax_receipts(cache = FALSE)

# Remove files older than 30 days
clear_cache(max_age_days = 30)

# Remove all cached files
clear_cache()
```

---

## How URL resolution works

HMRC data files are hosted on `assets.publishing.service.gov.uk` with a random media hash in the path that changes every publication cycle. This makes hardcoding URLs impossible.

This package queries the [GOV.UK Content API](https://content-api.publishing.service.gov.uk/) at runtime to discover the current download URL for each publication, then caches the file locally. This means:

- Data is always current: the day HMRC publishes a new monthly bulletin, `get_tax_receipts()` will download the updated file on the next call
- No manual maintenance is needed to handle URL rotation
- A network connection is required for the first call; subsequent calls use the cache

---

## Related packages

| Package | What it covers |
|---|---|
| [`obr`](https://github.com/charlescoverdale/obr) | OBR fiscal forecasts and the Public Finances Databank — the forecast-side complement to HMRC actuals |
| [`readoecd`](https://github.com/charlescoverdale/readoecd) | OECD economic indicators — useful for placing UK tax receipts in international context |
| [`inflateR`](https://github.com/charlescoverdale/inflateR) | Adjust nominal HMRC receipts figures for inflation to compare across decades |
| [`nomisr`](https://github.com/ropensci/nomisr) | ONS/Nomis labour market data — employment and earnings data that drives PAYE and NICs revenues |
| [`onsr`](https://cran.r-project.org/package=onsr) | ONS economic time series — GDP, CPI, trade, and national accounts data |

---

## Issues

Please report bugs or requests at <https://github.com/charlescoverdale/hmrc/issues>.
