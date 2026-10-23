# Migrating to pbiweave 0.4.0

Version 0.4.0 adds the opt-in `european_commission` theme. Existing presets,
the default `linen` theme, and existing positional arguments retain their
behavior. Use `theme = "european_commission"` in `pbi_dashboard()` or
`pbi_example()` to select it. The new final `title_color` argument of
`pbi_theme()` lets headings differ from body text; older theme objects without
this field continue to use their foreground color for headings.

The Commission preset defaults to Arial only when `font` is omitted. Explicit
font arguments continue to take precedence. See
[the design guide](EUROPEAN-COMMISSION-THEME.md) for the palette, provenance and
examples, and [validation evidence](VALIDATION.md) for the checks performed.

## Historical 0.3.1 consolidation guidance

The following notes document migration from the earlier 0.1.0 and 0.2.0 APIs.
Version numbers in this historical section identify that release.

This consolidation uses the supplied **0.1.0 source as its implementation baseline**, not a reconstruction. It adds the useful 0.2.0 API and documentation, restores the original exports and visual/model safeguards, and keeps the pinned 0.1.0 Microsoft schema profile. See `CONSOLIDATION.md` for the audit-to-code map.

## Keep your accepted project

Install this source package in a separate R library for acceptance testing. Keep accepted `.pbix` files and generate 0.3.1 into a **new directory**. Close Desktop before replacing a project. `overwrite = TRUE` only permits replacement of a pbiweave project and retains the prior directory and requested ZIP in sibling backups by default. This protects files, not an unsaved Desktop editing session.

```r
lib <- file.path(getwd(), "pbiweave-v031-library")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
install.packages("pbiweave_0.3.1.tar.gz", repos = NULL, type = "source", lib = lib)
library(pbiweave, lib.loc = lib)
project <- pbi_example("showcase", theme = "midnight") %>%
  pbi_compile("commercial-dashboard-v031", bundle = TRUE)
pbi_open(project)
# In Desktop: Home -> Refresh, verify, Save As .pbix.
```

Install the runtime dependencies in this or an already visible library first. Start a fresh R session before loading the separate version.

## Model format and first refresh

The public `pbi_compile()` default changes to `model_format = "tmdl"`. Explicit `model_format = "tmsl"` retains `model.bim`. A project contains exactly one model representation. Both serializers consume the same validated intermediate model, column metadata and embedded M payload. Changing format is a new compilation, not an in-place rewrite of arbitrary user-edited TMDL or BIM.

**Home ➜ Refresh remains required on first open in either format.** A source project contains the data snapshot in its expressions, not a processed native cache. `pbi_check()$valid` does not certify loaded data, visual rendering, DAX evaluation, publish permissions or Microsoft TMDL parser acceptance. `data_loaded = NA` and `runtime_checked = FALSE` are intentional.

## Original positional meaning wins

There is no safe way to infer all incompatible positional calls introduced in the reconstructed 0.2.0. Version 0.3.1 preserves the original meaning and accepts newer *named* aliases where unambiguous.

| Function | Canonical 0.3.1 form | Compatibility rule |
|---|---|---|
| `pbi_data()` | `pbi_data(x, name, data, ...)` | Also detects `pbi_data(x, data, name)` by the data-frame/string types. Prefer canonical order in reusable code. |
| `pbi_compile()` | `pbi_compile(x, path, overwrite, bundle, compression, open, ...)` | Name `overwrite`, `bundle` and `model_format`; an old unnamed third argument still means overwrite. |
| `pbi_scatter()` | `pbi_scatter(x, y, size, details, legend, ...)` | Name size/details/series when migrating 0.2.0 declarations. Swapping two string fields cannot be inferred safely. |
| `pbi_sort()` | `pbi_sort(x, field, descending = TRUE)` | Named `direction = "ascending"` / `"descending"` is accepted. Do not supply both. |
| `pbi_check()` | `pbi_check(project, stop_on_error = TRUE, ...)` | Name `verify_hashes` and `check_data`. The original second argument remains stop-on-error. |
| `pbi_relationship()` | `pbi_relationship(x, from, from_column, to, to_column, ...)` | Named `from_table`, `to_table`, `direction` accepted. Original bidirectional flag retained; unmatched defaults to warning. |
| `pbi_filter()` | Reusable constructor **and** piped modifier | Original `pbi_filter(field, values, table, exclude)` works, as do piped dashboard/page/visual filters. Typed blanks (`NA`) work. |

Original `legend`, `aggregate`, `alt`, `single_select`, `descending`, `font_size`, `title_size`, `colors`, `padding`, `header` and `focus_ratio` remain. Named newer aliases such as `series`, `single`, `size` (text), `text_size`, `palette`, and `margin` are accepted with conflict checks. Avoid relying on partial argument matching.

## Defaults restored deliberately

The default table is `"data"`, original bar orientation is vertical, original page interactions are `"default"`, and `pbi_layout("sidebar")` puts the **first visual** in the rail. For the 0.2.0 all-slicer rail use `sidebar_mode = "slicers"`; `pbi_screen()` uses that policy automatically and defaults to disabled cross-visual interactions until you bind them.

`pbi_demo_data()` is the original deterministic 288-row, six-column data.table: date, region, product, units, revenue and cost. It has no pre-existing `profit`, `margin`, `row_id` or `channel` column. Derive them explicitly in R:

```r
sales <- pbi_demo_data() %>%
  pbi_prepare(function(d) d[, `:=`(profit = revenue - cost, row_id = seq_len(.N))])
```

All sixteen original named examples are retained. `pbi_example("shiny")` is the seventeenth. `name =` is a named alias for the example selector.

## Restored helpers and return contracts

`pbi_bundle()`, `pbi_date_table()`, `pbi_filters()`, `pbi_where()` and `pbi_inspect()` are back. `pbi_validate()` again returns the original diagnostic data.table (severity, code, location, message), with `$valid`, `$errors` and `$warnings` convenience accessors. These accessors are not added data-frame columns. Use `stop_on_error = FALSE` to inspect errors without stopping and `strict = TRUE` to make warnings fatal.

Project objects retain `path`, `pbip`, `report`, `model`, `bundle` and `diagnostics`; they add `project_file`, `model_format`, `backup` and `bundle_backup`. Checking, opening and bundling recognize either original `pbiweave.json` or reconstructed `pbiweave-manifest.json`, but reject an ambiguous project with both. Compilation emits `pbiweave.json`.

`pbi_column(type = ...)` now **normalizes the private copied values**, not just the metadata, and revalidates applicable sort/relationship invariants. Perform explicit rounding or substantive transformations in R first. Invalid precision is rejected, not silently rounded.

## Desktop edits and build manifests

File hashes refer to a particular build. Saving in Desktop can legitimately change source files; `verify_hashes = FALSE` is the default. Reformatting or replacing generated source queries can also make the original payload inventory inapplicable. For an intentionally edited project use `pbi_check(project, check_data = FALSE)` and native engine acceptance. `pbi_bundle()` bundles such source projects without recompiling, omitting local cache and localSettings while preserving editorSettings and other versioned content.

The lightweight TMDL inventory reader supports the compiler's generated table-per-file form. It is **not a general TMDL parser** for arbitrary redistributed partial declarations. `tools/validate-tmdl.ps1` invokes Microsoft's TOM parser for that gate. JSON schema validity does not imply valid M, DAX or native semantics.

## Evidence

See `VALIDATION.md` for checks actually performed on this delivery, and separate acceptance commands. Historical 0.1.0 evidence is archived with a legacy label and must not be mistaken for a 0.3.1 pass. No new native Power BI acceptance is claimed.
