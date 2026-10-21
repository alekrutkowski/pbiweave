# pbiweave

**Declarative R specifications for native Power BI reports with embedded data.**

Build coordinated pages, native interactive visuals, typed tables, DAX measures,
relationships, filters, and themes through a small pipe-friendly API. Compile the
specification into a portable Power BI Project (PBIP) containing the complete
report definition and the source data snapshot.

## The output contract

**The R compiler produces a self-contained project, with embedded source data.
Power BI Desktop performs the initial Refresh and the final Save As to PBIX.**
Microsoft documents that PBIP-to-PBIX conversion requires Desktop's File > Save as;
there is no supported programmatic conversion API. A newly generated project has
no VertiPaq data cache until Desktop loads the embedded data.
[PBIP documentation](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview)
[Semantic-model cache behavior](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset)

| Deliverable | Produced by | What it contains |
| --- | --- | --- |
| PBIP project folder | `pbi_compile()` | Native PBIR report, TMSL import model, complete embedded data, theme, and opening instructions |
| Portable ZIP | `pbi_compile(bundle = TRUE)` or `pbi_bundle()` | The project and embedded data together; extract before opening |
| Data-bearing PBIX | Power BI Desktop after Refresh and Save As | Report and loaded import model in one standard Power BI file |
| PBIT | Not emitted by this package | No unsupported template packaging is substituted for PBIX |

Here, “dashboard” is the R specification's name. The native artifact is a
**multipage Power BI report**. A Power BI service dashboard is a separate service
artifact assembled from pinned tiles.
[Reports and dashboards](https://learn.microsoft.com/en-us/power-bi/create-reports/service-dashboards)

**Compatibility baseline: 20 October 2026.** The compiler uses publicly documented
PBIR schemas and enhanced semantic-model metadata, with a pinned schema snapshot
for reproducible builds. PBIR is the current default report format, and current
Power BI Desktop opens PBIP projects directly. This package does not promise
compatibility with unreviewed future Desktop releases.
[Current report format](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report)
[Project documentation](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview)

See [the compatibility record](inst/COMPATIBILITY.md) for exact schema versions
and the distinction between offline validation and Desktop acceptance.

## Install

Install the dependencies from CRAN, then install the supplied source archive:

```r
install.packages(c("data.table", "jsonlite", "base64enc", "magrittr", "digest", "zip"))
install.packages("pbiweave_0.1.0.tar.gz", repos = NULL, type = "source")

library(pbiweave)
library(data.table)
```

The package requires R 4.1 or later. The compiler is platform-independent R code
for Windows and Linux. Power BI Desktop on Windows is needed to load the project,
inspect the native report, and save the final PBIX. On Linux or WSL2, compile and
transfer the complete project or ZIP to Windows.

For development from the unpacked repository:

```sh
R CMD INSTALL pbiweave
```

This is a source distribution, not a claim that the package is already on CRAN
or hosted at a particular GitHub URL.

## A complete first workflow

```r
project <- pbi_example("showcase") %>%
  pbi_compile(file.path(tempdir(), "northstar"), bundle = TRUE)

pbi_check(project)

# On Windows, open the project in the registered Power BI Desktop application:
# pbi_open(project)
```

Use a permanent folder instead of `tempdir()` for work you want to retain. The
default prevents overwriting an existing destination. Rebuild a known generated
project with `overwrite = TRUE` when that is intentional.

In Power BI Desktop:

1. Extract the ZIP, if applicable, and open the generated `.pbip` file.
2. Use a current Power BI Desktop release. Older builds can have different
   project-format settings and support.
3. Select **Home > Refresh**. The data are read from the model's embedded M
   expressions, so no source file, data gateway, credentials, or R installation
   is needed to reconstruct these snapshots.
4. Inspect the pages, filter behavior, formatting, and DAX results.
5. Use **File > Save as > Power BI Desktop file (.pbix)**. Keep the generated
   project as the editable source.
6. Publish the PBIX through the usual Desktop or service workflow if required.

This final Desktop step is essential. JSON schema validation cannot execute the
Power Query or DAX engines or prove that the visual output meets your publication
requirements.
[Opening projects and conversion](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview)

## What the API covers

| Area | Capabilities |
| --- | --- |
| Visuals | Bar/column, clustered and stacked bars, 100% stacked bars, line, area, stacked area, scatter/bubble, pie, donut, treemap, funnel, waterfall, card, gauge, table, matrix, slicer, text |
| Layouts | Grid with row/column spans, a left sidebar, a large focus visual above supporting visuals, exact free positioning |
| Canvas | Wide, standard, portrait, A4 landscape ratio, custom pixel dimensions |
| Themes | Linen, midnight, ocean, forest, ink, accessible; custom palette, colors, fonts, and text sizes |
| Model | Multiple embedded tables, typed columns, hidden fields, descriptions, sort columns, DAX measures, many-to-one relationships, explicit calendar |
| Interactivity | Native slicers and synchronized selections, native visual interactions, include/exclude filters at report/page/visual scope |
| Build | Copied data snapshots, compressed embedded data, stable identifiers, transactional project output, optional ZIP, structural checks |
| Documentation | Sixteen runnable examples, a three-page showcase, package help, offline JSON schema validator |

A native slicer or chart selection changes Power BI's filter context and
recalculates the visuals and DAX measures. Reactivity runs in Power BI. It does
not call back into R. Data are a snapshot taken when `pbi_data()` is called;
rebuild the specification to capture changed R data.

## Sixteen pedagogical examples

All blocks below run after the two `library()` calls above and assign a dashboard
specification to `dashboard`. They use synthetic data from `pbi_demo_data()` or
R's built-in `mtcars` data. The synthetic panel has 288 rows, 24 months, three
regions, and four products; generating it does not change R's random seed.

Compile any block with:

```r
project <- pbi_compile(dashboard, file.path(tempdir(), "my-report"), bundle = TRUE)
```

The exact report specifications are also available as
`pbi_example("example-name")` or `pbi_example(1)` through `pbi_example(16)`.

### 1. Your first reactive report

**Example ID:** `quickstart`

Start with a data frame and four visual declarations. Category fields are left unaggregated; numeric chart values default to sums. A slicer and chart selections use native Power BI interactions after the embedded model is refreshed.

```r
dashboard <- pbi_dashboard("Sales overview", pbi_demo_data(), table = "Sales") %>% pbi_page("Overview", 
    pbi_card("revenue", title = "Sales revenue"), pbi_bar("region", "revenue", horizontal = TRUE, 
        title = "Revenue by region"), pbi_line("date", "revenue", title = "Monthly revenue"), 
    pbi_slicer("product", title = "Choose products"))
```

A plain string resolves against the visual's table, or the first table by default. Supply `table = "AnotherTable"` when necessary.

### 2. Types and publication formats

**Example ID:** `typed`

Dates and logical values are inferred. Declare currency explicitly when you want a fixed-decimal model column, and use DAX format strings for percentages and money. A format string changes presentation without changing the stored value.

```r
visits <- data.table::data.table(day = as.Date("2026-01-01") + 0:3, visitors = c(120L, 
    145L, 132L, 158L), conversion = c(0.12, 0.14, 0.11, 0.16), budget = c("350.2500", "400.5000", 
    "375.0000", "450.7500"), campaign = c(TRUE, TRUE, FALSE, TRUE))
dashboard <- pbi_dashboard("Typed data") %>% pbi_data("Visits", visits, types = c(budget = "decimal"), 
    formats = c(conversion = "0.0%", budget = "$#,0.00"), descriptions = c(conversion = "Completed visits divided by all visits")) %>% 
    pbi_page("Daily activity", pbi_line("day", "visitors", title = "Visitors per day"), 
        pbi_table(c("day", "visitors", "conversion", "budget", "campaign"), title = "Explicit types and formatting"))
```

Fixed-decimal currency has four fractional digits in the Power BI model. Supply exact decimal strings when binary floating-point conversion would be undesirable; choose a numeric double column when your values require a different scale.

### 3. Six coordinated themes

**Example ID:** `themes`

A theme sets the palette, surfaces, typography, and title styling across the report. This example starts with ocean. Theme overrides do not alter the data or chart bindings.

```r
dashboard <- pbi_dashboard("A consistent visual language", pbi_demo_data(), theme = "ocean") %>% pbi_page("Theme sampler", 
    pbi_bar("product", "revenue", title = "Revenue by product", labels = TRUE), pbi_donut("region", 
        "revenue", title = "Regional mix"), pbi_line("date", "revenue", legend = "region", 
        title = "Regional trends"), pbi_card("units", title = "Units sold"))
```

Build the same report in all six presets:

```r
theme_names <- c("linen", "midnight", "ocean", "forest", "ink", "accessible")
theme_reports <- setNames(lapply(theme_names, function(name) {
  pbi_example("themes", theme = name)
}), theme_names)

brand <- pbi_theme("linen",
  colors = c("#125D7A", "#DF8C4D", "#50816F"),
  accent = "#125D7A", font = "Segoe UI", title_size = 16)
custom_report <- pbi_example("themes", theme = brand)
```

The accessible preset uses a color-conscious palette, but a theme alone does not
establish accessibility. Provide meaningful titles and alt text, inspect contrast,
and avoid relying on color alone. Custom fonts must exist on the viewing computer.

### 4. A grid with unequal spans

**Example ID:** `grid`

The first three visuals occupy one row. The line chart then spans two columns and the regional comparison fills the remaining column. Spans belong to the visual, so the same chart can be placed in several compositions.

```r
dashboard <- pbi_dashboard("A structured grid", pbi_demo_data()) %>% pbi_page("Summary", pbi_card("revenue", 
    title = "Revenue"), pbi_card("cost", title = "Cost"), pbi_card("units", title = "Units"), 
    pbi_line("date", "revenue", title = "A chart spanning two columns") %>% pbi_span(columns = 2), 
    pbi_bar("region", "revenue", title = "Regional revenue"), layout = pbi_layout("grid", 
        columns = 3, gap = 18))
```

Use `pbi_span(columns = 2, rows = 2)` when a visual needs both more width and height. Layout validation rejects a column span larger than the grid.

### 5. A persistent filter sidebar

**Example ID:** `sidebar`

The first visual occupies the left sidebar. The remaining visuals are laid out in the right-hand area. Setting interactions to filter asks chart selections to filter other visuals instead of leaving the cross-highlighting choice to each visual.

```r
dashboard <- pbi_dashboard("Explore with a sidebar", pbi_demo_data(), theme = "forest") %>% pbi_page("Explore", 
    pbi_slicer("region", style = "list", title = "Choose a region"), pbi_line("date", "revenue", 
        title = "Revenue over time"), pbi_bar("product", "revenue", title = "Product sales"), 
    pbi_card("units", title = "Units in selection"), layout = pbi_layout("sidebar", sidebar_width = 0.23), 
    interactions = "filter")
```

The sidebar can contain any visual. A list slicer is useful when you want users to see all categories before making a selection.

### 6. Put the main comparison first

**Example ID:** `focus`

The first visual receives the upper focus area; supporting visuals share the space below. Three columns give each supporting visual its own slot. This is useful for a central trend accompanied by a KPI, composition chart, and selector.

```r
dashboard <- pbi_dashboard("One central story", pbi_demo_data(), theme = "ink") %>% pbi_page("Trend in focus", 
    pbi_line("date", "revenue", legend = "region", title = "The main comparison"), pbi_card("revenue", 
        title = "Total revenue"), pbi_donut("product", "revenue", title = "Product contribution"), 
    pbi_slicer("region", title = "Select regions"), layout = pbi_layout("focus", columns = 3, 
        focus_ratio = 0.65))
```

The focus ratio is a proportion of available height, after margins, heading space, and gaps.

### 7. Control an exact page composition

**Example ID:** `free`

Use free layout when a publication calls for specific alignments and proportions. Every visual receives an explicit position in canvas pixels. The default wide canvas is 1280 by 720 pixels.

```r
dashboard <- pbi_dashboard("An exact canvas", pbi_demo_data(), theme = "linen") %>% pbi_page("Designed composition", 
    pbi_text("Select a region to update the summary and trend.", font_size = 16) %>% pbi_place(24, 
        88, 1232, 48), pbi_card("revenue", title = "Revenue") %>% pbi_place(24, 154, 380, 
        136), pbi_card("units", title = "Units") %>% pbi_place(424, 154, 380, 136), pbi_line("date", 
        "revenue", title = "Monthly performance") %>% pbi_place(24, 310, 780, 386), pbi_bar("region", 
        "revenue", horizontal = TRUE, title = "Regional contribution") %>% pbi_place(824, 
        154, 432, 542), layout = pbi_layout("free"), size = "wide", interactions = "filter")
```

The compiler checks canvas bounds. Inspect text wrapping and the rendered chart contents in Desktop before publishing; valid bounds do not guarantee readable labels.

### 8. Use DAX for ratios and financial logic

**Example ID:** `measures`

Define reusable measures once and reference them explicitly with `pbi_ref()`. Gross margin is computed from filtered totals, so slicer selections retain the intended ratio. It is not an average of row-level percentages.

```r
dashboard <- pbi_dashboard("Measures and ratios", pbi_demo_data(), table = "Sales") %>% pbi_measure("Total revenue", 
    column = "revenue", format = "$#,0") %>% pbi_measure("Total cost", column = "cost", 
    format = "$#,0") %>% pbi_measure("Gross profit", "[Total revenue] - [Total cost]", 
    format = "$#,0") %>% pbi_measure("Gross margin", "DIVIDE([Gross profit], [Total revenue])", 
    format = "0.0%") %>% pbi_page("Profitability", pbi_card(pbi_ref("Total revenue"), title = "Revenue"), 
    pbi_card(pbi_ref("Gross margin"), title = "Margin on selected sales"), pbi_bar("product", 
        pbi_ref("Gross profit"), title = "Profit by product"), pbi_line("date", pbi_ref("Gross margin"), 
        title = "Margin over time"))
```

The measure helper can generate a standard aggregation from `column`; supply an expression for more involved DAX. User-written DAX is evaluated by Power BI, not parsed or executed by this R compiler. [DIVIDE documentation](https://learn.microsoft.com/en-us/dax/divide-function-dax)

### 9. Separate facts and dimensions

**Example ID:** `star`

A product dimension describes the sales table. The many-to-one relationship lets product-category selections filter sales. Explicit `pbi_field()` references make it clear which table supplies a category.

```r
products <- data.table::data.table(product = c("Atlas", "Beacon", "Cedar", "Delta"), category = c("Software", 
    "Software", "Hardware", "Hardware"))
dashboard <- pbi_dashboard("A small star schema", pbi_demo_data(), table = "Sales") %>% pbi_data("Products", 
    products) %>% pbi_relationship("Sales", "product", "Products", "product") %>% pbi_measure("Total revenue", 
    column = "revenue", table = "Sales", format = "$#,0") %>% pbi_page("Categories", pbi_slicer(pbi_field("category", 
    "Products"), title = "Product category"), pbi_bar(pbi_field("category", "Products"), 
    pbi_ref("Total revenue"), title = "Dimension filters flow to sales"), pbi_matrix(rows = pbi_field("product", 
    "Products"), values = pbi_ref("Total revenue"), title = "Product detail"))
```

The dimension key must be unique and non-missing, and both key columns must use the same model type. Single-direction filtering is the default; enable bidirectional relationships only when your model needs their semantics. [Star-schema guidance](https://learn.microsoft.com/en-us/power-bi/guidance/star-schema)

### 10. An explicit calendar and year-on-year comparison

**Example ID:** `time`

The calendar includes every day in the requested interval and is marked as a date table. The sales date relationship gives DAX time-intelligence functions a complete date axis. A page filter limits the displayed period to 2026 while the model retains 2025 for the comparison.

```r
dashboard <- pbi_dashboard("Time intelligence", pbi_demo_data(), table = "Sales") %>% pbi_date_table("2025-01-01", 
    "2026-12-31") %>% pbi_relationship("Sales", "date", "Calendar", "Date") %>% pbi_measure("Sales amount", 
    column = "revenue", table = "Sales", format = "$#,0") %>% pbi_measure("Prior year", 
    "CALCULATE([Sales amount], SAMEPERIODLASTYEAR('Calendar'[Date]))", table = "Sales", 
    format = "$#,0") %>% pbi_measure("Year-on-year", "DIVIDE([Sales amount] - [Prior year], [Prior year])", 
    table = "Sales", format = "0.0%") %>% pbi_page("2026 compared with 2025", pbi_line(pbi_field("YearMonth", 
    "Calendar"), list(pbi_ref("Sales amount"), pbi_ref("Prior year")), title = "Current and previous year"), 
    pbi_card(pbi_ref("Year-on-year"), title = "Year-on-year change"), filters = list(pbi_filter(pbi_field("Year", 
        "Calendar"), 2026L)))
```

Use calendar fields on the axis rather than a formatted fact-table date. The code declares the intended DAX; verify its results in Desktop for your real model. [SAMEPERIODLASTYEAR](https://learn.microsoft.com/en-us/dax/sameperiodlastyear-function-dax)

### 11. Filter scopes and synchronized slicers

**Example ID:** `filters`

The report filter retains Central and West throughout the report. The first page selects the 2026 monthly dates. One visual additionally excludes Delta. The two product slicers share a synchronization group so the user's selection can follow them across pages.

```r
dashboard <- pbi_dashboard("Three filter scopes", pbi_demo_data()) %>% pbi_filters(pbi_filter("region", 
    c("Central", "West"))) %>% pbi_page("Overview", pbi_slicer("product", sync = "product-selection", 
    title = "Shared product selection"), pbi_line("date", "revenue", title = "Revenue excluding Delta") %>% 
    pbi_where(pbi_filter("product", "Delta", exclude = TRUE)), pbi_card("revenue", title = "All selected products"), 
    filters = list(pbi_filter("date", seq.Date(as.Date("2026-01-01"), by = "month", length.out = 12))), 
    interactions = "filter") %>% pbi_page("Detail", pbi_slicer("product", sync = "product-selection", 
    title = "The same product selection"), pbi_bar("region", "revenue", title = "Regional sales"), 
    pbi_table(c("date", "region", "product", "revenue"), title = "Underlying snapshot"), 
    layout = pbi_layout("sidebar"))
```

These filters are report behavior, not access controls. The embedded project still contains all source rows. A synchronized group should bind the same field in each participating slicer.

### 12. Compare individual observations

**Example ID:** `scatter`

The car name is the point identifier. Average aggregation avoids treating numeric coordinates as additive quantities, while the point detail keeps each car separate. Horsepower controls bubble size, and cylinder count controls the legend.

```r
cars <- data.table::as.data.table(mtcars, keep.rownames = "car") %>% .[, `:=`(cyl, as.character(cyl))]
dashboard <- pbi_dashboard("Fuel economy", cars, theme = "accessible") %>% pbi_page("Compare cars", 
    pbi_scatter("wt", "mpg", size = "hp", details = "car", legend = "cyl", aggregate = "average", 
        tooltip = c("disp", "qsec"), title = "Fuel economy and weight", alt = "Fuel economy in miles per gallon versus vehicle weight; bubble size is horsepower."), 
    pbi_slicer("cyl", style = "list", title = "Cylinder count"), layout = pbi_layout("focus", 
        columns = 1, focus_ratio = 0.72))
```

The alt text states the axes and size meaning. Use `details` for an observation identifier; omitting it intentionally aggregates points by the remaining grouping fields.

### 13. Tables and cross-tabulations

**Example ID:** `tables`

An explicit measure in a table is evaluated for each displayed region-product group. The matrix moves products into columns and regions into rows. The same measure serves both presentations.

```r
dashboard <- pbi_dashboard("Tables and matrices", pbi_demo_data(), table = "Sales", theme = "ink") %>% 
    pbi_measure("Total revenue", column = "revenue", format = "$#,0") %>% pbi_measure("Total units", 
    column = "units", format = "#,0") %>% pbi_page("Comparative detail", pbi_table(list("region", 
    "product", pbi_ref("Total revenue"), pbi_ref("Total units")), title = "Grouped table with explicit measures"), 
    pbi_matrix(rows = "region", columns = "product", values = pbi_ref("Total revenue"), 
        title = "Region by product"))
```

A plain column binding and a measure binding have different semantics. Use measures when you want grouped totals, ratios, or distinct counts. Native table visuals group by the projected columns: duplicate rows with identical displayed values can collapse. Include a unique row identifier when a detail table must show every source observation.

### 14. Gauges, treemaps, funnels, and waterfalls

**Example ID:** `gallery`

The gallery combines four native visual forms. A gauge binds its target and bounds to measures. Pipeline and change-bridge tables have independent category orders, declared through sort columns.

```r
pipeline <- data.table::data.table(stage = c("Leads", "Qualified", "Proposals", "Won"), 
    prospects = c(2400L, 1100L, 520L, 180L), order = 1:4)
bridge <- data.table::data.table(step = c("Opening", "New business", "Expansion", "Churn"), 
    change = c(150, 40, 20, -35), order = 1:4)
dashboard <- pbi_dashboard("Native chart gallery", pbi_demo_data(), table = "Sales", theme = "midnight") %>% 
    pbi_data("Pipeline", pipeline, sort_by = c(stage = "order"), hidden = "order") %>% 
    pbi_data("Bridge", bridge, sort_by = c(step = "order"), hidden = "order") %>% pbi_measure("Current sales", 
    column = "revenue", table = "Sales", format = "$#,0") %>% pbi_measure("Sales target", 
    "900000", table = "Sales", format = "$#,0") %>% pbi_measure("Gauge maximum", "1200000", 
    table = "Sales") %>% pbi_measure("Gauge minimum", "0", table = "Sales") %>% pbi_page("Four visual forms", 
    pbi_gauge(pbi_ref("Current sales"), target = pbi_ref("Sales target"), min = pbi_ref("Gauge minimum"), 
        max = pbi_ref("Gauge maximum"), title = "Progress toward target"), pbi_treemap("product", 
        "revenue", table = "Sales", title = "Product composition"), pbi_funnel("stage", 
        "prospects", table = "Pipeline", title = "Sales pipeline") %>% pbi_sort("stage"), 
    pbi_waterfall("step", "change", table = "Bridge", title = "Change in recurring revenue") %>% 
        pbi_sort("step"))
```

The sales, pipeline, and bridge visuals deliberately use separate tables. The funnel counts are illustrative stage totals; the waterfall shows changes in the declared step order. This interface does not mark arbitrary intermediate waterfall bars as totals.

### 15. Unicode, blanks, timestamps, and large integers

**Example ID:** `types`

Unicode labels remain UTF-8, missing values become Power BI blanks, and timestamps are stored as UTC values without a timezone field. Integer IDs above the exact R-double range are supplied as decimal strings and declared as Int64.

```r
places <- data.table::data.table(city = c("Łódź", "München", "東京", NA_character_), 
    id = c("9007199254740993", "9007199254740994", "9007199254740995", "9007199254740996"), 
    value = c(12.5, NA_real_, 18.75, 0), observed = as.POSIXct(c("2026-01-01 12:00:00", 
        "2026-01-02 13:00:00", "2026-01-03 14:00:00", NA_character_), tz = "UTC"))
dashboard <- pbi_dashboard("Unicode and missing observations") %>% pbi_data("Places", places, types = c(id = "int64"), 
    formats = c(value = "0.00")) %>% pbi_page("Typed edge cases", pbi_table(c("city", "id", 
    "value", "observed"), title = "Values retain their intended types"), pbi_card("id", 
    aggregate = "distinct_count", title = "Distinct location IDs"), pbi_bar("city", "value", 
    title = "Available observations"), pbi_slicer("city", title = "Blank is a selectable value"))
```

The source payload retains those integer strings exactly before Power Query applies `Int64.Type`. That does not guarantee exact display or interactive filtering of values above 2^53 in every Power BI visual. Use character identifiers when arithmetic is unnecessary, and verify large-integer behavior in the target visual. The package does not promise sub-millisecond datetime precision in the Power BI model. [Power BI data types](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-data-types)

### 16. A complete three-page deliverable

**Example ID:** `showcase`

This report combines a deliberately positioned executive overview, a product-mix page, and a supporting-evidence page. Revenue, profit, and margin use shared measures. The final two pages share a region slicer group.

```r
dashboard <- pbi_dashboard("Northstar | Commercial performance", pbi_demo_data(), table = "Sales", theme = "linen") %>% 
    pbi_measure("Total revenue", column = "revenue", format = "$#,0") %>% pbi_measure("Total cost", 
    column = "cost", format = "$#,0") %>% pbi_measure("Gross profit", "[Total revenue] - [Total cost]", 
    format = "$#,0") %>% pbi_measure("Gross margin", "DIVIDE([Gross profit], [Total revenue])", 
    format = "0.0%") %>% pbi_page("Executive overview", pbi_card(pbi_ref("Total revenue"), 
    title = "Revenue") %>% pbi_place(24, 88, 398, 126), pbi_card(pbi_ref("Gross profit"), 
    title = "Gross profit") %>% pbi_place(441, 88, 398, 126), pbi_card(pbi_ref("Gross margin"), 
    title = "Gross margin") %>% pbi_place(858, 88, 398, 126), pbi_line("date", pbi_ref("Total revenue"), 
    title = "Monthly revenue") %>% pbi_place(24, 234, 816, 462), pbi_bar("region", pbi_ref("Total revenue"), 
    horizontal = TRUE, title = "Revenue by region") %>% pbi_place(860, 234, 396, 462), 
    layout = pbi_layout("free"), interactions = "filter") %>% pbi_page("Products and mix", 
    pbi_slicer("region", style = "list", sync = "regions", title = "Region"), pbi_treemap("product", 
        pbi_ref("Total revenue"), title = "Revenue contribution"), pbi_bar("product", pbi_ref("Gross profit"), 
        title = "Profit contribution"), pbi_donut("product", "units", title = "Unit mix"), 
    pbi_matrix("region", pbi_ref("Gross margin"), columns = "product", title = "Margin by region and product"), 
    layout = pbi_layout("sidebar"), interactions = "filter") %>% pbi_page("Trends and evidence", 
    pbi_slicer("region", style = "list", sync = "regions", title = "Region"), pbi_area("date", 
        pbi_ref("Total revenue"), legend = "product", stacked = TRUE, title = "Sales composition over time"), 
    pbi_table(list("region", "product", pbi_ref("Total revenue"), pbi_ref("Gross profit")), 
        title = "Supporting detail"), pbi_text("Source: deterministic synthetic sales panel.\nJanuary 2025 to December 2026. Values are illustrative.", 
        font_size = 15), layout = pbi_layout("sidebar"))
```

Select a region in the overview to filter its native charts. The synchronized region slicers on the other two pages form a separate cross-page selection group. Synthetic data and the time coverage are identified in the evidence page.

## Run every example

The installed example runner compiles all sixteen specifications and creates
portable bundles:

```r
Sys.setenv(PBIWEAVE_EXAMPLE_DIR = file.path(tempdir(), "pbiweave-tutorials"))
source(system.file("examples", "run-all.R", package = "pbiweave"))
```

The runner defaults to a directory inside `tempdir()` when the environment variable
is unset. It uses `lapply()` and does not silently overwrite existing builds.
Choose an unused directory for another run.

To build only selected examples:

```r
ids <- c("quickstart", "measures", "star", "showcase")
reports <- setNames(lapply(ids, pbi_example), ids)
projects <- setNames(lapply(ids, function(id) {
  pbi_compile(reports[[id]], file.path(tempdir(), paste0("selected-", id)),
              bundle = TRUE)
}), ids)
```

## Prepare data efficiently in R

The compiler receives a snapshot. Reduce unnecessary columns and rows before
adding the data; for suitable reports, pre-aggregate to the grain you will show:

```r
monthly <- pbi_demo_data() %>%
  .[, .(revenue = sum(revenue), units = sum(units)), by = .(date, region)]

dashboard <- pbi_dashboard("Compact monthly report", monthly) %>%
  pbi_page("Monthly",
    pbi_line("date", "revenue", legend = "region"),
    pbi_bar("region", "units"))
```

Pre-aggregation trades drill-down detail for a smaller model. Keep transaction
rows when users need them, and use an explicit fact/dimension model for richer
filtering. Native Import mode moves interaction work to Power BI's engine after
Refresh; pbiweave itself does not provide a query-speed benchmark or performance
guarantee. Very large embedded snapshots can increase compiler memory use,
project size, and initial refresh time.
[Import model reduction guidance](https://learn.microsoft.com/en-us/power-bi/guidance/import-modeling-data-reduction)

## Validation and reproducibility

```r
dashboard <- pbi_example("showcase")
pbi_validate(dashboard)
project <- pbi_compile(dashboard, file.path(tempdir(), "review-build"))
pbi_check(project)
```

`pbi_validate()` checks the R specification and model references before writing.
`pbi_check()` checks a generated project's JSON and required file references. The source
distribution additionally includes an independent Python validator using the
bundled Microsoft JSON schema registry:

```sh
python -m pip install jsonschema
python tools/validate_project.py /path/to/project --json
```

Run that command from the source repository. The validator does not download
schemas at runtime. Use the same package version, input values, and specification
to keep the generated source definitions reproducible.

The R tests and offline schema validator check different properties. Neither
replaces an acceptance pass in Power BI Desktop: refresh the model, inspect each
page, test the slicers and relationships, compare key totals with R, and save a
PBIX. In particular, valid JSON does not prove valid DAX or guarantee a particular
chart's rendered appearance.

## Practical boundaries

- **Native reports:** the package emits PBIR reports and a TMSL `model.bim` import
  model. It does not create a Power BI service dashboard, app, or workspace.
- **Final PBIX:** Desktop Refresh and Save As remain required. Renaming the ZIP
  to `.pbix` does not create a PBIX.
- **Snapshots:** the embedded data do not automatically follow later R changes.
  Refresh reconstructs the compiled snapshot. Rebuild to update the data.
- **Security:** filters and hidden columns do not remove data from the artifact
  or implement row-level security.
- **Custom visuals:** the supported interface uses native visuals. No AppSource
  installation, external JavaScript widget, or R visual is required.
- **Advanced authoring:** automatic drillthrough pages, bookmarks, mobile layouts,
  calculation groups, deployment APIs, external refresh sources, and arbitrary
  custom visual properties are outside this release's interface.
- **Native evaluation:** arbitrary DAX and Power Query expressions cannot be
  validated by the R compiler alone.
- **Dates and currency:** UTC timestamps lose a separate timezone label;
  fixed-decimal currency uses Power BI's four-decimal model type.
- **Publication:** review font availability, labels, legends, filter behavior,
  and measure results in the target Desktop version before distributing the
  final report.

## Format and dependency references

The implementation follows public Microsoft definitions and current native
report samples, rather than an undocumented imitation of the PBIX binary
container:

- [Power BI projects](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview)
- [PBIR report definitions](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report)
- [Semantic model definitions and model.bim example](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/semantic-model-definition)
- [Microsoft JSON schemas](https://github.com/microsoft/json-schemas)
- [Official Power BI Desktop samples](https://github.com/microsoft/powerbi-desktop-samples)
- [M Binary.Decompress](https://learn.microsoft.com/en-us/powerquery-m/binary-decompress)
- [M Table.FromRows](https://learn.microsoft.com/en-us/powerquery-m/table-fromrows)
- [M Table.TransformColumnTypes](https://learn.microsoft.com/en-us/powerquery-m/table-transformcolumntypes)
- [R in-memory compression documentation](https://stat.ethz.ch/R-manual/R-devel/library/base/html/memCompress.html)

The runtime dependencies are **data.table**, **jsonlite**, **base64enc**,
**magrittr**, **digest**, and **zip**. **testthat** supports development testing;
**bit64** is optional for supplying integer64 input. The source distribution
retains Microsoft's MIT notice for the bundled schemas. Dependency packages
retain their respective licenses and authorship; see the package's
[acknowledgments](inst/ACKNOWLEDGEMENTS.md), [MIT license](LICENSE.md), and the
[Microsoft schema notice](inst/schemas/LICENSE-MICROSOFT).

## License and author

MIT license. Copyright 2026 Alek Rutkowski.

Author and maintainer: Alek Rutkowski, <alek.rutkowski@gmail.com>.

Microsoft, Power BI, and related product names belong to their respective owners.
This package is independent of Microsoft.

