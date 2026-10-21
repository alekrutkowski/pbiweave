# Consolidation map: 0.1.0 + 0.2.0 → 0.3.1

The implementation starts from the actual supplied 0.1.0 source. This is not another reconstruction. All original exports remain, and all ten additional 0.2.0 exports are included. The original sixteen example declarations are retained verbatim; source comments/help were revised separately. `validation/provenance.json` records hashes and the API union.

The table records **implemented source changes and regression gates**, not a claim that the R or native gates have run. The shipped `VALIDATION.md` is the evidence boundary.

| Audit item | Consolidated implementation | Relevant files / tests |
|---|---|---|
| F01: incompatible API | Original positional order; restored five exports; conflict-checked named aliases; original defaults | `R/spec.R`, `data.R`, `visuals.R`, `compile.R`, `extensions.R`; `test-consolidated.R` |
| F02: decimal precision | Exact scaled-decimal text bounds; strict four-place syntax; numeric rounding tolerance rejects the tiny-extra-decimal counterexample | `R/data.R::normalize_decimal`; original numeric tests and consolidation boundary tests |
| F03: integer normalization | Canonical signed decimal Int64 text before key/sort validation | `R/data.R::normalize_column`; original and consolidation key tests |
| F04: leading spaces | Compare case-insensitively and remove trailing ASCII spaces only; preserve leading spaces | `R/data.R::model_key`; unmatched-key tests |
| F05: typed filters | Original type normalization including NA, dates, timestamps, decimal and large integers; reusable and piped interfaces | `data.R`, `report.R`, `extensions.R`; filter regression tests |
| F06: queryRef collisions | Stable disambiguation of punctuation-bearing field/table names; explicit collision diagnostics | `R/report.R::field_query_ref`, `R/validate.R`; dotted-field counterexample |
| F07: text tooltips | Text retained as grouping fields; numeric tooltips aggregate unless explicit none | `R/report.R::visual_query`; tooltip projection tests |
| F08: query constraints | Cardinality, aggregation/grouping, multi-value/legend conflict, projected-sort and time order retained | `report.R`, `validate.R`; original visual tests |
| F09: relationship paths | Conservative active undirected-cycle/parallel-path guard restored; key checks re-run after column changes | `validate.R`, `extensions.R`; graph and metadata tests |
| F10: alt descriptions | Per-visual alt and meaningful defaults restored | `visuals.R`, `report.R`; accessible description assertion |
| F11: cards/tables | Original modern multi-value cardVisual and NULL auto-visible table fields | `report.R`, `visuals.R`; original card/table tests |
| F12: themes | Original rich theme controls and explicit native visual/table/matrix/text styling | `spec.R`, `report.R`; inherited theme tests |
| F13: layout/pages | Original sidebar, focus ratio, free placement, headers, hidden pages and page background; opt-in all-slicer sidebar | `layout.R`; sidebar-policy tests |
| F14: calendar | Standalone pbi_date_table, rich ordered calendar fields, original bounds; additive pbi_calendar wrapper | `data.R`, `extensions.R`; calendar tests |
| F15: project interoperability | Both historic manifests; original project fields; standalone bundling; safe destinations; staged overwrite with retained backup | `compile.R`; project/overwrite/symlink/archive tests |
| F16: diagnostics | Original structured diagnostic data.table and strict mode; pbi_inspect and size/complexity warnings; additive convenience accessors | `validate.R`; original and consolidation diagnostic tests |
| F17: schema rollback | Preserve original PBIR report3.3.0, page2.1.0, visualContainer2.13.0, semantic compatibility1702 profile | `report.R`, `model.R`, `inst/COMPATIBILITY.md` |
| F18: offline contracts | Original complete schema registry, theme schema, license and cross-file/resource/field/bounds linter retained; generated-TMDL inventory added | `inst/schemas`, `tools/validate_project.py`, `tools/tmdl_inventory.py` |
| F19: ingestion | Original batch column options, named-list input, locale, typed conversion and unsupported-class checks retained; additive table/column metadata | `spec.R`, `data.R`, `extensions.R`; original ingestion tests |
| F20: lost tests | Original test files retained; one compile assertion explicitly requests TMSL to preserve its original model.bim contract; additional regressions and documentation coverage | `tests/testthat`, `tools/legacy-tests`, `validation/provenance.json` |

## Useful additions retained

TMDL is the default output representation, with explicit TMSL compatibility. `model_definition()` is shared: it builds the typed columns, partitions, annotations, measures and relationships once, and the serializer chooses the representation. TMDL uses proper quoted names and fenced expressions; unsupported multiline property/fence cases fail explicitly instead of guessing. The optional native TOM tool compares equivalent generated definitions after Microsoft deserialization.

The R-first preparation/column/aggregate/ratio/calendar helpers, Shiny-style input/output/screen/binding/flow helpers, explicit unmatched-key policies, sync-field validation, payload/hash checks and backup retention are kept. Tutorials and help were adapted to the original six-column demo rather than silently redefining it.

## Compatibility choices that are intentionally explicit

Some 0.2.0 positional call orders were irreconcilable with 0.1.0, notably scatter string arguments and unnamed compile flags. Version 0.3.1 preserves original positional meaning and documents named migration calls rather than attempting a heuristic. `pbi_data()` can safely recognize both name/data orders by their different types. `pbi_filter()` explicitly supports both the reusable-object and piped-modifier forms.

The original sidebar's first-visual rail is the default. `sidebar_mode = "slicers"` preserves the useful new all-slicer behavior; `pbi_screen()` selects it automatically. The native interaction graph is not a Shiny runtime dependency graph.

## Remaining acceptance gates

Run the R tests, help examples, unchanged original example declarations, all 17 built-ins in both representations and both flight tutorials. Validate the resulting JSON offline, deserialize TMDL with Microsoft TOM, compare the equivalent TMSL definition, and perform native refresh/render/PBIX-save/reopen and publication acceptance. Those gates are provided, not fabricated as completed evidence.
