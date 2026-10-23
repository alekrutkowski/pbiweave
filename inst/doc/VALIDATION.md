# pbiweave 0.4.0: validation evidence

Version 0.4.0 adds the European Commission theme and independent heading colors.
The checks below were completed on 23 October 2026. They cover this addition,
its output files, and preservation of the six existing preset defaults.
Historical evidence remains under `validation/`; the previous validation guide
is retained at `validation/legacy-0.3.1/VALIDATION.md` in the source repository.

## Checks completed for 0.4.0

| Check | Result | Repository evidence |
|---|---|---|
| Focused R regression tests | All 6 cases and 103 expectations passed, with no failures, skipped cases or warnings | `validation/ec-theme-R-tests-0.4.0.json` |
| Existing preset defaults | Exact 0.3.1 objects, including field order and Segoe UI defaults, preserved for all six older presets | New theme regression tests |
| Constructor and override behavior | Theme selection through dashboard/example constructors, explicit fonts, color overrides, aliases and legacy heading fallback passed | New theme regression tests |
| Actual compiled formatting | Blue chart, slicer, table, matrix and page headings; independent body text; Arial; backgrounds; palette and resource registration passed in both model formats | New theme regression tests |
| EC example compilation | Two-page sampler compiled as TMDL and TMSL; structural and manifest-hash checks passed | `validation/ec-theme-compilation-0.4.0.json` |
| Generated JSON schemas | Both examples passed; 18 schema-governed JSON files per project, 2 pages and 9 visuals including page headings | `validation/ec-theme-schema-0.4.0.json` |
| Standalone theme | Generated from the runtime constructor/compiler, checked for equivalence in R, and validated against Microsoft's bundled theme schema 2.159 | `validation/ec-theme-0.4.0.json` |
| Python tool tests | 14 tests passed, including schema validation and unchanged historical schema/test provenance | `validation/python-tool-tests.json` |
| Static source and documentation | Export consistency, 32 R source/test/example/tool files, README coverage of all 50 exports, help topics, Python syntax and text hygiene passed | `validation/static-checks-0.4.0.json` |

The R checks used **webR 0.6.0 with R 4.6.0 (2026-04-24)**. The package's R
source functions were loaded and evaluated in WebAssembly. The new test file
ran unchanged. The example script's declaration and compilation expressions
also ran; its initial `library(pbiweave)` was omitted in that source-loading
harness. These are execution results for the focused checks, distinct from
native Windows/Linux installation or `R CMD check`.

The standalone JSON contains palette, text-class, structural, semantic and
hyperlink defaults. Compiled PBIR also contains explicit page and visual
formatting. The regression checks inspect those actual emitted properties, so
the blue title treatment is not dependent only on an imported text class.

Microsoft's schema is preserved unchanged under `inst/schemas/`. The schema
checks also verify project cross-references and the package's generated TMDL
inventory. They do not use Microsoft's native TMDL parser or execute M/DAX.
See the [official theme schema documentation](https://github.com/microsoft/powerbi-desktop-samples/tree/main/Report%20Theme%20JSON%20Schema).

## Platform checks supplied for GitHub

The existing workflow runs the full R package checks on Windows and Ubuntu.
Its generated-project job now compiles the EC sampler in both model formats,
in addition to the 34 existing built-in example projects and the optional
flight tutorials. This release does not claim that those GitHub jobs, native
`R CMD check`, the full R regression suite, Microsoft TOM, or Power BI Desktop
have already run.

Reproduce the package and project gates from a fresh extracted repository:

```sh
R CMD build .
R CMD check --no-manual pbiweave_0.4.0.tar.gz
R CMD INSTALL pbiweave_0.4.0.tar.gz
Rscript tools/run-acceptance.R --flights
python -m pip install 'jsonschema>=4.18,<5'
python tools/validate_project.py build/examples build/tutorials --json
```

Run the smaller theme regression separately after installing the development
dependencies:

```r
testthat::test_local(filter = "theme-european-commission")
```

Regenerate and validate the documentation and standalone theme:

```sh
python tools/make_docs.py
Rscript tools/export-themes.R
python tools/check-static.py --output validation/static-checks-0.4.0.json
python tools/test_static.py
```

The static checker reports only its own scope. Its `R_runtime_executed: false`
flag means that Python command does not execute R; the separate focused R
execution is recorded in the EC evidence files. The source repository ZIP
includes GitHub workflows and development tools. It is not an installable
Windows binary package or a prebuilt PBIX.

## Review in Power BI Desktop

Open a generated `.pbip` and select **Home ➜ Refresh**. Check label fit and
font availability, chart titles and page headings, table readability, slicer
behavior, and chart contrast. Save as `.pbix`, close and reopen it to confirm
that the loaded data and intended formatting are retained.

The EC sampler uses the unchanged, fictional `pbi_demo_data()` fixture. With
filters cleared its revenue is 929,888, cost is 576,336.64 and units are 18,368.
These are fixture expectations, not European Commission statistics or results
of a Desktop rendering test. The supplied presentation's exact colors alone
do not guarantee accessibility in every chart.

For Microsoft's native TMDL gate and the broader platform acceptance steps,
see [CONTRIBUTING.md](CONTRIBUTING.md). For the sources and design decisions,
see [EUROPEAN-COMMISSION-THEME.md](EUROPEAN-COMMISSION-THEME.md).
