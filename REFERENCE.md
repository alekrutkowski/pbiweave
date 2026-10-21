# pbiweave 0.3.1 function reference

Each of the 49 package functions has an installed help topic with arguments, explanations, return values and an example. `%>%` is reexported from magrittr and has a separate help topic.
**FIRST OPEN: Home ➜ Refresh in Power BI Desktop, inspect, then Save As `.pbix`.**

## `pbi_aggregate()` – Choose the selection-time summary for a column

Builds a column reference with an explicit native aggregation.

```r
pbi_aggregate(column, fun = c("sum", "average", "min", "max", "count", "distinct_count"),
                          table = NULL, label = NULL, format = NULL)
```

No rows are aggregated in R by this helper. It tells Power BI to sum, average, count, find a minimum or maximum, or count distinct values after applying the viewer's filters. count counts nonblank values; it is not a row count when the column has missing values. For record counts, prepare a column of ones in R and sum it. The average of a 0/1 indicator with NA for unknown outcomes is a valid observed-outcome proportion. Do not average preaggregated group means: use sufficient statistics and pbi_ratio().

**Returns:** A pbi_field reference with an explicit aggregation.

```r
d <- pbi_dashboard("Mean transaction", pbi_demo_data()) %>%
  pbi_page("Explore", pbi_bar("region",
    pbi_aggregate("revenue", "average", format = "$#,0.00")))
pbi_validate(d)$valid
```

## `pbi_area()` – Show a filled trend

Creates an area chart with an optional stacked series presentation.

```r
pbi_area(x, y, legend = NULL, table = NULL, title = NULL, alt = NULL,
                     aggregate = "sum", stacked = FALSE, labels = FALSE, tooltip = NULL,
                     id = NULL, series = NULL)
```

Area emphasizes magnitude over time. Stacking is useful for additive parts of a whole, not unrelated percentages. Precompute transformed series in R and retain the grouping columns needed by slicers.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_area("date", "revenue", series = "region", stacked = TRUE, title = "Revenue composition")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_bar()` – Compare categories with a bar or column chart

Plots an aggregated value by category, with optional series, stacking, or percent stacking.

```r
pbi_bar(x, y, legend = NULL, table = NULL, title = NULL, alt = NULL,
                    aggregate = "sum", horizontal = FALSE, stacked = FALSE,
                    percent = FALSE, labels = FALSE, tooltip = NULL,
                     id = NULL, series = NULL)
```

Horizontal bars are useful for long labels. Set horizontal = FALSE for columns. percent selects 100% stacking. A numeric value defaults to a sum; use pbi_aggregate() for an average or pbi_ref() for a measure. A chart selection can filter other visuals when interactions permit it. Original horizontal = FALSE remains the default. legend and series are equivalent named spellings. A categorical legend cannot be combined with multiple numeric value fields. alt supplies the accessible description.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_bar("region", "revenue", series = "product", stacked = TRUE, title = "Revenue mix")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_bind()` – Declare which visual selections affect which outputs

Sets directed Power BI interaction edges between visual IDs on one page.

```r
pbi_bind(x, input, outputs, page = NULL, mode = c("filter", "none", "native"))
```

filter translates to a native DataFilter interaction, none to NoFilter, and native leaves the choice to Power BI. Later bindings replace earlier bindings for the same source/target pair. Sources must support selections; static text, cards, and gauges are not input sources. pbi_text() is not a reactive text output. Bindings do not join tables: the semantic model must have the necessary relationships for a selected dimension to filter a fact visual. This is not bindEvent() and does not execute R code.

**Returns:** The modified pbi_dashboard object.

```r
d <- pbi_example("shiny") %>%
  pbi_bind("region", "trend", mode = "none")
pbi_flow(d, include_disabled = TRUE)
```

## `pbi_bundle()` – Bundle an existing project without recompiling it

Writes a ZIP of the complete project source, including intentional Desktop edits.

```r
pbi_bundle(project, file = NULL, overwrite = FALSE)
```

Unlike pbi_compile(bundle = TRUE), this does not regenerate the model or report. It accepts an existing project object, folder or PBIP entry point, including legacy manifests. Structural checks are retained, but snapshot decoding and build-hash checks are skipped because intentional edits can invalidate the old manifest. cache.abf and localSettings.json are excluded; editor settings and other source files are retained. Destination paths must be outside the source folder. Symlinks escaping the project are rejected. The ZIP is not a PBIX; recipients must extract it and refresh. The original bundle is replaced transactionally when overwrite = TRUE.

**Returns:** Invisibly, the absolute ZIP filename.

```r
p <- pbi_compile(pbi_example("quickstart"), tempfile("bundle-"))
z <- pbi_bundle(p)
stopifnot(file.exists(z))
unlink(c(p$path, z), recursive = TRUE)
```

## `pbi_calendar()` – Build a contiguous calendar in R

Creates a daily calendar table and relates it to a Date column in the fact table.

```r
pbi_calendar(x, column, table = NULL, name = "Calendar", from = NULL, to = NULL)
```

The source column must be a Date, not a timestamp. Bounds default to the nonmissing source range. This adds the same rich calendar as pbi_date_table(), including Date, Year, Quarter, Month, MonthName, YearMonth, Day, Weekday (Monday = 1) and WeekdayName, marks Date as the key and adds a many-to-one relationship. Both displayed month and weekday names have sort-by mappings. Bounds excluding fact dates produce unmatched-key diagnostics. For a standalone calendar or deliberate inactive relationship, use pbi_date_table() and pbi_relationship() separately.

**Returns:** The modified pbi_dashboard object, with a calendar table and relationship.

```r
d <- pbi_dashboard("Calendar", pbi_demo_data(), table = "Sales") %>%
  pbi_calendar("date", table = "Sales") %>%
  pbi_page("Monthly", pbi_slicer("Year", table = "Calendar"),
           pbi_bar(pbi_field("MonthName", "Calendar"), "revenue"))
pbi_validate(d)$valid
```

## `pbi_card()` – Present one or several selection-dependent values

Creates the native modern cardVisual, supporting one or several value fields.

```r
pbi_card(value, table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL)
```

Numeric columns default to sums; explicit aggregate references and measures override that. Pass a list of fields for several cards inside one visual, or create individual pbi_card() visuals for separate layout control. Titles are static; numbers are queried under current filters. Empty or zero-denominator measures can display blank. Cards are not selectable binding sources. alt supplies an accessible description.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
d <- pbi_dashboard("Summary", pbi_demo_data()) %>%
  pbi_page("KPIs", pbi_card(c("revenue", "cost"), title = "Revenue and cost"))
pbi_validate(d)$valid
```

## `pbi_check()` – Inspect a generated project without claiming it is refreshed

Checks generated files, model-format exclusivity, JSON parsing, references, and optionally embedded data or file hashes.

```r
pbi_check(project, stop_on_error = TRUE, verify_hashes = FALSE, check_data = TRUE)
```

This checker understands projects generated by this package and their build manifests. $valid describes structural and payload checks only. $data_loaded is NA because the checker does not inspect a live Power BI engine, and $runtime_checked is FALSE. Merely finding cache.abf is not evidence that refresh succeeded. verify_hashes is useful immediately after compiling; intentional Desktop edits can change hashes, source formatting, or paths. After such edits, disable payload checks or recompile before comparing against the old manifest. TMDL text is not parsed by Microsoft TOM here; use Desktop or the supplied TOM validation script for that acceptance step. Both the 0.1.0 pbiweave.json and 0.2.0 pbiweave-manifest.json are accepted. A conflicting pair is rejected. stop_on_error is the preserved second positional argument; name verify_hashes and check_data. Hashes detect changes, not authenticity: anyone able to edit the manifest can replace them. A modified report can be bundled with pbi_bundle() without decoding its intentionally changed queries.

**Returns:** Invisibly, a list with valid, files, errors, model_format, embedded_tables_checked, hashes_checked, cache_present, data_loaded (NA), and runtime_checked (FALSE).

```r
p <- pbi_compile(pbi_example("quickstart"), tempfile("check-"))
c <- pbi_check(p, verify_hashes = TRUE)
stopifnot(c$valid, is.na(c$data_loaded), !c$runtime_checked)
unlink(p$path, recursive = TRUE)
```

## `pbi_column()` – Describe a column for the semantic model

Sets presentation metadata, semantic types, visibility, and sort-by behavior for an existing column.

```r
pbi_column(x, column, table = NULL, type = NULL, format = NULL,
                       hidden = NULL, description = NULL, sort_by = NULL,
                       summarize = NULL, data_category = NULL)
```

This modifies column metadata and, when type is supplied, converts a private copy of the stored values using the same strict normalizers as pbi_data(). Invalid integers, currency scales and date strings fail before compilation. Existing relationships and sort mappings are revalidated after the change. Prepare more complex transformations with ordinary R or pbi_prepare(). A display value must map to exactly one sort key; circular sort mappings are rejected. NULL leaves an existing setting unchanged; format = "" explicitly clears a display format. Identifiers normally use summarize = "none". Hidden data remain recoverable from the project.

**Returns:** The modified pbi_dashboard object.

```r
d <- pbi_dashboard("Typed model", pbi_demo_data()) %>%
  pbi_column("revenue", type = "decimal", format = "$#,0.00") %>%
  pbi_column("product", summarize = "none")
d$tables$data$columns$revenue$format
```

## `pbi_compile()` – Compile a portable project using TMDL by default

Writes report definitions, embedded data, and a TMDL or legacy TMSL semantic model to a project directory.

```r
pbi_compile(x, path, overwrite = FALSE, bundle = FALSE,
                        compression = TRUE, open = FALSE,
                        model_format = c("tmdl", "tmsl"), keep_backup = TRUE)
```

The default model_format = "tmdl" writes a definition/ folder and never a model.bim file. Explicit "tmsl" writes model.bim instead. Both formats use the same internal model and embedded data source. Compilation stages files before committing them. overwrite = TRUE only replaces a directory bearing a pbiweave manifest and retains the old project in a sibling backup directory. Close Desktop before replacing an open project. A bundle ZIP contains all source definitions, not a processed Power BI cache. On first opening select Home -> Refresh, review the visuals, and use Save As .pbix. There is no supported headless PBIX build step implemented here. The original positional sequence (x, path, overwrite, bundle, compression, open) is unchanged. Name the newer options, especially model_format. keep_backup = TRUE retains prior output; FALSE discards it after a successful commit. Compression uses genuine gzip framing, not R memCompress() zlib framing. Both project and requested ZIP are prepared before old output is moved. Output is still source definitions plus embedded data, not a headlessly generated PBIX.

**Returns:** Invisibly, a pbi_project with original path, pbip, report, model, bundle and diagnostics fields, plus project_file, model_format, backup and bundle_backup.

```r
d <- pbi_example("quickstart")
p <- pbi_compile(d, tempfile("pbiweave-example-"))
p$model_format
pbi_check(p)$valid
# For legacy output, use model_format = "tmsl" in a different directory.
unlink(p$path, recursive = TRUE)
```

## `pbi_dashboard()` – Start a declarative report specification

Creates an in-memory report specification and optionally snapshots a first data frame. Nothing is published and no Power BI process is started.

```r
pbi_dashboard(title, data = NULL, table = "data", theme = "linen", locale = "en-US")
```

Build a report by piping this object through data, measure, and page constructors, then call pbi_compile(). Incoming data.tables are copied, so later by-reference edits to the original do not alter the snapshot. A specification is not a running application. R calculations finish before compilation; native Power BI filtering starts after opening and refreshing the generated project. A single table defaults to the name "data", as in 0.1.0. A named list of data frames creates several independent tables; add relationships explicitly. locale controls model culture, not the typed source-data parsing culture.

**Returns:** A pbi_dashboard object. Most model and page helpers return a modified object of this class.

```r
d <- pbi_dashboard("Revenue", pbi_demo_data(), table = "Sales") %>%
  pbi_page("Overview", pbi_card("revenue"), pbi_bar("region", "cost"))
pbi_validate(d)$valid
```

## `pbi_data()` – Embed another data frame in the model

Adds a copied, typed data snapshot under a unique model-table name.

```r
pbi_data(x, name, data, types = NULL, formats = NULL, hidden = character(),
                     descriptions = NULL, sort_by = NULL, description = NULL, table_hidden = FALSE)
```

Use one table for observation-level data and additional tables for dimensions. Adding tables does not join or relate them. Define a many-to-one relationship explicitly with pbi_relationship(). Data are embedded in the generated source; hidden tables are not a security boundary. Factors become text, Dates remain dates, and timestamps are serialized in UTC. Lists, complex vectors, and raw columns must be converted in R first. The canonical positional order is (x, name, data). The reversed 0.2.0 order (x, data, name) is accepted when argument types make it unambiguous. Prefer named arguments in shared code. types, formats, descriptions and sort_by are named column mappings. hidden is normally a vector of column names; table_hidden hides the table. A scalar logical hidden is also accepted as a table-hidden alias. Exact int64 and fixed-decimal strings are normalized before key validation.

**Returns:** The modified pbi_dashboard object.

```r
sales <- pbi_demo_data()
regions <- data.frame(region = unique(sales$region), area = c("A", "B", "C"))
d <- pbi_dashboard("Regions", sales, table = "Sales") %>%
  pbi_data("Regions", regions) %>%
  pbi_relationship("Sales", "region", "Regions", "region")
length(d$tables)
```

## `pbi_date_table()` – Add a standalone, richly described calendar dimension

Creates a contiguous calendar in R from explicit inclusive start and end bounds.

```r
pbi_date_table(x, start, end, name = "Calendar")
```

The table contains Date, Year, Quarter, Month, MonthName, YearMonth, Day, Weekday and WeekdayName. Weekday is Monday = 1. Month and weekday labels have sort-by metadata; Date is the model key and the table is marked as a time dimension. This helper deliberately adds no relationship. Relate the correct fact Date column explicitly, or use pbi_calendar() to infer bounds and add that relationship together. Timestamps should first be converted to Date in R at the desired timezone/grain. Date bounds must be valid and ordered; ranges greater than approximately 1000 years are rejected.

**Returns:** The modified dashboard, with a new embedded calendar table.

```r
d <- pbi_dashboard("Calendar", data.frame(day = as.Date("2025-01-01"), value = 1)) %>%
  pbi_date_table("2025-01-01", "2025-12-31") %>%
  pbi_relationship("data", "day", "Calendar", "Date") %>%
  pbi_page("Months", pbi_bar(pbi_field("MonthName", "Calendar"), "value"))
pbi_validate(d)$valid
```

## `pbi_demo_data()` – Create deterministic demonstration data without changing the RNG

Returns a small synthetic sales data.table used by the examples and help pages.

```r
pbi_demo_data()
```

The original 0.1.0 fixture is intentionally unchanged: 288 synthetic observations cover January 2025 through December 2026, three regions (Central, East, West) and four products (Atlas, Beacon, Cedar, Delta). It contains exactly date, region, product, units, revenue and cost. No random-number generator is used. Compute additional profit, margin or row IDs in R. Unfiltered totals are revenue 929888, cost 576336.64 and units 18368. This is illustrative data, not observed company performance.

**Returns:** A fresh six-column, 288-row data.table.

```r
d <- pbi_demo_data()
head(d)
d[, .(revenue = sum(revenue), profit = sum(revenue - cost), units = sum(units))]
```

## `pbi_donut()` – Show a compact part-to-whole composition

Creates a native donut chart from a category and value.

```r
pbi_donut(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL)
```

As with a pie, use only a few nonnegative additive groups. The hole is a visual style, not another data field or a separate KPI. Put an explicit pbi_card() alongside the chart for a total.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_donut("region", "revenue", title = "Regional composition")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_example()` – Construct one of the teaching report specifications

Builds a complete example specification without writing files or opening Desktop.

```r
pbi_example(id = "showcase", theme = NULL, name = NULL)
```

Names quickstart, typed, themes, grid, sidebar, focus, free, measures, star, time, filters, scatter, tables, gallery, types, showcase, and shiny are supported in that order. A numeric index selects the same sequence. The examples use deterministic fictional data. Select a theme, inspect the specification with pbi_validate(), and choose a new output directory when compiling. The flight tutorials are separate, fully annotated scripts under inst/examples. id is the original argument; name is an alias. The first sixteen declarations and their original six-column fixture are retained, with shiny added seventeenth. No data are downloaded by pbi_example().

**Returns:** A pbi_dashboard object ready for pbi_compile().

```r
d <- pbi_example("showcase", theme = "midnight")
pbi_validate(d)$valid
print(pbi_example(1))
```

## `pbi_field()` – Refer to a model column without writing DAX

Constructs a column reference, optionally qualified by table and given an aggregation, display label, or visual-level format.

```r
pbi_field(name = NULL, table = NULL, aggregate = NULL, label = NULL,
                      format = NULL, column = NULL)
```

A string field name normally resolves in the report's first table. Qualify fields from dimensions, or ambiguous names, with table. Value roles default to sums for numeric columns, while category, slicer, and detail-table roles stay unaggregated. Setting aggregate explicitly overrides that rule. This function does not extract an R vector: it describes a field that Power BI will query later. aggregate = "none" is an explicit unaggregated request for grouping, detail or tooltip roles, not a valid numeric chart-value aggregation. column is an alias for name; use one, not both.

**Returns:** A pbi_field reference consumed by visual constructors.

```r
f <- pbi_field("revenue", table = "Sales", aggregate = "average",
               label = "Mean revenue", format = "$#,0.00")
v <- pbi_bar("region", f, table = "Sales")
print(v)
```

## `pbi_filter()` – Apply a static include or exclude filter at a chosen scope

Constructs a reusable typed filter or attaches that filter to a report, page or visual.

```r
pbi_filter(..., field = NULL, values = NULL, table = NULL,
                       exclude = FALSE, x = NULL, page = NULL)
```

The original constructor remains pbi_filter(field, values, table, exclude). Its result can be reused with pbi_filters(), pbi_where() or pbi_page(filters = list(...)). The added modifier form is dashboard_or_visual %>% pbi_filter(field, values, ...). For a dashboard, page = NULL means report scope; use a page name or index for page scope. Named x is also accepted. NA represents a native blank, and values are normalized against the model type before compilation. Invalid numeric, integer, date, timestamp and currency values are rejected. These are static query constraints, not row-level security and not R callbacks. Slicers combine with these constraints, so excluded source rows cannot be made available by a slicer. This API implements inclusion/exclusion, not arbitrary DAX, Top N or range expressions.

**Returns:** With no dashboard/visual supplied, a reusable pbi_filter object. Otherwise, the modified pbi_dashboard or pbi_visual.

```r
keep_east <- pbi_filter("region", "East")
d <- pbi_dashboard("Scoped filters", pbi_demo_data()) %>%
  pbi_filters(keep_east) %>%
  pbi_page("Overview", pbi_bar("product", "revenue"),
           pbi_card("cost") %>% pbi_filter("product", "Atlas"))
pbi_validate(d)$valid
```

## `pbi_filters()` – Attach reusable filters to the entire report

Adds one or more pbi_filter() specifications to report-level filter context.

```r
pbi_filters(x, ...)
```

Each argument can be a filter or a list of filters. Added constraints combine with existing report, page, visual and slicer filters. A filter is validated against the referenced column type, including blank handling. Qualify dimension columns with table. Report-level constraints are not row-level security: all embedded source values remain accessible to a recipient. Use pbi_page(filters = ...) for page scope and pbi_where() for a visual.

**Returns:** The modified pbi_dashboard specification.

```r
regions <- pbi_filter("region", c("East", "West"))
d <- pbi_dashboard("Subset", pbi_demo_data()) %>%
  pbi_filters(regions) %>%
  pbi_page("Comparison", pbi_bar("region", "revenue"))
pbi_validate(d)$valid
```

## `pbi_flow()` – Inspect declared visual-interaction dependencies

Returns a table of potential directed selection flows in a report specification.

```r
pbi_flow(x, page = NULL, include_disabled = FALSE)
```

Each row identifies page, source ID, target ID, mode, and whether an explicit binding overrides the page default. Disabled edges are omitted unless requested. This is a static inspection tool, not a live reactlog and not proof that data can propagate through the semantic model. It does not include DAX dependency inference, relationship paths, or cross-page slicer synchronization. Native chart interactions may form cycles; they are not a Shiny reactive dependency DAG.

**Returns:** A data.table with page, source, target, mode, and explicit columns.

```r
d <- pbi_example("shiny")
pbi_flow(d)
pbi_flow(d, page = "Explore", include_disabled = TRUE)
```

## `pbi_funnel()` – Display ordered stages or ranked categories

Creates a native funnel visual from categorical labels and an aggregated value.

```r
pbi_funnel(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL)
```

A funnel does not infer a process or calculate conversion rates. Prepare genuine stage counts and meaningful stage ordering in R; unrelated category counts should not be described as sequential conversion. Use pbi_column(sort_by = ...) or an explicit visual sort when appropriate.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_funnel("region", "units", title = "Units by region (not a conversion funnel)")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_gauge()` – Compare a value with a target and bounded scale

Creates a native gauge with optional target, minimum, and maximum.

```r
pbi_gauge(value, target = NULL, min = NULL, max = NULL,
                      table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL, minimum = NULL, maximum = NULL)
```

Bounds can be numeric constants or model field/measure references. Constants are fixed at compilation; fields are evaluated in the current selection. Use a coherent scale and a clearly documented target. Gauges are not selection sources for pbi_bind().

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_gauge("revenue", target = 900000, minimum = 0, maximum = 1800000, title = "Revenue target")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_input()` – Declare a Shiny-style input ID backed by a native slicer

Creates a native slicer with an explicit ID for subsequent interaction bindings.

```r
pbi_input(id, field, table = NULL, label = NULL,
                      style = c("dropdown", "list", "between"), single = FALSE,
                      sync = NULL, alt = NULL)
```

This is a convenience wrapper around pbi_slicer(), not a Shiny input object. The ID is a compile-time visual identifier; there is no input$id value available to R while the exported report runs. Fields must be model columns. With pbi_screen()'s default disabled interactions, use pbi_bind() to name the outputs affected by this input. single controls selection behavior but does not supply an initial selected value.

**Returns:** A pbi_visual object representing a slicer.

```r
d <- pbi_dashboard("Input example", pbi_demo_data()) %>%
  pbi_screen("Explore", pbi_input("region", "region", label = "Region"),
             pbi_output("sales", pbi_card("revenue"))) %>%
  pbi_bind("region", "sales")
pbi_flow(d)
```

## `pbi_inspect()` – Inspect snapshot sizes and report complexity

Summarizes data sizes, page geometry, model complexity and preflight diagnostics.

```r
pbi_inspect(x)
```

Use this before choosing a data grain or compiling a larger report. tables contains rows, columns and approximate in-memory bytes for each copied data.table; it is not a forecast of VertiPaq or encoded JSON size. pages contains visual counts, layout and page dimensions. Measures and relationships are counts, and diagnostics is the structured pbi_validate() result. Large snapshots and pages with many visuals can produce actionable warnings without invalidating the specification. This does not measure native refresh or interaction latency.

**Returns:** A named list: tables, pages, measures, relationships and diagnostics.

```r
report <- pbi_example("showcase")
info <- pbi_inspect(report)
info$tables
info$pages
info$diagnostics
```

## `pbi_layout()` – Declare how visuals occupy a fixed report canvas

Constructs a grid, sidebar, focus, or free-position layout.

```r
pbi_layout(type = c("grid", "sidebar", "focus", "free"), columns = 2L,
                       gap = 20, padding = 24, header = 56,
                       sidebar_width = 0.23, focus_ratio = 0.6, margin = NULL, sidebar_mode = c("first", "slicers"))
```

grid places visuals in declaration order and honors pbi_span(). sidebar preserves the original first-visual-on-the-left behavior by default; sidebar_mode = "slicers" instead places every slicer in the left rail. pbi_screen() uses that second mode. sidebar_width is a fraction from 0.1 to 0.8, or at least 100 canvas pixels. focus enlarges the first visual above the rest, using focus_ratio. free uses pbi_place() coordinates. padding is the page margin; margin is a named alias. header reserves heading space, and header = 0 removes that generated heading. These are fixed canvas layouts, not CSS breakpoints.

**Returns:** A pbi_layout object accepted by pbi_page() or pbi_screen().

```r
d <- pbi_dashboard("Grid", pbi_demo_data()) %>%
  pbi_page("Overview", pbi_card("revenue"), pbi_card("cost"),
           pbi_span(pbi_line("date", "revenue"), columns = 2),
           layout = pbi_layout("grid", columns = 2, gap = 20))
pbi_validate(d)$valid
```

## `pbi_line()` – Show a trend or ordered comparison

Plots one or more value series against an ordered category, commonly a date.

```r
pbi_line(x, y, legend = NULL, table = NULL, title = NULL, alt = NULL,
                     aggregate = "sum", labels = FALSE, tooltip = NULL,
                     id = NULL, series = NULL)
```

Prepare dates and any rolling averages in R. A date column is a real Date value, not a formatted string. Precomputed rolling averages do not recalculate when a viewer filters the report. A basic sum or mean still aggregates within the selected native filter context. Multiple values can be supplied as a list of field references.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_line("date", "revenue", series = "region", title = "Monthly revenue")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_matrix()` – Cross-tabulate values by row and column groups

Creates a native matrix with row groups, optional column groups, and one or more values.

```r
pbi_matrix(rows, values, columns = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL)
```

The matrix evaluates values under each row/column filter context. A ratio-of-sums measure correctly recomputes totals; a precomputed percentage averaged across unequal groups does not. Supply several fields as a list to combine measures and columns. Prepare bespoke statistics in R at a grain that preserves the intended filters.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_matrix("region", "revenue", columns = "product", title = "Revenue cross-tabulation")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_measure()` – Define an optional DAX measure

Adds either a simple aggregation measure or an explicit DAX expression.

```r
pbi_measure(x, name, expression = NULL, table = NULL, column = NULL,
                        aggregate = "sum", format = NULL, description = NULL)
```

Supply exactly one of column and expression. Prefer R for transformations and model-fitting; use a measure only when a value genuinely depends on a viewer's current selection. Free-form DAX is passed through, not evaluated or parsed by R. Its validity must be checked in Power BI. A sum measure is a convenient reusable label, not a requirement for using a numeric column in a visual.

**Returns:** The modified pbi_dashboard object.

```r
d <- pbi_dashboard("Profit", pbi_demo_data(), table = "Sales") %>%
  pbi_measure("Revenue total", column = "revenue", format = "$#,0") %>%
  pbi_measure("Cost total", column = "cost", format = "$#,0") %>%
  pbi_measure("Profit total", "[Revenue total] - [Cost total]", format = "$#,0") %>%
  pbi_page("Summary", pbi_card(pbi_ref("Profit total")))
pbi_validate(d)$valid
```

## `pbi_open()` – Open the project and print the mandatory first-refresh instructions

Opens the generated .pbip entry point using the Windows file association, or returns its path on other systems.

```r
pbi_open(project)
```

Home -> Refresh is required on the first Desktop opening because the generated project contains embedded source data but no processed data cache. pbi_open() never triggers a refresh, presses GUI buttons, or publishes a report. On Linux and WSL, use Power BI Desktop on Windows to open the returned path. After refreshing, compare totals with R, test selections, and save as .pbix to include the loaded cache.

**Returns:** The .pbip filename, invisibly. A clear refresh notice is always printed.

```r
p <- pbi_compile(pbi_example("quickstart"), tempfile("open-"))
if (interactive() && .Platform$OS.type == "windows") {
  pbi_open(p)
} else {
  unlink(p$path, recursive = TRUE)
}
# In Desktop: Home -> Refresh, inspect, then Save As .pbix.
```

## `pbi_output()` – Give a native visual a stable output ID

Assigns an ID to an existing visual specification.

```r
pbi_output(id, visual)
```

The helper provides naming similar to output$plot in Shiny, but it does not register a render function. Pass a completed pbi_bar(), pbi_line(), or other visual, not an R function. IDs are unique per page. A native chart can also be a source of data-point selections, so bindings are not limited to slicer inputs.

**Returns:** The same pbi_visual specification with its ID replaced.

```r
v <- pbi_output("trend", pbi_line("date", "revenue", title = "Revenue trend"))
print(v)
```

## `pbi_page()` – Add a page of native visuals

Adds a named report page containing visual specifications and a layout.

```r
pbi_page(x, name, ..., layout = pbi_layout(), size = "wide", filters = list(),
                     interactions = c("default", "filter", "none"), hidden = FALSE, background = NULL,
                     width = NULL, height = NULL)
```

Supply complete native visuals directly or in a list. Page names and visual IDs must be unique within their respective scopes. Original presets wide, standard, portrait and a4 are supported, as is a numeric width/height size vector. Named width and height override the preset; "custom" uses wide defaults for unspecified dimensions. Filters supplied here are page-scoped pbi_filter() specifications. Hidden pages are presentation metadata, not security. At least one page must be visible. The default interactions = "default" uses native selection rules; "native" is an alias, "filter" forces filtering and "none" disables cross-visual selections. Report/page filters and model relationships are separate from these interaction settings.

**Returns:** The modified pbi_dashboard object.

```r
d <- pbi_dashboard("Sales", pbi_demo_data()) %>%
  pbi_page("Summary", pbi_card("revenue"), pbi_bar("product", "cost")) %>%
  pbi_page("Detail", pbi_table(c("date", "region", "revenue")))
length(d$pages)
```

## `pbi_pie()` – Show a small categorical composition

Creates a native pie chart from a category and value.

```r
pbi_pie(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL)
```

Use a pie only for a small number of nonnegative, additive categories. A sorted bar chart is usually better for precise comparisons or many categories. Precompute Others groups in R when appropriate; grouping should be reproducible and explicitly described.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_pie("region", "revenue", title = "Revenue by region")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_place()` – Place a visual precisely on a free-layout page

Assigns a visual's left/top position and width/height in report-canvas units.

```r
pbi_place(x, left, top, width, height)
```

Coordinates are measured from the top-left of the page. Use layout = pbi_layout("free"). Place data visuals below the reserved heading region; its height depends on the layout padding, header and gap settings. Bounds are checked, while overlaps are reported for review rather than rejected because intentional layering is possible. Geometry is fixed at compilation time.

**Returns:** The modified pbi_visual object.

```r
d <- pbi_dashboard("Custom composition", pbi_demo_data()) %>%
  pbi_page("Overview", pbi_place(pbi_card("revenue"), 24, 90, 280, 160),
           pbi_place(pbi_bar("product", "cost"), 328, 90, 900, 560),
           layout = pbi_layout("free"))
pbi_validate(d)$valid
```

## `pbi_prepare()` – Run a build-time R transformation on a private copy

Calls an ordinary R function once on a copy of a data frame and returns its resulting data.table.

```r
pbi_prepare(data, transform = identity, ...)
```

This is deliberately not a reactive expression or callback registration. The supplied function runs immediately. It may clean values, join data, calculate features, or preaggregate, but must return a data frame. Copying prevents data.table := inside the function from modifying the caller's original object. Changing a slicer in the exported report will never rerun transform.

**Returns:** A copied data.table containing the result.

```r
sales <- pbi_demo_data()
prepared <- pbi_prepare(sales, function(d) {
  d[, profit_per_unit := (revenue - cost) / units]
  d
})
stopifnot(!"profit_per_unit" %in% names(sales))
head(prepared)
```

## `pbi_ratio()` – Combine R-precomputed sufficient statistics correctly

Defines a ratio of two native sums without requiring handwritten DAX.

```r
pbi_ratio(x, name, numerator, denominator, table = NULL,
                      format = "0.0%", description = NULL)
```

The generated measure is DIVIDE(SUM(numerator), SUM(denominator)). Prepare both additive columns in R at the chosen data grain. For a rate, store event counts and eligible counts. For a mean, store a value sum and its nonmissing observation count. This preserves weighted results under arbitrary supported filtering; averaging cell means does not. A zero denominator produces a blank, not an invented zero. A ratio is still evaluated by Power BI at viewing time.

**Returns:** The modified pbi_dashboard object with an additional measure.

```r
cells <- data.frame(group = c("small", "large"),
                    value_sum = c(0, 1000), observed = c(2L, 100L))
d <- pbi_dashboard("Weighted mean", cells) %>%
  pbi_ratio("Mean value", "value_sum", "observed", format = "0.00") %>%
  pbi_page("Summary", pbi_card(pbi_ref("Mean value")))
# The unfiltered result should be 1000 / 102, not mean(c(0, 10)).
pbi_validate(d)$valid
```

## `pbi_ref()` – Refer to an explicitly defined model measure

Creates a measure reference for use in a card, chart, table, or matrix.

```r
pbi_ref(name, table = NULL, label = NULL, format = NULL)
```

Use pbi_ref() rather than a bare name for measures created by pbi_measure() or pbi_ratio(). A measure is evaluated against the current Power BI filter context. The name must exist when the report is validated or compiled. An explicit table can disambiguate a reference, although this implementation requires measure names to be globally unique.

**Returns:** A pbi_field reference with kind = "measure".

```r
d <- pbi_dashboard("Revenue", pbi_demo_data()) %>%
  pbi_measure("Total revenue", column = "revenue") %>%
  pbi_page("Summary", pbi_card(pbi_ref("Total revenue")))
pbi_validate(d)$valid
```

## `pbi_relationship()` – Connect a fact table to a unique dimension key

Creates an active or inactive many-to-one relationship and checks key integrity.

```r
pbi_relationship(x, from = NULL, from_column, to = NULL, to_column,
                             active = TRUE, bidirectional = FALSE,
                             from_table = NULL, to_table = NULL, direction = NULL,
                             unmatched = c("warn", "error", "allow"))
```

from/from_column name the many-side fact key and to/to_column name the one-side dimension key. With single-direction filtering, dimension selections filter fact rows, not the reverse. from_table and to_table are named aliases; direction = "single" or "both" aliases bidirectional. Dimension keys must be unique and nonmissing after typed normalization. Text comparisons fold case and remove trailing ASCII spaces but preserve leading spaces. Other locale-specific equivalences require native review. unmatched defaults to "warn" for original compatibility; choose "error" for strict coverage or "allow" for intentional unknown facts. Active undirected cycles and parallel routes are conservatively rejected by pbi_validate(), even though some more complex native models could resolve them. Make alternative relationships inactive rather than suppressing the diagnostics.

**Returns:** The modified pbi_dashboard object.

```r
sales <- pbi_demo_data()
regions <- data.frame(region = unique(sales$region),
                      manager = c("Alex", "Sam", "Robin"))
d <- pbi_dashboard("Team sales", sales, table = "Sales") %>%
  pbi_data(regions, "Regions") %>%
  pbi_relationship("Sales", "region", "Regions", "region") %>%
  pbi_page("Teams", pbi_bar(pbi_field("manager", "Regions"), "revenue"))
pbi_validate(d)$valid
```

## `pbi_scatter()` – Compare observations or aggregates in two dimensions

Creates a scatter chart, optionally encoding group with color and magnitude with bubble size.

```r
pbi_scatter(x, y, size = NULL, details = NULL, legend = NULL,
                        table = NULL, title = NULL, alt = NULL, aggregate = "sum", tooltip = NULL,
                     id = NULL, series = NULL)
```

Supply details as a unique row identifier to obtain one point per observation. Without details, native aggregations can collapse many rows into one point or one point per series. A hidden identifier is still usable as a details field. For large datasets, prepare a meaningful summary or sample in R and explain the sampling rule. Bubble size must have a meaningful nonnegative magnitude. Preserve the original positional order x, y, size, details, legend. Use named arguments when migrating from 0.2.0, which reordered those meanings.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
sales <- pbi_demo_data() %>% pbi_prepare(function(d) d[, row_id := seq_len(.N)])
d <- pbi_dashboard("Scatter", sales) %>%
  pbi_page("Compare", pbi_scatter("units", "revenue", size = "cost", details = "row_id",
                                 legend = "region", title = "Monthly observations"))
pbi_validate(d)$valid
```

## `pbi_screen()` – Add an explicitly wired, Shiny-style screen

Adds a report page with a sidebar layout and interactions disabled by default.

```r
pbi_screen(x, name, ..., layout = pbi_layout("sidebar", sidebar_mode = "slicers"),
                       size = "wide", width = NULL, height = NULL, interactions = "none")
```

This is a page-construction wrapper. It intentionally uses interactions = "none" so omitted pbi_bind() calls are visible as missing behavior rather than hidden default links. Every input-to-output route must then be declared. Static report/page filters and synchronized slicer state are separate from these links. For a page without slicers choose a grid layout explicitly.

**Returns:** The modified pbi_dashboard object.

```r
d <- pbi_dashboard("Screen", pbi_demo_data()) %>%
  pbi_screen("Explore", pbi_input("product", "product"),
    pbi_output("revenue", pbi_card("revenue")),
    pbi_output("trend", pbi_line("date", "revenue"))) %>%
  pbi_bind("product", c("revenue", "trend"))
pbi_flow(d)
```

## `pbi_slicer()` – Add a viewer-operated filter

Creates a native dropdown, list, or between-range slicer bound to one model column.

```r
pbi_slicer(field, table = NULL, title = NULL, alt = NULL,
                       style = c("dropdown", "list", "between"), single_select = FALSE, sync = NULL,
                     id = NULL, single = NULL)
```

The choices come from the embedded column rather than an R callback. between requires a numeric or date column. single affects selection behavior but does not specify an initial selected value. Giving slicers on multiple pages the same sync name synchronizes their selection state; they must refer to the same column. On explicit pbi_screen() pages use bindings to connect the slicer to outputs.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_slicer("region", title = "Choose regions", style = "list", sync = "region")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_sort()` – Set a visual query's sort order

Requests ascending or descending sorting by a model column or measure.

```r
pbi_sort(x, field, descending = FALSE, direction = NULL, table = NULL)
```

The field should be present in the visual. When a bare column name identifies exactly one projected aggregate, the compiler reuses that aggregation for sorting. Supply an explicit pbi_field(), pbi_aggregate(), or pbi_ref() to avoid ambiguity. Sorting a displayed month-name column is usually better handled by pbi_column(sort_by = "Month") than by alphabetic sorting. The third positional argument remains the logical descending flag. Use direction = "descending" for the newer string spelling; do not pass that string positionally. The selected sorting expression must already appear in the visual with the same aggregation.

**Returns:** The modified pbi_visual object.

```r
v <- pbi_bar("product", "revenue") %>%
  pbi_sort("revenue", descending = TRUE)
d <- pbi_dashboard("Ranked products", pbi_demo_data()) %>%
  pbi_page("Rank", v)
pbi_validate(d)$valid
```

## `pbi_span()` – Give a visual more grid cells

Sets the integer column and row span of a visual in a grid-based layout.

```r
pbi_span(x, columns = 1L, rows = 1L)
```

Spans change geometry, not the data query. A column span cannot exceed the number of grid columns. The layout solver allocates enough rows and shares the available page height between them. Large spans on a crowded page can still produce unreadable visuals; use pbi_validate() warnings and review the rendered page. Use pbi_place() rather than spans for a free layout.

**Returns:** The modified pbi_visual object.

```r
d <- pbi_dashboard("Spans", pbi_demo_data()) %>%
  pbi_page("Overview", pbi_span(pbi_line("date", "revenue"), columns = 2),
           pbi_card("revenue"), pbi_card("cost"),
           layout = pbi_layout(columns = 2))
pbi_validate(d)$valid
```

## `pbi_table()` – Show unaggregated detail fields or explicit summaries

Creates a native table visual from a vector or list of fields.

```r
pbi_table(columns = NULL, table = NULL, title = NULL, alt = NULL,
                     id = NULL)
```

Plain column names are unaggregated in this visual. Explicit pbi_aggregate() and pbi_ref() values remain aggregated. Power BI can group identical combinations of unaggregated displayed fields, so include a unique row ID when every source record must be distinguishable. A visual is not a guaranteed full-data export; native query reduction can limit displayed rows. columns = NULL automatically selects the visible columns of the chosen table. Hidden columns may still be selected explicitly; hiding is not data security.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
d <- pbi_dashboard("Evidence", pbi_demo_data()) %>%
  pbi_page("Details", pbi_table(title = "Visible source columns"))
pbi_validate(d)$valid
```

## `pbi_text()` – Add static explanatory text

Creates a native text box with a fixed string, size, and weight.

```r
pbi_text(text, font_size = 18, color = NULL, title = NULL, alt = NULL,
                     id = NULL, size = NULL, bold = FALSE)
```

Text is evaluated and embedded at build time. It does not become renderText() and cannot be a data-filtered output. Compute explanatory prose in R before compiling or use a numeric card for a selection-dependent value. Newline characters create separate paragraphs.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
d <- pbi_dashboard("Explanation", pbi_demo_data()) %>%
  pbi_page("Notes", pbi_text("Select a region. Data are synthetic.",
                           font_size = 15, bold = TRUE, alt = "Report instructions"))
pbi_validate(d)$valid
```

## `pbi_theme()` – Choose coordinated colors and typography

Constructs a theme specification used by the report and visual containers.

```r
pbi_theme(preset = c("linen", "midnight", "ocean", "forest", "ink", "accessible"),
                      colors = NULL, background = NULL, surface = NULL,
                      foreground = NULL, muted = NULL, accent = NULL,
                      font = "Segoe UI", font_size = 11, title_size = 15, text_size = NULL, palette = NULL)
```

Six coordinated presets are available: linen, midnight, ocean, forest, ink and accessible. The complete original theme controls are preserved, including muted/accent colors and separate base/title text sizes. colors needs at least three #RRGGBB values; all individual colors must be scalar. palette aliases colors and text_size aliases font_size, with conflicts rejected. Font families are references, not embedded font files. Verify font availability, contrast, label fit and alternative text in the intended viewing environment; a palette alone does not certify accessibility.

**Returns:** A pbi_theme object accepted by pbi_dashboard().

```r
theme <- pbi_theme("midnight", text_size = 13)
d <- pbi_dashboard("Dark report", pbi_demo_data(), theme = theme) %>%
  pbi_page("Overview", pbi_bar("region", "revenue"))
pbi_validate(d)$valid
```

## `pbi_treemap()` – Show a hierarchical area composition

Creates rectangles sized by a value, optionally split by a second category.

```r
pbi_treemap(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL, group = NULL)
```

category is the primary Group role and group supplies a more detailed split. Values should be nonnegative and additive. This is a native Power BI treemap, not an R plot embedded as an image.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
v <- pbi_treemap("region", "revenue", group = "product", title = "Regional product mix")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## `pbi_validate()` – Preflight a report specification before writing files

Checks fields, measures, types, filters, layouts, sort metadata, and slicer synchronization.

```r
pbi_validate(x, strict = FALSE, stop_on_error = FALSE)
```

Returns structured diagnostics by default without stopping. Each row has severity, code, location and message. stop_on_error = TRUE raises on errors; strict = TRUE also promotes warnings for that stop decision. Compatibility accessors $valid, $errors and $warnings do not replace the underlying data.table columns. Checks include typed filters, relationship keys and conservative path ambiguity, sort dependencies, grouping/value roles, projected sort expressions, synchronized slicer fields, layout bounds and complexity. DAX grammar, native TMDL deserialization, Power Query execution, Desktop rendering and publication permissions remain native acceptance steps.

**Returns:** A pbi_diagnostics data.table with severity, code, location and message. $valid is TRUE when no error rows exist, independently of warnings.

```r
d <- pbi_example("showcase")
check <- pbi_validate(d)
check
check$valid
pbi_inspect(d)$tables
```

## `pbi_waterfall()` – Explain additive contributions to a total

Creates a native waterfall from categories and signed contributions.

```r
pbi_waterfall(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL, breakdown = NULL)
```

Positive and negative contributions should be calculated in R from the analytical question. Passing already cumulative totals would count them again. breakdown adds a secondary categorical split. Native total/breakdown presentation still needs a Desktop review.

**Returns:** A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.

```r
changes <- data.frame(step = c("Opening", "Growth", "Churn"),
                      amount = c(100, 25, -10), order = 1:3)
d <- pbi_dashboard("Bridge") %>%
  pbi_data("Changes", changes, sort_by = c(step = "order")) %>%
  pbi_page("Bridge", pbi_waterfall("step", "amount") %>% pbi_sort("step"))
pbi_validate(d)$valid
```

## `pbi_where()` – Attach reusable filters to one visual

Adds typed include/exclude filters to a single visual specification.

```r
pbi_where(x, ...)
```

A visual filter is an additional static constraint, not an R subset operation and not a selection input. Other visuals can still use rows excluded from this visual. Several arguments or a list are supported. A reusable filter can be shared between pbi_where(), pbi_filters() and pbi_page(filters = ...). The pipe form visual %>% pbi_filter(field, values) is an additive convenience alias.

**Returns:** The modified pbi_visual specification.

```r
v <- pbi_card("revenue") %>% pbi_where(pbi_filter("region", "West"))
d <- pbi_dashboard("Scoped KPI", pbi_demo_data()) %>%
  pbi_page("Compare", v, pbi_card("revenue", title = "All regions"))
pbi_validate(d)$valid
```

## `%>%` – build-time piping

This is magrittr’s ordinary forward pipe, not an R callback inside Power BI.

```r
pbi_demo_data() %>% pbi_prepare(identity)
```
