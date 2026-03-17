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
