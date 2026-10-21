# Compatibility and delivery contract

The compiler targets the documented Power BI file formats available on
20 October 2026. Install a current Power BI Desktop for Windows to open and
finish the generated project. Newer schema releases are reviewed explicitly;
the compiler never downloads an unreviewed schema during a user's build.

## What the files contain

| File or component | Purpose |
| --- | --- |
| `.pbip` | Entry point referring to the report folder. It is not the whole report. |
| `.Report/definition/` | Current enhanced PBIR report, pages, native visual queries, formatting and interactions. |
| `.Report/StaticResources/RegisteredResources/` | Custom JSON theme, with matching report resource registration. |
| `.SemanticModel/definition/` | Default TMDL database/model/table/relationship definitions with embedded import partitions. |
| `.SemanticModel/model.bim` | Explicit TMSL alternative; mutually exclusive with definition/. |
| `.SemanticModel/definition.pbism` | Semantic model format settings. |
| `pbiweave.json` | Build profile, table/page counts and source-file checksums. |
| `FIRST-OPEN.md` and `START-HERE.txt` | Desktop refresh, verification and PBIX-save instructions. |
| `.zip` | Entire portable source project, ready to extract into a directory. |

Every table's source values are encoded in its M expression as UTF-8 JSON,
optionally gzip-compressed and Base64-encoded. There are no external CSV files,
database connections, R scripts or credentials in the generated queries.
Sending the entire folder or ZIP sends the complete data snapshot and report
definition. The receiver still needs Power BI to open and process it.

The compiler does not create Power BI's proprietary VertiPaq cache. Microsoft
states that opening a project without `cache.abf` loads the model definition
without loaded data. Select **Home > Refresh** before assessing the visuals.
Then use **File > Save As > Power BI (.pbix)** to create the single binary file
with imported data. Microsoft documents no supported programmatic PBIP-to-PBIX
conversion. A ZIP renamed to `.pbix` would not satisfy that requirement.

Sources:

- [Power BI projects and conversion FAQ](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview)
- [Semantic model folder and cache behavior](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset)
- [Enhanced report format](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report)
- [Supported model formats and model.bim example](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/semantic-model-definition)

## Version profile

| Component | Version |
| --- | --- |
| PBIP format | 1.0 |
| Report definition.pbir format | 4.0 |
| PBIR definition/version.json | 2.0.0 |
| Report JSON schema | 3.3.0 |
| Page JSON schema | 2.1.0 |
| Visual container JSON schema | 2.13.0 |
| Theme schema | 2.159 |
| Semantic model definition.pbism format | 5.0 |
| Semantic model compatibility level (both formats) | 1702 |

These numbers describe different components and are not interchangeable.
TMDL is the default in 0.3.1; TMSL remains an explicitly supported alternative. The two representations share the same model-definition builder. The package does not require
users to install or license a separate tabular-model compiler.

## Data behavior

- Input data frames and data.tables are copied on insertion. Later source-data
  edits do not mutate an existing report specification.
- Factor labels become text; ordering must be supplied explicitly with
  `sort_by`. Ordered factors do not silently become numeric factor codes.
- R integer values map to Int64. Large Int64 values should be supplied as
  `bit64::integer64` or decimal character strings plus `types`. Numeric values
  exceeding R double's exact-integer range are rejected.
- Double payloads are serialized with 17-digit precision.
- Fixed decimals use at most four decimal places. Extra precision and values
  outside the signed 64-bit scaled range are rejected; rounding is explicit.
- R `Date` becomes a Power BI date annotation over a datetime model column.
- POSIX timestamps are converted to UTC, then stored as timezone-free UTC
  clock values because the model does not retain an R timezone attribute.
- NA and NaN become JSON null/Power BI blank. Empty strings remain empty strings
  in source data. Infinite numeric values are rejected.
- Source values can contain Unicode, quotes and line breaks. Model object names
  may contain Unicode and quotes but not control characters or edge whitespace.
- Power BI text comparisons are case-insensitive and discard trailing ASCII spaces, but preserve leading spaces.
  The compiler checks these common key collisions; locale-specific collation
  equivalences still require engine verification.
- Native table visuals group identical projected rows. Include a row identifier
  if duplicate source records must remain distinguishable.

Source: [Power BI data types](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-data-types).

## Interaction and layout behavior

Native Power BI slicers, chart selections, DAX measures and relationships provide
reactivity. There is no Shiny server or R callback at viewing time. `sync` links
slicers across pages. Report, page and visual include/exclude filters are typed.
Page interaction policies may retain native defaults, use filtering, or disable
cross-visual interactions.

Grid spans, sidebar, focus and exact free positions are compiler features.
Canvas presets include wide, standard, portrait and A4 proportions. They do not
claim automatic mobile reflow; a dedicated Power BI mobile layout is not emitted.

Fifteen high-level visual families use built-in Power BI visuals. Maps, custom
`.pbiviz` packages, bookmarks, drillthrough navigation, conditional formatting,
RLS role management, DirectQuery, Direct Lake and authenticated Service deployment
are outside version 0.3.1. Raw DAX expressions are accepted and remain subject to
the Power BI DAX engine. A page may use multiple measures or a categorical legend
for a bar/line/area chart, but not both simultaneously.

The package creates dashboard-style **reports**. A Power BI Service **dashboard**
of pinned tiles is a different artifact and is not created by this local compiler.

## Validation scope

The package validates declaration semantics before writing. It stages a complete
project beside the destination, checks its structure, then commits it. An invalid
declaration does not overwrite an existing project. `overwrite=TRUE` intentionally
replaces a generated project and any later manual edits inside it; a sibling backup is retained unless keep_backup = FALSE. Close Desktop first.

The developer Python validator uses the vendored Microsoft schemas offline and
checks object/resource references. It does not execute M, evaluate DAX, create a
VertiPaq cache or render pixels. JSON validity and a readable layout specification
are necessary checks, but do not certify final publication quality. Review the
report after Desktop refresh before publishing.

## Performance and portability

The compiler uses data.table snapshots, column-oriented preparation, compressed
inline source data, and native Import-model queries. These avoid an R runtime in
the final report. Compilation temporarily holds multiple representations of the
data; embedded snapshots are most suitable for small to moderately sized reports.
Very large data should usually be aggregated before compilation or moved to a
separately designed service model. Warnings flag large snapshots and crowded pages.

Power BI rendering/refresh performance depends on cardinality, DAX, relationships,
data size and the viewing machine. The package does not promise an unmeasured
dashboard latency. Build-time measurements do not measure Power BI interactivity.

R-side compilation is supported on Windows and Linux. Desktop finishing is on
Windows; a project generated in WSL2 can be copied to a normal Windows folder.
Use short destination paths to stay within Windows path limits. The Power BI
Report Server edition is not the target.

## TMDL and acceptance

The pure-R TMDL writer uses quoted object/property names, separate table files, explicit reference ordering and fenced M/DAX expressions. Text properties with line breaks or expressions with standalone fence delimiters are rejected with a TMSL fallback instruction instead of producing ambiguous TMDL. The shipped lightweight inventory checks do not replace native deserialization.

Use `tools/validate-tmdl.ps1` with an explicitly selected trusted Microsoft TOM assembly to deserialize the generated folder and optionally compare it with the same specification compiled to TMSL. This gate does not process data or render visuals. Follow the Desktop acceptance checklist after it.

[TMDL language and serializer reference](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview).
