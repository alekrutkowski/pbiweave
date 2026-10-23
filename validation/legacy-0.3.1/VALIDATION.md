# pbiweave 0.3.1: validation evidence and acceptance boundaries

**This is a source consolidation, not a native-runtime certification.** The implementation is based on the actual supplied 0.1.0 archive, with the useful 0.2.0 features integrated into it. It is not another reconstruction of the original API.

The checks below distinguish what actually ran while preparing this delivery from executable gates supplied for later R and Microsoft-engine acceptance. Historical 0.1.0 check results are kept under `validation/legacy-0.1.0/` for provenance only. They are not results for version 0.3.1.

## 0.3.1 hotfix verification scope

The new `tests/testthat/test-path-guards.R` adds project-file, traversal,
symlink and end-to-end bundle regressions to the 0.3.0 test suite. The static
checks and archive-integrity checks for 0.3.1 are recorded separately. **R
was unavailable in the preparation environment**, so these new R tests and
`R CMD check` have not been executed here; they must pass on Windows before
claiming full platform acceptance. Any historical 0.3.0 validation results in
the consolidation provenance remain historical, not 0.3.1 passes.

## Checks actually executed for this delivery

| Check | Observed result | Evidence |
|---|---|---|
| Public API union | All 40 original exports and all 10 additional exports are present: 50 total, including the re-exported pipe | `validation/provenance.json` |
| Original examples | All 16 original example declarations are preserved verbatim; `shiny` is a seventeenth addition | `validation/provenance.json`, `tools/legacy-examples.R` |
| Original regression source | Seven original R test files retained; six byte-identical, one changed only to request TMSL for its model.bim assertions | `validation/provenance.json`, `tools/legacy-tests/` |
| Original schema files | The original bundled schema registry, theme schema, notices and documentation are retained byte-for-byte | `validation/provenance.json` |
| Static source consistency | Export/definition consistency, lexical string/delimiter checks, valid R escape introducers, Python syntax, documentation counts and text hygiene passed | `validation/static-checks.json` |
| README coverage | Every one of the 50 exports occurs in an R code example; two complete tutorials and 16 numbered recipes are present | `validation/static-checks.json` |
| Installed-help coverage | 50 function help topics, including the pipe, plus a package overview; function topics contain explanations and examples | `validation/static-checks.json` |
| Python development-tool tests | 13 tests executed, no failures or errors | `validation/python-tool-tests.json` |
| Archive integrity | Tar/ZIP readability, required paths, exclusions and contents compared with the release source | Distribution `SHA256SUMS.txt` and `pbiweave-0.3.1-ARCHIVE-VERIFICATION.json` in the delivery |

The Python tests exercise the generated-TMDL inventory reader, quoting and fence handling, relationship endpoint extraction, schema meta-validation, retained schema/test bytes, API union and original-example provenance. They **do not execute an R constructor or compiler**, and the schema meta-validation checks the schemas themselves, not newly R-generated reports.

The lexical R check is not an R parser. The generated-TMDL inventory reader recognizes the package's one-table-per-file subset for cross-file checking. It is not Microsoft's TMDL parser and does not validate all native syntax, TOM metadata, M or DAX.

## Gates provided but not executed for this release

* R installation, R parsing, the 62 `test_that()` cases and 309 expectation call sites, installed help examples, both complete flight tutorials, and `R CMD check`.
* Compilation of all 17 built-in reports to both TMDL and TMSL, followed by schema validation of those 34 generated projects.
* Microsoft TOM deserialization and equivalence checking of corresponding TMDL/TMSL models.
* Power BI Desktop refresh, M and DAX evaluation, visual rendering, interaction/accessibility acceptance, PBIX save/reopen and workspace publication.

The installable `.tar.gz` is a source archive assembled from the package files with `.Rbuildignore` exclusions. It is not presented as the output of a successful `R CMD build` or check. No precompiled PBIX or purportedly engine-accepted report is included in this release.

## Reproduce the executed source/tool checks

Run in the extracted full repository, not the reduced installable tarball:

```sh
python tools/check-static.py --output validation/static-checks.json
python -m pip install 'jsonschema>=4.18,<5'
python tools/test_static.py
```

These commands require no Microsoft account and do not modify any external service. The tools are development dependencies, not runtime dependencies of the R package or the compiled report.

## Run the R acceptance gates

Install Imports and the suggested test/data packages, then run in a fresh full-repository checkout:

```sh
R CMD build .
R CMD check --no-manual pbiweave_0.3.1.tar.gz
R CMD INSTALL pbiweave_0.3.1.tar.gz
Rscript tools/run-acceptance.R --flights
python tools/validate_project.py build/examples build/tutorials --json
```

`tools/run-acceptance.R` uses R itself to parse the source and README blocks, runs the regression suite and installed help examples, compiles every built-in specification in both model formats, and executes both complete flight tutorials when `--flights` is supplied. It refuses existing build/example or build/tutorial outputs to avoid confusing an old result with a new pass. It writes `build/R-acceptance.json` only after the R steps complete. The supplied GitHub Actions configuration runs R package checks on Windows and Ubuntu and provides a separate generated-project schema job; inclusion of that configuration does not claim those jobs have run.

## Run the native model acceptance gate

Use an explicitly selected, trusted Microsoft TOM assembly supporting `TmdlSerializer`, together with PowerShell 7. See [CONTRIBUTING.md](CONTRIBUTING.md) and `tools/validate-tmdl.ps1`. The tool calls Microsoft's `DeserializeDatabaseFromFolder` and can compare the corresponding TMSL definition after native deserialization. It does not refresh, evaluate M/DAX, render or publish.

Microsoft's references: [TMDL language and serialization API](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview) and [semantic-model project files](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset).

## Desktop acceptance checklist

Generate into a new directory and retain accepted older output. Record the exact Windows, Power BI Desktop, R, pbiweave and optional TOM versions.

1. Open the whole generated project and immediately select **Home ➜ Refresh**. Before refresh, empty containers and incomplete-data messages can be expected because the project contains source definitions rather than a processed data cache.
2. Compare totals, then exercise slicers, cross-filtering, synchronization, explicit disabled bindings, multi-table propagation, blank values and date controls. Check both light and dark themes, labels, alternative text and page bounds.
3. For both model formats, test exact Int64 and decimal examples, typed blank filters, names containing apostrophes or dots and the relationship-key edge cases.
4. Save as `.pbix`, close and reopen it independently of the source project, and confirm the saved data are present without a new refresh. Inspect publication in the intended workspace under the actual permissions.

### Original showcase acceptance values

The synthetic 288-row snapshot is unchanged. With all selections and optional filters cleared:

| Quantity | Expected value |
|---|---:|
| Revenue | 929,888.00 |
| Cost | 576,336.64 |
| Gross profit | 353,551.36 |
| Gross margin | 38.0208541244% |
| Units | 18,368 |

These are expected fixture totals, not measurements of a newly executed native report. A one-decimal percentage card should display 38.0% after successful native evaluation.

## What project checks promise

`pbi_validate()` checks an in-memory specification. `pbi_check()` checks the generated structure and recognizable embedded payload, with optional source-file hashes. Neither asserts that Power BI loaded data, accepted TMDL natively, evaluated expressions, rendered correctly or published. `data_loaded = NA` and `runtime_checked = FALSE` make that boundary explicit. Hashes are change detection, not authenticity or access control.

The compiler retains original type/relationship/visual safeguards and stages output before replacement. Default overwrite backups help recovery, but they do not replace user backups or make Desktop-edited projects safe to overwrite blindly. Native locale/collation, permissions, arbitrary DAX and external Desktop edits still require explicit review.
