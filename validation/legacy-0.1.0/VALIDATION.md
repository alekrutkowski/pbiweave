# Validation record

**Version:** pbiweave 0.1.0  
**Date:** 20 October 2026  
**Executed environment:** R 4.3.3, Ubuntu 24.04, x86-64 Linux

## Completed checks

| Check | Result |
| --- | --- |
| Package build and installation | Passed |
| R CMD check --no-manual --no-vignettes | Status: OK; zero errors, warnings or notes in the final check status |
| Automated R behavior suite | 37 test cases, 190 expectations; zero failures, errors, warnings or skips |
| README example constructors and compilation | All 16 examples passed |
| Generated project JSON/reference checks | All 16 passed |
| Offline Microsoft JSON schema checks | 219 schema-bearing documents passed |
| Total generated JSON documents | 251, including manifests and model.bim files |
| Example pages and visuals | 19 pages, 88 visuals including automatic headings |
| ZIP extraction and reopen-structure test | Passed, with companion folders preserved |
| Repeated build byte comparison | Passed for identical input and destination name |
| Gzip and JSON payload round trips | Passed, including UTF-8, blanks, dates, UTC, double precision and Int64 text |
| Fixed-decimal boundaries and typed filters | Passed |
| Unsafe overwrite and invalid-declaration protection | Passed |

The model.bim files are checked structurally and through model-specific R tests;
they are not claimed to have a public JSON schema in this validator. The 219
schema count includes report themes as well as PBIP/PBIR project definitions.

The R check uses locally installed dependencies. Its dependency lookup emitted
a repository-network message, while the final check status was OK. This is not
a CRAN submission result. The included GitHub workflow is configured for Windows
and Ubuntu; it has not been run on GitHub or on Windows in this delivery.

## Compiler benchmark

A single build used 100,000 rows, five columns, four native user visuals and
one page. Compilation, compression and ZIP creation took **1.829 seconds** in
this environment. The output project occupied **1,077,662 bytes**, and its ZIP
occupied **696,907 bytes**. This is an illustrative local compiler measurement,
not a reproducible hardware benchmark or a Power BI performance result.

Run `tools/benchmark.R` to measure on another machine. It intentionally measures
the R compiler only. Power BI Import refresh, VertiPaq compression, DAX evaluation
and native rendering were not measured.

## Expected showcase totals

After Desktop refresh, with no selections or filters, the synthetic 288-row
showcase data should produce:

| Quantity | Expected value |
| --- | ---: |
| Total revenue | 929,888.00 |
| Total cost | 576,336.64 |
| Gross profit | 353,551.36 |
| Gross margin | 38.0208541244% |
| Units | 18,368 |

The corresponding machine-readable values are in
`inst/examples/expected-totals.json`. Displayed cards round according to their
format strings, so the showcase margin card should display **38.0%**.

## Desktop acceptance remains required

No Windows Power BI Desktop rendering or engine execution was performed for
this delivery. The source project has embedded values but no prebuilt VertiPaq
cache. The current Desktop release must open the PBIP, refresh the model, verify
M/DAX behavior and visual appearance, then save a PBIX.

Consequently, this release is an implemented and automatically tested compiler
with an explicit native acceptance gate. It is not a claim of certified
publication readiness or compatibility with every future Desktop build. See
`CONTRIBUTING.md` for the specific acceptance procedure and
`inst/COMPATIBILITY.md` for the supported feature boundary.

Detailed R-check and schema results are preserved under `validation/` in the
repository source ZIP. They are development records, not runtime dependencies.
