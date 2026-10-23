"""Maintain checked-in Rd documentation from explicit prose and source signatures.
This generator is a development tool, not a runtime dependency of pbiweave.
"""
from pathlib import Path
import re, json
ROOT = Path(__file__).resolve().parents[1]
VERSION = re.search(r'^Version:\s*(\S+)', (ROOT/'DESCRIPTION').read_text(), re.M).group(1)

# Explanations intentionally distinguish R construction from Power BI runtime.
DOC = {
'pbi_dashboard': ('Start a declarative report specification',
 'Creates an in-memory report specification and optionally snapshots a first data frame. Nothing is published and no Power BI process is started.',
 'Build a report by piping this object through data, measure, and page constructors, then call pbi_compile(). Incoming data.tables are copied, so later by-reference edits to the original do not alter the snapshot. A specification is not a running application. R calculations finish before compilation; native Power BI filtering starts after opening and refreshing the generated project.',
 'A pbi_dashboard object. Most model and page helpers return a modified object of this class.',
 '''d <- pbi_dashboard("Revenue", pbi_demo_data(), table = "Sales") %>%
  pbi_page("Overview", pbi_card("revenue"), pbi_bar("region", "profit"))
pbi_validate(d)$valid'''),
'pbi_data': ('Embed another data frame in the model',
 'Adds a copied, typed data snapshot under a unique model-table name.',
 'Use one table for observation-level data and additional tables for dimensions. Adding tables does not join or relate them. Define a many-to-one relationship explicitly with pbi_relationship(). Data are embedded in the generated source; hidden tables are not a security boundary. Factors become text, Dates remain dates, and timestamps are serialized in UTC. Lists, complex vectors, and raw columns must be converted in R first.',
 'The modified pbi_dashboard object.',
 '''sales <- pbi_demo_data()
dim_region <- data.frame(region = unique(sales$region),
                         area = c("A", "B", "C"))
d <- pbi_dashboard("Regions", sales, table = "Sales") %>%
  pbi_data(dim_region, "Regions") %>%
  pbi_relationship("Sales", "region", "Regions", "region")
length(d$tables)'''),
'pbi_prepare': ('Run a build-time R transformation on a private copy',
 'Calls an ordinary R function once on a copy of a data frame and returns its resulting data.table.',
 'This is deliberately not a reactive expression or callback registration. The supplied function runs immediately. It may clean values, join data, calculate features, or preaggregate, but must return a data frame. Copying prevents data.table := inside the function from modifying the caller\'s original object. Changing a slicer in the exported report will never rerun transform.',
 'A copied data.table containing the result.',
 '''sales <- pbi_demo_data()
prepared <- pbi_prepare(sales, function(d) {
  d[, profit_per_unit := profit / units]
  d
})
stopifnot(!"profit_per_unit" %in% names(sales))
head(prepared)'''),
'pbi_column': ('Describe a column for the semantic model',
 'Sets presentation metadata, semantic types, visibility, and sort-by behavior for an existing column.',
 'This does not mutate the underlying R values. Perform substantive conversions in R before adding data; in particular, use Date and POSIXct for dates and timestamps. sort_by is useful for month names and ordered bands. A displayed label must map to only one sort key, and circular sort mappings are rejected. Model formats use Power BI format strings, not sprintf() formats. Mark identifiers with summarize = "none". Hidden columns remain in the embedded data.',
 'The modified pbi_dashboard object.',
 '''d <- pbi_dashboard("Typed model", pbi_demo_data()) %>%
  pbi_column("revenue", type = "decimal", format = "$#,0.00") %>%
  pbi_column("row_id", hidden = TRUE, summarize = "none")
d$tables$Data$columns$revenue$format'''),
'pbi_field': ('Refer to a model column without writing DAX',
 'Constructs a column reference, optionally qualified by table and given an aggregation, display label, or visual-level format.',
 'A string field name normally resolves in the report\'s first table. Qualify fields from dimensions, or ambiguous names, with table. Value roles default to sums for numeric columns, while category, slicer, and detail-table roles stay unaggregated. Setting aggregate explicitly overrides that rule. This function does not extract an R vector: it describes a field that Power BI will query later.',
 'A pbi_field reference consumed by visual constructors.',
 '''f <- pbi_field("revenue", table = "Sales", aggregate = "average",
               label = "Mean revenue", format = "$#,0.00")
v <- pbi_bar("region", f, table = "Sales")
print(v)'''),
'pbi_ref': ('Refer to an explicitly defined model measure',
 'Creates a measure reference for use in a card, chart, table, or matrix.',
 'Use pbi_ref() rather than a bare name for measures created by pbi_measure() or pbi_ratio(). A measure is evaluated against the current Power BI filter context. The name must exist when the report is validated or compiled. An explicit table can disambiguate a reference, although this implementation requires measure names to be globally unique.',
 'A pbi_field reference with kind = "measure".',
 '''d <- pbi_dashboard("Revenue", pbi_demo_data()) %>%
  pbi_measure("Total revenue", column = "revenue") %>%
  pbi_page("Summary", pbi_card(pbi_ref("Total revenue")))
pbi_validate(d)$valid'''),
'pbi_aggregate': ('Choose the selection-time summary for a column',
 'Builds a column reference with an explicit native aggregation.',
 'No rows are aggregated in R by this helper. It tells Power BI to sum, average, count, find a minimum or maximum, or count distinct values after applying the viewer\'s filters. count counts nonblank values; it is not a row count when the column has missing values. For record counts, prepare a column of ones in R and sum it. The average of a 0/1 indicator with NA for unknown outcomes is a valid observed-outcome proportion. Do not average preaggregated group means: use sufficient statistics and pbi_ratio().',
 'A pbi_field reference with an explicit aggregation.',
 '''d <- pbi_dashboard("Average margin", pbi_demo_data()) %>%
  pbi_page("Explore", pbi_bar("region",
    pbi_aggregate("margin", "average", format = "0.0%")))
pbi_validate(d)$valid'''),
'pbi_measure': ('Define an optional DAX measure',
 'Adds either a simple aggregation measure or an explicit DAX expression.',
 'Supply exactly one of column and expression. Prefer R for transformations and model-fitting; use a measure only when a value genuinely depends on a viewer\'s current selection. Free-form DAX is passed through, not evaluated or parsed by R. Its validity must be checked in Power BI. A sum measure is a convenient reusable label, not a requirement for using a numeric column in a visual.',
 'The modified pbi_dashboard object.',
 '''d <- pbi_dashboard("Profit", pbi_demo_data(), table = "Sales") %>%
  pbi_measure("Revenue total", column = "revenue", format = "$#,0") %>%
  pbi_measure("Cost total", column = "cost", format = "$#,0") %>%
  pbi_measure("Profit total", "[Revenue total] - [Cost total]", format = "$#,0") %>%
  pbi_page("Summary", pbi_card(pbi_ref("Profit total")))
pbi_validate(d)$valid'''),
'pbi_ratio': ('Combine R-precomputed sufficient statistics correctly',
 'Defines a ratio of two native sums without requiring handwritten DAX.',
 'The generated measure is DIVIDE(SUM(numerator), SUM(denominator)). Prepare both additive columns in R at the chosen data grain. For a rate, store event counts and eligible counts. For a mean, store a value sum and its nonmissing observation count. This preserves weighted results under arbitrary supported filtering; averaging cell means does not. A zero denominator produces a blank, not an invented zero. A ratio is still evaluated by Power BI at viewing time.',
 'The modified pbi_dashboard object with an additional measure.',
 '''cells <- data.frame(group = c("small", "large"),
                    value_sum = c(0, 1000), observed = c(2L, 100L))
d <- pbi_dashboard("Weighted mean", cells) %>%
  pbi_ratio("Mean value", "value_sum", "observed", format = "0.00") %>%
  pbi_page("Summary", pbi_card(pbi_ref("Mean value")))
# The unfiltered result should be 1000 / 102, not mean(c(0, 10)).
pbi_validate(d)$valid'''),
'pbi_relationship': ('Connect a fact table to a unique dimension key',
 'Creates an active or inactive many-to-one relationship and checks key integrity.',
 'from_table/from_column identify the many-side fact key. to_table/to_column identify the one-side dimension key. With the default single direction, dimension selections filter fact rows, not the reverse. Dimension keys must be unique and nonblank, including simple case and surrounding-space collisions. Unmatched fact keys fail by default; create an explicit unknown dimension member to retain those rows. both can create ambiguous filter paths and should be used deliberately. These checks do not implement the full Power BI collation or relationship engine.',
 'The modified pbi_dashboard object.',
 '''sales <- pbi_demo_data()
regions <- data.frame(region = unique(sales$region),
                      manager = c("Alex", "Sam", "Robin"))
d <- pbi_dashboard("Team sales", sales, table = "Sales") %>%
  pbi_data(regions, "Regions") %>%
  pbi_relationship("Sales", "region", "Regions", "region") %>%
  pbi_page("Teams", pbi_bar(pbi_field("manager", "Regions"), "revenue"))
pbi_validate(d)$valid'''),
'pbi_calendar': ('Build a contiguous calendar in R',
 'Creates a daily calendar table and relates it to a Date column in the fact table.',
 'The default range covers all nonmissing dates in the selected source column. The calendar contains Date, Year, Month, MonthName, Day, and ISO-style Weekday (Monday = 1). MonthName is sorted by Month, and the Date column is marked as a key. Convert timestamps to dates in R before calling this helper so joins are at the intended day grain. DAX time-intelligence expressions remain optional. Supplying bounds that exclude fact dates leaves those facts unmatched.',
 'The modified pbi_dashboard object, with a calendar table and relationship.',
 '''d <- pbi_dashboard("Calendar", pbi_demo_data(), table = "Sales") %>%
  pbi_calendar("date", table = "Sales") %>%
  pbi_page("Monthly", pbi_slicer("Year", table = "Calendar"),
           pbi_bar(pbi_field("MonthName", "Calendar"), "revenue"))
pbi_validate(d)$valid'''),
'pbi_theme': ('Choose coordinated colors and typography',
 'Constructs a theme specification used by the report and visual containers.',
 'Presets are linen, midnight, ocean, forest, ink, accessible, and european_commission. The European Commission preset combines the supplied EC Colour Palette 2024 presentation template with current Europa Component Library surfaces. It is an original EC-inspired adaptation, not an official or certified theme. Override palette and background/foreground/surface together when adapting a brand so text remains readable. Colors use #RRGGBB. Fonts are referenced by name; no font files are distributed.',
 'A pbi_theme object accepted by pbi_dashboard().',
 '''theme <- pbi_theme("european_commission")
d <- pbi_dashboard("European Commission style", pbi_demo_data(), theme = theme) %>%
  pbi_page("Overview", pbi_bar("region", "revenue"))
pbi_validate(d)$valid
# Override heading color independently on an existing preset.
pbi_theme("linen", foreground = "#222222", title_color = "#003399")
# Explicit fonts take precedence over preset defaults.
pbi_theme("european_commission", font = "Segoe UI")'''),
'pbi_layout': ('Declare how visuals occupy a fixed report canvas',
 'Constructs a grid, sidebar, focus, or free-position layout.',
 'A grid packs visual spans from left to right using first-fit placement. A sidebar places slicers in a left-hand column and other visuals in a grid on the right. A focus layout gives the first visual a large upper area and places others below it. Free layouts require pbi_place() on every visual. The compiler reserves a heading area. These are Power BI canvas arrangements, not responsive HTML/CSS breakpoints. Page scaling is native Power BI FitToPage.',
 'A pbi_layout object accepted by pbi_page() or pbi_screen().',
 '''d <- pbi_dashboard("Grid", pbi_demo_data()) %>%
  pbi_page("Overview", pbi_card("revenue"), pbi_card("profit"),
           pbi_span(pbi_line("date", "revenue"), columns = 2),
           layout = pbi_layout("grid", columns = 2, gap = 20))
pbi_validate(d)$valid'''),
'pbi_page': ('Add a page of native visuals',
 'Adds a named report page containing visual specifications and a layout.',
 'Visuals may be supplied separately in ... or as one list, which makes lapply() useful for reusable page builders. IDs must be unique within the page. native interactions use Power BI\'s default filtering/highlighting choices; filter forces data filtering between selectable visuals and other data visuals; none disables those interactions unless explicitly overridden by pbi_bind(). Report-level and page-level filters still apply. Page names are tabs, not Shiny routes.',
 'The modified pbi_dashboard object.',
 '''d <- pbi_dashboard("Sales", pbi_demo_data()) %>%
  pbi_page("Summary", pbi_card("revenue"), pbi_bar("product", "profit")) %>%
  pbi_page("Detail", pbi_table(c("date", "region", "revenue")))
length(d$pages)'''),
'pbi_span': ('Give a visual more grid cells',
 'Sets the integer column and row span of a visual in a grid-based layout.',
 'Spans change geometry, not the data query. A column span cannot exceed the number of grid columns. The layout solver allocates enough rows and shares the available page height between them. Large spans on a crowded page can still produce unreadable visuals; use pbi_validate() warnings and review the rendered page. Use pbi_place() rather than spans for a free layout.',
 'The modified pbi_visual object.',
 '''d <- pbi_dashboard("Spans", pbi_demo_data()) %>%
  pbi_page("Overview", pbi_span(pbi_line("date", "revenue"), columns = 2),
           pbi_card("revenue"), pbi_card("profit"),
           layout = pbi_layout(columns = 2))
pbi_validate(d)$valid'''),
'pbi_place': ('Place a visual precisely on a free-layout page',
 'Assigns a visual\'s left/top position and width/height in report-canvas units.',
 'Coordinates are measured from the top-left of the page. Use layout = pbi_layout("free"). Place data visuals below the reserved heading region; its height depends on the layout padding, header and gap settings. Bounds are checked, while overlaps are reported for review rather than rejected because intentional layering is possible. Geometry is fixed at compilation time.',
 'The modified pbi_visual object.',
 '''d <- pbi_dashboard("Custom composition", pbi_demo_data()) %>%
  pbi_page("Overview", pbi_place(pbi_card("revenue"), 24, 90, 280, 160),
           pbi_place(pbi_bar("product", "profit"), 328, 90, 900, 560),
           layout = pbi_layout("free"))
pbi_validate(d)$valid'''),
'pbi_sort': ('Set a visual query\'s sort order',
 'Requests ascending or descending sorting by a model column or measure.',
 'The field should be present in the visual. When a bare column name identifies exactly one projected aggregate, the compiler reuses that aggregation for sorting. Supply an explicit pbi_field(), pbi_aggregate(), or pbi_ref() to avoid ambiguity. Sorting a displayed month-name column is usually better handled by pbi_column(sort_by = "Month") than by alphabetic sorting.',
 'The modified pbi_visual object.',
 '''v <- pbi_bar("product", "revenue") %>%
  pbi_sort("revenue", "descending")
d <- pbi_dashboard("Ranked products", pbi_demo_data()) %>%
  pbi_page("Rank", v)
pbi_validate(d)$valid'''),
'pbi_filter': ('Apply a static include or exclude filter at a chosen scope',
 'Adds a categorical filter to an entire report, a named page, or one visual.',
 'For a dashboard, page = NULL means report scope; specify a page name for page scope. For a visual, the filter applies only to that visual. These are initial static query constraints, not reactive R subsets and not row-level security. Slicer selections combine with these constraints, so a slicer cannot make excluded rows available. Values must not be NA; create a meaningful missing-value category in R. This helper supports inclusion/exclusion, not arbitrary range, Top N, or DAX filter expressions.',
 'The modified pbi_dashboard or pbi_visual object.',
 '''d <- pbi_dashboard("Scoped filters", pbi_demo_data()) %>%
  pbi_page("East only", pbi_bar("product", "revenue"),
           pbi_card("profit") %>% pbi_filter("product", "Atlas")) %>%
  pbi_filter("region", "East", page = "East only")
pbi_validate(d)$valid'''),
'pbi_input': ('Declare a Shiny-style input ID backed by a native slicer',
 'Creates a native slicer with an explicit ID for subsequent interaction bindings.',
 'This is a convenience wrapper around pbi_slicer(), not a Shiny input object. The ID is a compile-time visual identifier; there is no input$id value available to R while the exported report runs. Fields must be model columns. With pbi_screen()\'s default disabled interactions, use pbi_bind() to name the outputs affected by this input. single controls selection behavior but does not supply an initial selected value.',
 'A pbi_visual object representing a slicer.',
 '''d <- pbi_dashboard("Input example", pbi_demo_data()) %>%
  pbi_screen("Explore", pbi_input("region", "region", label = "Region"),
             pbi_output("sales", pbi_card("revenue"))) %>%
  pbi_bind("region", "sales")
pbi_flow(d)'''),
'pbi_output': ('Give a native visual a stable output ID',
 'Assigns an ID to an existing visual specification.',
 'The helper provides naming similar to output$plot in Shiny, but it does not register a render function. Pass a completed pbi_bar(), pbi_line(), or other visual, not an R function. IDs are unique per page. A native chart can also be a source of data-point selections, so bindings are not limited to slicer inputs.',
 'The same pbi_visual specification with its ID replaced.',
 '''v <- pbi_output("trend", pbi_line("date", "revenue", title = "Revenue trend"))
print(v)'''),
'pbi_screen': ('Add an explicitly wired, Shiny-style screen',
 'Adds a report page with a sidebar layout and interactions disabled by default.',
 'This is a page-construction wrapper. It intentionally uses interactions = "none" so omitted pbi_bind() calls are visible as missing behavior rather than hidden default links. Every input-to-output route must then be declared. Static report/page filters and synchronized slicer state are separate from these links. For a page without slicers choose a grid layout explicitly.',
 'The modified pbi_dashboard object.',
 '''d <- pbi_dashboard("Screen", pbi_demo_data()) %>%
  pbi_screen("Explore", pbi_input("product", "product"),
    pbi_output("revenue", pbi_card("revenue")),
    pbi_output("trend", pbi_line("date", "revenue"))) %>%
  pbi_bind("product", c("revenue", "trend"))
pbi_flow(d)'''),
'pbi_bind': ('Declare which visual selections affect which outputs',
 'Sets directed Power BI interaction edges between visual IDs on one page.',
 'filter translates to a native DataFilter interaction, none to NoFilter, and native leaves the choice to Power BI. Later bindings replace earlier bindings for the same source/target pair. Sources must support selections; static text, cards, and gauges are not input sources. pbi_text() is not a reactive text output. Bindings do not join tables: the semantic model must have the necessary relationships for a selected dimension to filter a fact visual. This is not bindEvent() and does not execute R code.',
 'The modified pbi_dashboard object.',
 '''d <- pbi_example("shiny") %>%
  pbi_bind("region", "trend", mode = "none")
pbi_flow(d, include_disabled = TRUE)'''),
'pbi_flow': ('Inspect declared visual-interaction dependencies',
 'Returns a table of potential directed selection flows in a report specification.',
 'Each row identifies page, source ID, target ID, mode, and whether an explicit binding overrides the page default. Disabled edges are omitted unless requested. This is a static inspection tool, not a live reactlog and not proof that data can propagate through the semantic model. It does not include DAX dependency inference, relationship paths, or cross-page slicer synchronization. Native chart interactions may form cycles; they are not a Shiny reactive dependency DAG.',
 'A data.table with page, source, target, mode, and explicit columns.',
 '''d <- pbi_example("shiny")
pbi_flow(d)
pbi_flow(d, page = "Explore", include_disabled = TRUE)'''),
'pbi_validate': ('Preflight a report specification before writing files',
 'Checks fields, measures, types, filters, layouts, sort metadata, and slicer synchronization.',
 'Invalid specifications raise an informative error. A successful result includes nonfatal layout warnings and runtime_checked = FALSE. Free-form DAX and Power Query execution, Desktop rendering, loaded row counts, and publish permissions are not evaluated. Validation is a compile-time safety check, not a certificate that a report has been refreshed or is publication-ready. Read and resolve warnings rather than inspecting only $valid.',
 'A list containing valid, warnings, tables, pages, runtime_checked, and note.',
 '''d <- pbi_example("showcase")
check <- pbi_validate(d)
check$valid
check$warnings'''),
'pbi_compile': ('Compile a portable project using TMDL by default',
 'Writes report definitions, embedded data, and a TMDL or legacy TMSL semantic model to a project directory.',
 'The default model_format = "tmdl" writes a definition/ folder and never a model.bim file. Explicit "tmsl" writes model.bim instead. Both formats use the same internal model and embedded data source. Compilation stages files before committing them. overwrite = TRUE only replaces a directory bearing a pbiweave manifest and retains the old project in a sibling backup directory. Close Desktop before replacing an open project. A bundle ZIP contains all source definitions, not a processed Power BI cache. On first opening select Home -> Refresh, review the visuals, and use Save As .pbix. There is no supported headless PBIX build step implemented here.',
 'A pbi_project object containing path, project_file, model_format, optional bundle, and optional backup.',
 '''d <- pbi_example("quickstart")
p <- pbi_compile(d, tempfile("pbiweave-example-"))
p$model_format
pbi_check(p)$valid
# For legacy output, use model_format = "tmsl" in a different directory.
unlink(p$path, recursive = TRUE)'''),
'pbi_check': ('Inspect a generated project without claiming it is refreshed',
 'Checks generated files, model-format exclusivity, JSON parsing, references, and optionally embedded data or file hashes.',
 'This checker understands projects generated by this package and their build manifests. $valid describes structural and payload checks only. $data_loaded is NA because the checker does not inspect a live Power BI engine, and $runtime_checked is FALSE. Merely finding cache.abf is not evidence that refresh succeeded. verify_hashes is useful immediately after compiling; intentional Desktop edits can change hashes, source formatting, or paths. After such edits, disable payload checks or recompile before comparing against the old manifest. TMDL text is not parsed by Microsoft TOM here; use Desktop or the supplied TOM validation script for that acceptance step.',
 'A diagnostic list with valid, errors, notes, model_format, embedded_data_checked, cache_present, data_loaded, runtime_checked, and next_step.',
 '''p <- pbi_compile(pbi_example("quickstart"), tempfile("check-"))
c <- pbi_check(p, verify_hashes = TRUE)
stopifnot(c$valid, is.na(c$data_loaded), !c$runtime_checked)
unlink(p$path, recursive = TRUE)'''),
'pbi_open': ('Open the project and print the mandatory first-refresh instructions',
 'Opens the generated .pbip entry point using the Windows file association, or returns its path on other systems.',
 'Home -> Refresh is required on the first Desktop opening because the generated project contains embedded source data but no processed data cache. pbi_open() never triggers a refresh, presses GUI buttons, or publishes a report. On Linux and WSL, use Power BI Desktop on Windows to open the returned path. After refreshing, compare totals with R, test selections, and save as .pbix to include the loaded cache.',
 'The .pbip filename, invisibly. A clear refresh notice is always printed.',
 '''p <- pbi_compile(pbi_example("quickstart"), tempfile("open-"))
if (interactive() && .Platform$OS.type == "windows") pbi_open(p)
# In Desktop: Home -> Refresh, inspect the report, then Save As .pbix.
# Retain p$path while the report is open.'''),
'pbi_demo_data': ('Create deterministic demonstration data without changing the RNG',
 'Returns a small synthetic sales data.table used by the examples and help pages.',
 'Rows cover 24 monthly dates, three regions, and four products. Columns include row_id, channel, units, revenue, cost, profit, and margin. Values are generated by deterministic arithmetic, not random sampling. The data are fictional and must not be presented as observed business performance. For expected showcase totals, compute sums from this returned object rather than reusing numbers from a previous package release.',
 'A data.table with dates, categories, counts, and numeric financial-style values.',
 '''d <- pbi_demo_data()
head(d)
d[, .(revenue = sum(revenue), profit = sum(profit), units = sum(units))]'''),
'pbi_example': ('Construct one of the teaching report specifications',
 'Builds a complete example specification without writing files or opening Desktop.',
 'Names quickstart, typed, themes, grid, sidebar, focus, free, measures, star, time, filters, scatter, tables, gallery, types, showcase, and shiny are supported in that order. A numeric index selects the same sequence. The examples use deterministic fictional data. Select a theme, inspect the specification with pbi_validate(), and choose a new output directory when compiling. The flight tutorials are separate, fully annotated scripts under inst/examples.',
 'A pbi_dashboard object ready for pbi_compile().',
 '''d <- pbi_example("showcase", theme = "midnight")
pbi_validate(d)$valid
print(pbi_example(1))'''),
}

# Specific visual documentation; shared mechanics are supplemented with chart-specific cautions.
VIS = {
'pbi_bar': ('Compare categories with a bar or column chart', 'Plots an aggregated value by category, with optional series, stacking, or percent stacking.', 'Horizontal bars are useful for long labels. Set horizontal = FALSE for columns. percent selects 100% stacking. A numeric value defaults to a sum; use pbi_aggregate() for an average or pbi_ref() for a measure. A chart selection can filter other visuals when interactions permit it.', 'pbi_bar("region", "revenue", series = "product", stacked = TRUE, title = "Revenue mix")'),
'pbi_line': ('Show a trend or ordered comparison', 'Plots one or more value series against an ordered category, commonly a date.', 'Prepare dates and any rolling averages in R. A date column is a real Date value, not a formatted string. Precomputed rolling averages do not recalculate when a viewer filters the report. A basic sum or mean still aggregates within the selected native filter context. Multiple values can be supplied as a list of field references.', 'pbi_line("date", "revenue", series = "region", title = "Monthly revenue")'),
'pbi_area': ('Show a filled trend', 'Creates an area chart with an optional stacked series presentation.', 'Area emphasizes magnitude over time. Stacking is useful for additive parts of a whole, not unrelated percentages. Precompute transformed series in R and retain the grouping columns needed by slicers.', 'pbi_area("date", "revenue", series = "region", stacked = TRUE, title = "Revenue composition")'),
'pbi_scatter': ('Compare observations or aggregates in two dimensions', 'Creates a scatter chart, optionally encoding group with color and magnitude with bubble size.', 'Supply details as a unique row identifier to obtain one point per observation. Without details, native aggregations can collapse many rows into one point or one point per series. A hidden identifier is still usable as a details field. For large datasets, prepare a meaningful summary or sample in R and explain the sampling rule. Bubble size must have a meaningful nonnegative magnitude.', 'pbi_scatter("units", "profit", details = "row_id", series = "region", size = "revenue", title = "Sales observations")'),
'pbi_pie': ('Show a small categorical composition', 'Creates a native pie chart from a category and value.', 'Use a pie only for a small number of nonnegative, additive categories. A sorted bar chart is usually better for precise comparisons or many categories. Precompute Others groups in R when appropriate; grouping should be reproducible and explicitly described.', 'pbi_pie("region", "revenue", title = "Revenue by region")'),
'pbi_donut': ('Show a compact part-to-whole composition', 'Creates a native donut chart from a category and value.', 'As with a pie, use only a few nonnegative additive groups. The hole is a visual style, not another data field or a separate KPI. Put an explicit pbi_card() alongside the chart for a total.', 'pbi_donut("region", "revenue", title = "Regional composition")'),
'pbi_treemap': ('Show a hierarchical area composition', 'Creates rectangles sized by a value, optionally split by a second category.', 'category is the primary Group role and group supplies a more detailed split. Values should be nonnegative and additive. This is a native Power BI treemap, not an R plot embedded as an image.', 'pbi_treemap("region", "revenue", group = "product", title = "Regional product mix")'),
'pbi_funnel': ('Display ordered stages or ranked categories', 'Creates a native funnel visual from categorical labels and an aggregated value.', 'A funnel does not infer a process or calculate conversion rates. Prepare genuine stage counts and meaningful stage ordering in R; unrelated category counts should not be described as sequential conversion. Use pbi_column(sort_by = ...) or an explicit visual sort when appropriate.', 'pbi_funnel("region", "units", title = "Units by region (not a conversion funnel)")'),
'pbi_waterfall': ('Explain additive contributions to a total', 'Creates a native waterfall from categories and signed contributions.', 'Positive and negative contributions should be calculated in R from the analytical question. Passing already cumulative totals would count them again. breakdown adds a secondary categorical split. Native total/breakdown presentation still needs a Desktop review.', 'pbi_waterfall("region", "profit", title = "Contributions to profit")'),
'pbi_card': ('Present a single selection-dependent value', 'Creates a native single-value card.', 'A numeric column defaults to a sum. Use an explicit aggregation for an average or count, or a pbi_ref() for a measure. title is static text; the number is queried under current filters. Empty or zero-denominator measure results can display as blank. A card is not a selectable input source for pbi_bind().', 'pbi_card("revenue", title = "Total revenue")'),
'pbi_gauge': ('Compare a value with a target and bounded scale', 'Creates a native gauge with optional target, minimum, and maximum.', 'Bounds can be numeric constants or model field/measure references. Constants are fixed at compilation; fields are evaluated in the current selection. Use a coherent scale and a clearly documented target. Gauges are not selection sources for pbi_bind().', 'pbi_gauge("revenue", target = 900000, minimum = 0, maximum = 1800000, title = "Revenue target")'),
'pbi_table': ('Show unaggregated detail fields or explicit summaries', 'Creates a native table visual from a vector or list of fields.', 'Plain column names are unaggregated in this visual. Explicit pbi_aggregate() and pbi_ref() values remain aggregated. Power BI can group identical combinations of unaggregated displayed fields, so include a unique row ID when every source record must be distinguishable. A visual is not a guaranteed full-data export; native query reduction can limit displayed rows.', 'pbi_table(c("row_id", "date", "region", "product", "revenue"), title = "Detail rows")'),
'pbi_matrix': ('Cross-tabulate values by row and column groups', 'Creates a native matrix with row groups, optional column groups, and one or more values.', 'The matrix evaluates values under each row/column filter context. A ratio-of-sums measure correctly recomputes totals; a precomputed percentage averaged across unequal groups does not. Supply several fields as a list to combine measures and columns. Prepare bespoke statistics in R at a grain that preserves the intended filters.', 'pbi_matrix("region", "revenue", columns = "product", title = "Revenue cross-tabulation")'),
'pbi_slicer': ('Add a viewer-operated filter', 'Creates a native dropdown, list, or between-range slicer bound to one model column.', 'The choices come from the embedded column rather than an R callback. between requires a numeric or date column. single affects selection behavior but does not specify an initial selected value. Giving slicers on multiple pages the same sync name synchronizes their selection state; they must refer to the same column. On explicit pbi_screen() pages use bindings to connect the slicer to outputs.', 'pbi_slicer("region", title = "Choose regions", style = "list", sync = "region")'),
'pbi_text': ('Add static explanatory text', 'Creates a native text box with a fixed string, size, and weight.', 'Text is evaluated and embedded at build time. It does not become renderText() and cannot be a data-filtered output. Compute explanatory prose in R before compiling or use a numeric card for a selection-dependent value. Newline characters create separate paragraphs.', 'pbi_text("Select a region to explore the report.\nData are synthetic.", size = 15)'),
}
for name,(title,desc,details,expr) in VIS.items():
    DOC[name] = (title, desc, details, 'A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.',
                'v <- '+expr+'\nd <- pbi_dashboard("Visual example", pbi_demo_data()) %>%\n  pbi_page("Example", v)\npbi_validate(d)$valid')

ARG = {
'x':'An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.',
'y':'The value field or list of value fields. Use pbi_aggregate() or pbi_ref() when the default summary is not appropriate.',
'value':'The value field, aggregate reference, or measure reference to display.',
'values':'The value fields for a matrix; for pbi_filter(), the allowed or excluded values of a single column.',
'data':'A data.frame, data.table, or tibble. The package stores a copy rather than a live R data source.',
'title':'A static human-readable report or visual title. NULL uses no visual title.',
'name':'A unique model, measure, page, or example name, as described above.',
'column':'An existing column name, supplied as a string. A calendar column must contain R Date values.',
'table':'The model table name. NULL uses the first table or an unambiguous field resolution.',
'theme':'A named theme preset or an object returned by pbi_theme().',
'description':'Optional explanatory metadata stored with the model object.',
'hidden':'Whether to hide the table or column from the field list. This does not remove or secure its data.',
'transform':'An ordinary R function taking a private data.table copy and returning a data frame. It is called immediately, once.',
'...':'Additional visual specifications, transformation arguments, or print arguments, depending on the function.',
'format':'A Power BI format string, such as "#,0", "$#,0.00", or "0.0%". It is not an R sprintf() pattern.',
'sort_by':'Another column in the same table that provides a unique ordering for each displayed value.',
'summarize':'The model-column default summarization. Use "none" for identifiers.',
'data_category':'Optional Power BI category metadata, for example "Latitude" or "Longitude".',
'aggregate':'An explicit native aggregation, or NULL to choose according to the visual role.',
'label':'Optional user-facing field or input label. It does not change the underlying column name.',
'fun':'The native summary: sum, average, min, max, count (nonblank), or distinctcount.',
'expression':'A DAX expression string. It is passed through for evaluation by Power BI; R does not validate the DAX grammar.',
'numerator':'An additive numeric column containing R-precomputed numerator totals.',
'denominator':'An additive numeric column containing the matching eligible counts or denominator totals.',
'from_table':'The many-side fact table name.', 'from_column':'The fact-table foreign-key column.',
'to_table':'The one-side dimension table name.', 'to_column':'The unique, nonblank dimension key.',
'direction':'For relationships: single (dimension to fact) or both. For visual sorting: ascending or descending.',
'active':'Whether the relationship participates in the default filter propagation.',
'unmatched':'How to handle missing or unmatched fact keys: error, warn, or allow. The default prevents silent mismatches.',
'from':'Optional first Date for a generated calendar; default is the source minimum.',
'to':'Optional last Date for a generated calendar; default is the source maximum.',
'preset':'One of the coordinated built-in theme names.',
'palette':'Optional vector of at least two #RRGGBB categorical colors.',
'background':'Optional #RRGGBB page background.', 'foreground':'Optional #RRGGBB text color.',
'surface':'Optional #RRGGBB visual-panel background.',
'font':'Font-family name referenced by the report. When omitted, european_commission uses Arial and existing presets use Segoe UI. An explicit font always takes precedence.',
'title_color':'Optional scalar #RRGGBB heading color, independent of foreground. NULL uses #003399 for european_commission and the effective foreground for existing presets.',
'text_size':'Base label/title size used by the theme.',
'columns':'Grid column count, matrix column-group fields, or table fields, depending on the function.',
'rows':'Grid row span or matrix row-group fields.',
'gap':'Nonnegative space between visual cells.', 'margin':'Nonnegative outer page margin.',
'sidebar_width':'Width of the slicer sidebar in report-canvas units.',
'layout':'A pbi_layout() specification. The default is a two-column grid, except for pbi_screen().',
'size':'A preset page size, or a text size for pbi_text(). Page presets are wide, standard, portrait, a4, and custom.',
'width':'Optional page width or required visual width in report-canvas units.',
'height':'Optional page height or required visual height in report-canvas units.',
'interactions':'native, filter, or none. Controls page-default selection propagation.',
'left':'Distance from the page\'s left edge.', 'top':'Distance from the page\'s top edge.',
'field':'A column name or pbi_field() reference. Slicers and categorical filters require an unaggregated column.',
'exclude':'FALSE includes the supplied values; TRUE excludes them.',
'page':'The page name. Defaults to the last page for binding, all pages for flow inspection, and report scope for filtering.',
'id':'A stable visual ID unique within its page.',
'style':'Slicer presentation: dropdown, list, or between.',
'single':'Whether the slicer permits only a single selection. No initial selection is specified.',
'sync':'Optional synchronization-group name for slicers on different pages using the same column.',
'visual':'An already constructed pbi_visual object, not an R render function.',
'input':'The source visual ID on the chosen page. The source must support selection.',
'outputs':'One or more target visual IDs on the same page.',
'mode':'filter, none, or native, describing the directed visual interaction.',
'include_disabled':'Whether pbi_flow() should include edges with mode = "none".',
'path':'A project directory to create, not a .pbix, .pbip, or .zip filename.',
'bundle':'Whether also to create a ZIP alongside the generated directory.',
'overwrite':'Whether to replace an existing pbiweave-generated directory, preserving its old contents in a sibling backup.',
'model_format':'"tmdl" (default) or "tmsl". Exactly one semantic-model representation is written.',
'project':'A pbi_project object, a generated project directory, or its .pbip entry-point path.',
'verify_hashes':'Whether to compare generated files with build-manifest MD5 hashes. Intended for unedited builds.',
'check_data':'Whether to decode the embedded gzip/JSON snapshots and verify their row and column counts.',
'series':'Optional grouping field used as a legend/series split.',
'horizontal':'TRUE uses horizontal bars; FALSE uses vertical columns.',
'stacked':'Whether additive series are stacked.', 'percent':'Whether to use 100% stacking; implies stacked = TRUE.',
'labels':'Whether native data labels are displayed.',
'tooltip':'Optional field references for the native tooltip role.',
'details':'A field identifying scatter points. Use a unique observation ID for one point per row.',
'category':'The categorical grouping field.', 'group':'Optional treemap detail grouping.',
'breakdown':'Optional secondary grouping for a waterfall.',
'target':'A fixed numeric target or a field/measure reference.',
'minimum':'A fixed numeric minimum or a field/measure reference.',
'maximum':'A fixed numeric maximum or a field/measure reference.',
'bold':'Whether static text is bold.', 'text':'Static text to embed. Newlines create paragraphs.',
}

def get_signature(text, name):
    m = re.search(r'^'+re.escape(name)+r'\s*<-\s*function\s*\(', text, re.M)
    assert m, name
    start=m.end(); depth=1; quote=None; escape=False
    for i in range(start,len(text)):
        ch=text[i]
        if quote:
            if escape: escape=False
            elif ch=='\\': escape=True
            elif ch==quote: quote=None
        else:
            if ch in '\"\'`': quote=ch
            elif ch=='(': depth+=1
            elif ch==')':
                depth-=1
                if depth==0: return text[start:i]
    raise ValueError(name)

def split_args(signature):
    out=[]; start=0; depth=0; quote=None; esc=False
    for i,ch in enumerate(signature):
        if quote:
            if esc: esc=False
            elif ch=='\\': esc=True
            elif ch==quote: quote=None
        else:
            if ch in '\"\'`': quote=ch
            elif ch in '([{': depth+=1
            elif ch in ')]}': depth-=1
            elif ch==',' and depth==0: out.append(signature[start:i].strip()); start=i+1
    out.append(signature[start:].strip())
    return [v.split('=',1)[0].strip() for v in out if v]

def rd(text):
    return text.replace('\\', r'\textbackslash{}').replace('%',r'\%').replace('{',r'\{').replace('}',r'\}')

# Consolidation: these overrides are part of the checked-in documentation
# source of truth. Never regenerate man/ with stale roxygen blocks.
def revise(name, *, title=None, desc=None, details=None, value=None, example=None):
    a=list(DOC[name])
    for i,v in enumerate((title,desc,details,value,example)):
        if v is not None: a[i]=v
    DOC[name]=tuple(a)

revise('pbi_dashboard', example='''d <- pbi_dashboard("Revenue", pbi_demo_data(), table = "Sales") %>%
  pbi_page("Overview", pbi_card("revenue"), pbi_bar("region", "cost"))
pbi_validate(d)$valid''', details=DOC['pbi_dashboard'][2]+' A single table defaults to the name "data", as in 0.1.0. A named list of data frames creates several independent tables; add relationships explicitly. locale controls model culture, not the typed source-data parsing culture.')
revise('pbi_data', details=DOC['pbi_data'][2]+' The canonical positional order is (x, name, data). The reversed 0.2.0 order (x, data, name) is accepted when argument types make it unambiguous. Prefer named arguments in shared code. types, formats, descriptions and sort_by are named column mappings. hidden is normally a vector of column names; table_hidden hides the table. A scalar logical hidden is also accepted as a table-hidden alias. Exact int64 and fixed-decimal strings are normalized before key validation.', example='''sales <- pbi_demo_data()
regions <- data.frame(region = unique(sales$region), area = c("A", "B", "C"))
d <- pbi_dashboard("Regions", sales, table = "Sales") %>%
  pbi_data("Regions", regions) %>%
  pbi_relationship("Sales", "region", "Regions", "region")
length(d$tables)''')
revise('pbi_prepare', example='''sales <- pbi_demo_data()
prepared <- pbi_prepare(sales, function(d) {
  d[, profit_per_unit := (revenue - cost) / units]
  d
})
stopifnot(!"profit_per_unit" %in% names(sales))
head(prepared)''')
revise('pbi_column', details='This modifies column metadata and, when type is supplied, converts a private copy of the stored values using the same strict normalizers as pbi_data(). Invalid integers, currency scales and date strings fail before compilation. Existing relationships and sort mappings are revalidated after the change. Prepare more complex transformations with ordinary R or pbi_prepare(). A display value must map to exactly one sort key; circular sort mappings are rejected. NULL leaves an existing setting unchanged; format = "" explicitly clears a display format. Identifiers normally use summarize = "none". Hidden data remain recoverable from the project.', example='''d <- pbi_dashboard("Typed model", pbi_demo_data()) %>%
  pbi_column("revenue", type = "decimal", format = "$#,0.00") %>%
  pbi_column("product", summarize = "none")
d$tables$data$columns$revenue$format''')
revise('pbi_field', details=DOC['pbi_field'][2]+' aggregate = "none" is an explicit unaggregated request for grouping, detail or tooltip roles, not a valid numeric chart-value aggregation. column is an alias for name; use one, not both.')
revise('pbi_aggregate', example='''d <- pbi_dashboard("Mean transaction", pbi_demo_data()) %>%
  pbi_page("Explore", pbi_bar("region",
    pbi_aggregate("revenue", "average", format = "$#,0.00")))
pbi_validate(d)$valid''')
revise('pbi_relationship', details='from/from_column name the many-side fact key and to/to_column name the one-side dimension key. With single-direction filtering, dimension selections filter fact rows, not the reverse. from_table and to_table are named aliases; direction = "single" or "both" aliases bidirectional. Dimension keys must be unique and nonmissing after typed normalization. Text comparisons fold case and remove trailing ASCII spaces but preserve leading spaces. Other locale-specific equivalences require native review. unmatched defaults to "warn" for original compatibility; choose "error" for strict coverage or "allow" for intentional unknown facts. Active undirected cycles and parallel routes are conservatively rejected by pbi_validate(), even though some more complex native models could resolve them. Make alternative relationships inactive rather than suppressing the diagnostics.')
revise('pbi_calendar', details='The source column must be a Date, not a timestamp. Bounds default to the nonmissing source range. This adds the same rich calendar as pbi_date_table(), including Date, Year, Quarter, Month, MonthName, YearMonth, Day, Weekday (Monday = 1) and WeekdayName, marks Date as the key and adds a many-to-one relationship. Both displayed month and weekday names have sort-by mappings. Bounds excluding fact dates produce unmatched-key diagnostics. For a standalone calendar or deliberate inactive relationship, use pbi_date_table() and pbi_relationship() separately.')
revise('pbi_theme', details='Seven coordinated presets are available: linen, midnight, ocean, forest, ink, accessible and european_commission. The European Commission preset is an original EC-inspired adaptation combining the supplied EC Colour Palette 2024 presentation template with current Europa Component Library surfaces; it is not an official or certified Commission theme. Its categorical colors are #003399, #44BA7E, #FF712C, #48038C, #FFD34E, #DD0C86 and #000083. It uses blue headings (#003399), dark body text (#00002E), a pale page background (#F2F6FF), white visual surfaces (#FFFFFF), muted text (#505070) and a web-blue accent (#0046FF). When font is omitted, this preset selects Arial; the six existing presets retain Segoe UI. An explicitly supplied font always wins. title_color controls headings independently from body text. NULL selects the EC blue for european_commission and otherwise follows the effective foreground, including a foreground override. The complete original theme controls are preserved, including muted/accent colors and separate base/title text sizes. colors needs at least three #RRGGBB values; all individual colors must be scalar. palette aliases colors and text_size aliases font_size, with conflicts rejected. Font families are references, not embedded font files. Verify font availability, contrast, label fit and alternative text in the intended viewing environment. A palette alone does not certify accessibility, and light chart colors need suitable labels and other visual distinctions.')
revise('pbi_layout', details='grid places visuals in declaration order and honors pbi_span(). sidebar preserves the original first-visual-on-the-left behavior by default; sidebar_mode = "slicers" instead places every slicer in the left rail. pbi_screen() uses that second mode. sidebar_width is a fraction from 0.1 to 0.8, or at least 100 canvas pixels. focus enlarges the first visual above the rest, using focus_ratio. free uses pbi_place() coordinates. padding is the page margin; margin is a named alias. header reserves heading space, and header = 0 removes that generated heading. These are fixed canvas layouts, not CSS breakpoints.')
revise('pbi_page', details='Supply complete native visuals directly or in a list. Page names and visual IDs must be unique within their respective scopes. Original presets wide, standard, portrait and a4 are supported, as is a numeric width/height size vector. Named width and height override the preset; "custom" uses wide defaults for unspecified dimensions. Filters supplied here are page-scoped pbi_filter() specifications. Hidden pages are presentation metadata, not security. At least one page must be visible. The default interactions = "default" uses native selection rules; "native" is an alias, "filter" forces filtering and "none" disables cross-visual selections. Report/page filters and model relationships are separate from these interaction settings.')
revise('pbi_place', example='''d <- pbi_dashboard("Custom composition", pbi_demo_data()) %>%
  pbi_page("Overview", pbi_place(pbi_card("revenue"), 24, 90, 280, 160),
           pbi_place(pbi_bar("product", "cost"), 328, 90, 900, 560),
           layout = pbi_layout("free"))
pbi_validate(d)$valid''')
revise('pbi_sort', details=DOC['pbi_sort'][2]+' The third positional argument remains the logical descending flag. Use direction = "descending" for the newer string spelling; do not pass that string positionally. The selected sorting expression must already appear in the visual with the same aggregation.', example='''v <- pbi_bar("product", "revenue") %>%
  pbi_sort("revenue", descending = TRUE)
d <- pbi_dashboard("Ranked products", pbi_demo_data()) %>%
  pbi_page("Rank", v)
pbi_validate(d)$valid''')
revise('pbi_filter', desc='Constructs a reusable typed filter or attaches that filter to a report, page or visual.', details='The original constructor remains pbi_filter(field, values, table, exclude). Its result can be reused with pbi_filters(), pbi_where() or pbi_page(filters = list(...)). The added modifier form is dashboard_or_visual %>% pbi_filter(field, values, ...). For a dashboard, page = NULL means report scope; use a page name or index for page scope. Named x is also accepted. NA represents a native blank, and values are normalized against the model type before compilation. Invalid numeric, integer, date, timestamp and currency values are rejected. These are static query constraints, not row-level security and not R callbacks. Slicers combine with these constraints, so excluded source rows cannot be made available by a slicer. This API implements inclusion/exclusion, not arbitrary DAX, Top N or range expressions.', value='With no dashboard/visual supplied, a reusable pbi_filter object. Otherwise, the modified pbi_dashboard or pbi_visual.', example='''keep_east <- pbi_filter("region", "East")
d <- pbi_dashboard("Scoped filters", pbi_demo_data()) %>%
  pbi_filters(keep_east) %>%
  pbi_page("Overview", pbi_bar("product", "revenue"),
           pbi_card("cost") %>% pbi_filter("product", "Atlas"))
pbi_validate(d)$valid''')
revise('pbi_validate', details='Returns structured diagnostics by default without stopping. Each row has severity, code, location and message. stop_on_error = TRUE raises on errors; strict = TRUE also promotes warnings for that stop decision. Compatibility accessors $valid, $errors and $warnings do not replace the underlying data.table columns. Checks include typed filters, relationship keys and conservative path ambiguity, sort dependencies, grouping/value roles, projected sort expressions, synchronized slicer fields, layout bounds and complexity. DAX grammar, native TMDL deserialization, Power Query execution, Desktop rendering and publication permissions remain native acceptance steps.', value='A pbi_diagnostics data.table with severity, code, location and message. $valid is TRUE when no error rows exist, independently of warnings.', example='''d <- pbi_example("showcase")
check <- pbi_validate(d)
check
check$valid
pbi_inspect(d)$tables''')
revise('pbi_compile', details=DOC['pbi_compile'][2]+' The original positional sequence (x, path, overwrite, bundle, compression, open) is unchanged. Name the newer options, especially model_format. keep_backup = TRUE retains prior output; FALSE discards it after a successful commit. Compression uses genuine gzip framing, not R memCompress() zlib framing. Both project and requested ZIP are prepared before old output is moved. Output is still source definitions plus embedded data, not a headlessly generated PBIX.', value='Invisibly, a pbi_project with original path, pbip, report, model, bundle and diagnostics fields, plus project_file, model_format, backup and bundle_backup.')
revise('pbi_check', details=DOC['pbi_check'][2]+' Both the 0.1.0 pbiweave.json and 0.2.0 pbiweave-manifest.json are accepted. A conflicting pair is rejected. stop_on_error is the preserved second positional argument; name verify_hashes and check_data. Hashes detect changes, not authenticity: anyone able to edit the manifest can replace them. A modified report can be bundled with pbi_bundle() without decoding its intentionally changed queries.', value='Invisibly, a list with valid, files, errors, model_format, embedded_tables_checked, hashes_checked, cache_present, data_loaded (NA), and runtime_checked (FALSE).')
revise('pbi_open', example='''p <- pbi_compile(pbi_example("quickstart"), tempfile("open-"))
if (interactive() && .Platform$OS.type == "windows") {
  pbi_open(p)
} else {
  unlink(p$path, recursive = TRUE)
}
# In Desktop: Home -> Refresh, inspect, then Save As .pbix.''')
revise('pbi_demo_data', details='The original 0.1.0 fixture is intentionally unchanged: 288 synthetic observations cover January 2025 through December 2026, three regions (Central, East, West) and four products (Atlas, Beacon, Cedar, Delta). It contains exactly date, region, product, units, revenue and cost. No random-number generator is used. Compute additional profit, margin or row IDs in R. Unfiltered totals are revenue 929888, cost 576336.64 and units 18368. This is illustrative data, not observed company performance.', value='A fresh six-column, 288-row data.table.', example='''d <- pbi_demo_data()
head(d)
d[, .(revenue = sum(revenue), profit = sum(revenue - cost), units = sum(units))]''')
revise('pbi_example', details=DOC['pbi_example'][2]+' id is the original argument; name is an alias. The first sixteen declarations and their original six-column fixture are retained, with shiny added seventeenth. No data are downloaded by pbi_example().')
revise('pbi_bar', details=DOC['pbi_bar'][2]+' Original horizontal = FALSE remains the default. legend and series are equivalent named spellings. A categorical legend cannot be combined with multiple numeric value fields. alt supplies the accessible description.')
revise('pbi_card', title='Present one or several selection-dependent values', desc='Creates the native modern cardVisual, supporting one or several value fields.', details='Numeric columns default to sums; explicit aggregate references and measures override that. Pass a list of fields for several cards inside one visual, or create individual pbi_card() visuals for separate layout control. Titles are static; numbers are queried under current filters. Empty or zero-denominator measures can display blank. Cards are not selectable binding sources. alt supplies an accessible description.', example='''d <- pbi_dashboard("Summary", pbi_demo_data()) %>%
  pbi_page("KPIs", pbi_card(c("revenue", "cost"), title = "Revenue and cost"))
pbi_validate(d)$valid''')
revise('pbi_scatter', example='''sales <- pbi_demo_data() %>% pbi_prepare(function(d) d[, row_id := seq_len(.N)])
d <- pbi_dashboard("Scatter", sales) %>%
  pbi_page("Compare", pbi_scatter("units", "revenue", size = "cost", details = "row_id",
                                 legend = "region", title = "Monthly observations"))
pbi_validate(d)$valid''', details=DOC['pbi_scatter'][2]+' Preserve the original positional order x, y, size, details, legend. Use named arguments when migrating from 0.2.0, which reordered those meanings.')
revise('pbi_waterfall', example='''changes <- data.frame(step = c("Opening", "Growth", "Churn"),
                      amount = c(100, 25, -10), order = 1:3)
d <- pbi_dashboard("Bridge") %>%
  pbi_data("Changes", changes, sort_by = c(step = "order")) %>%
  pbi_page("Bridge", pbi_waterfall("step", "amount") %>% pbi_sort("step"))
pbi_validate(d)$valid''')
revise('pbi_table', details=DOC['pbi_table'][2]+' columns = NULL automatically selects the visible columns of the chosen table. Hidden columns may still be selected explicitly; hiding is not data security.', example='''d <- pbi_dashboard("Evidence", pbi_demo_data()) %>%
  pbi_page("Details", pbi_table(title = "Visible source columns"))
pbi_validate(d)$valid''')
revise('pbi_text', example='''d <- pbi_dashboard("Explanation", pbi_demo_data()) %>%
  pbi_page("Notes", pbi_text("Select a region. Data are synthetic.",
                           font_size = 15, bold = TRUE, alt = "Report instructions"))
pbi_validate(d)$valid''')
# Restored public functions receive separate, fully documented help topics.
DOC['pbi_bundle']=(
 'Bundle an existing project without recompiling it',
 'Writes a ZIP of the complete project source, including intentional Desktop edits.',
 'Unlike pbi_compile(bundle = TRUE), this does not regenerate the model or report. It accepts an existing project object, folder or PBIP entry point, including legacy manifests. Structural checks are retained, but snapshot decoding and build-hash checks are skipped because intentional edits can invalidate the old manifest. cache.abf and localSettings.json are excluded; editor settings and other source files are retained. Destination paths must be outside the source folder. Symlinks escaping the project are rejected. The ZIP is not a PBIX; recipients must extract it and refresh. The original bundle is replaced transactionally when overwrite = TRUE.',
 'Invisibly, the absolute ZIP filename.',
 '''p <- pbi_compile(pbi_example("quickstart"), tempfile("bundle-"))
z <- pbi_bundle(p)
stopifnot(file.exists(z))
unlink(c(p$path, z), recursive = TRUE)''')
DOC['pbi_date_table']=(
 'Add a standalone, richly described calendar dimension',
 'Creates a contiguous calendar in R from explicit inclusive start and end bounds.',
 'The table contains Date, Year, Quarter, Month, MonthName, YearMonth, Day, Weekday and WeekdayName. Weekday is Monday = 1. Month and weekday labels have sort-by metadata; Date is the model key and the table is marked as a time dimension. This helper deliberately adds no relationship. Relate the correct fact Date column explicitly, or use pbi_calendar() to infer bounds and add that relationship together. Timestamps should first be converted to Date in R at the desired timezone/grain. Date bounds must be valid and ordered; ranges greater than approximately 1000 years are rejected.',
 'The modified dashboard, with a new embedded calendar table.',
 '''d <- pbi_dashboard("Calendar", data.frame(day = as.Date("2025-01-01"), value = 1)) %>%
  pbi_date_table("2025-01-01", "2025-12-31") %>%
  pbi_relationship("data", "day", "Calendar", "Date") %>%
  pbi_page("Months", pbi_bar(pbi_field("MonthName", "Calendar"), "value"))
pbi_validate(d)$valid''')
DOC['pbi_filters']=(
 'Attach reusable filters to the entire report',
 'Adds one or more pbi_filter() specifications to report-level filter context.',
 'Each argument can be a filter or a list of filters. Added constraints combine with existing report, page, visual and slicer filters. A filter is validated against the referenced column type, including blank handling. Qualify dimension columns with table. Report-level constraints are not row-level security: all embedded source values remain accessible to a recipient. Use pbi_page(filters = ...) for page scope and pbi_where() for a visual.',
 'The modified pbi_dashboard specification.',
 '''regions <- pbi_filter("region", c("East", "West"))
d <- pbi_dashboard("Subset", pbi_demo_data()) %>%
  pbi_filters(regions) %>%
  pbi_page("Comparison", pbi_bar("region", "revenue"))
pbi_validate(d)$valid''')
DOC['pbi_where']=(
 'Attach reusable filters to one visual',
 'Adds typed include/exclude filters to a single visual specification.',
 'A visual filter is an additional static constraint, not an R subset operation and not a selection input. Other visuals can still use rows excluded from this visual. Several arguments or a list are supported. A reusable filter can be shared between pbi_where(), pbi_filters() and pbi_page(filters = ...). The pipe form visual %>% pbi_filter(field, values) is an additive convenience alias.',
 'The modified pbi_visual specification.',
 '''v <- pbi_card("revenue") %>% pbi_where(pbi_filter("region", "West"))
d <- pbi_dashboard("Scoped KPI", pbi_demo_data()) %>%
  pbi_page("Compare", v, pbi_card("revenue", title = "All regions"))
pbi_validate(d)$valid''')
DOC['pbi_inspect']=(
 'Inspect snapshot sizes and report complexity',
 'Summarizes data sizes, page geometry, model complexity and preflight diagnostics.',
 'Use this before choosing a data grain or compiling a larger report. tables contains rows, columns and approximate in-memory bytes for each copied data.table; it is not a forecast of VertiPaq or encoded JSON size. pages contains visual counts, layout and page dimensions. Measures and relationships are counts, and diagnostics is the structured pbi_validate() result. Large snapshots and pages with many visuals can produce actionable warnings without invalidating the specification. This does not measure native refresh or interaction latency.',
 'A named list: tables, pages, measures, relationships and diagnostics.',
 '''report <- pbi_example("showcase")
info <- pbi_inspect(report)
info$tables
info$pages
info$diagnostics''')

ARG.update({
'locale':'Model culture such as "en-US". Typed embedded values are parsed using an explicit en-US source culture.',
'colors':'Optional vector of at least three categorical #RRGGBB colors.',
'muted':'Optional scalar #RRGGBB muted-text color.', 'accent':'Optional scalar #RRGGBB highlight color.',
'font_size':'Base font size in points, or the static text size for pbi_text().',
'title_size':'Title font size in points.',
'legend':'Optional unaggregated categorical series field; series is its named alias.',
'alt':'Optional scalar accessibility description stored as native alternative text.',
'single_select':'Restrict a slicer to a single selected value. Does not set an initial selection.',
'color':'Optional scalar #RRGGBB static-text color.',
'min':'Gauge minimum: a fixed finite number or a model field/measure reference.',
'max':'Gauge maximum: a fixed finite number or a model field/measure reference.',
'descending':'Logical original sort flag; TRUE sorts descending. Do not use together with direction.',
'padding':'Outer page margin in canvas pixels. margin is an alias.',
'header':'Height reserved for the generated heading band; zero omits the heading.',
'focus_ratio':'Fraction of the usable focus-layout height devoted to the first visual.',
'sidebar_mode':'"first" preserves the original first-visual rail; "slicers" places all slicers there.',
'filters':'A pbi_filter() object or list of such objects applied to this page.',
'start':'Inclusive first calendar date, as Date or an ISO YYYY-MM-DD string.',
'end':'Inclusive last calendar date, as Date or an ISO YYYY-MM-DD string.',
'strict':'With stop_on_error = TRUE, treat warning diagnostics as failures too.',
'stop_on_error':'Stop when errors are found instead of returning an invalid diagnostics result.',
'compression':'Embed data as genuine gzip-compressed Base64 JSON; FALSE embeds uncompressed Base64 JSON.',
'open':'Open the completed project using pbi_open(); this never automates the Desktop refresh.',
'keep_backup':'Retain the previous project and requested ZIP after a successful overwrite. Defaults TRUE.',
'file':'ZIP filename outside the source project. NULL chooses a sibling .zip.',
'types':'Named per-column semantic type overrides; see pbi_column() for supported types.',
'formats':'Named Power BI display-format strings for columns, such as c(revenue = "$#,0.00").',
'descriptions':'Named explanatory descriptions for individual columns.',
'table_hidden':'Hide this table in the field list; data remain embedded and recoverable.',
'palette':'Named alias for colors; supply at least three #RRGGBB values.',
'unmatched':'Policy for missing or unmatched fact keys: "warn" (original default), "error" or "allow".',
'fun':'Native summary: sum, average, min, max, count of nonblank values, or distinct_count. distinctcount is an alias.',
'interactions':'"default" or "native" uses native rules; "filter" forces filtering; "none" disables same-page cross-visual selections.',
'sidebar_width':'A width fraction in [0.1, 0.8], or at least 100 canvas pixels.',
'bidirectional':'Logical original relationship flag. FALSE propagates dimension filters to facts; TRUE allows both directions.',
'foreground':'Optional scalar #RRGGBB text color.',
'background':'Optional scalar #RRGGBB page background; on pbi_page(), overrides the report theme.',
'from':'Many-side fact table for pbi_relationship(); lower Date bound for pbi_calendar().',
' to':'One-side dimension table or upper calendar Date bound.',
' to_table':'Named alias for the one-side table.',
})
ARG['to']='One-side dimension table for pbi_relationship(); upper Date bound for pbi_calendar().'
ARG['title']='Static human-readable report or visual title. NULL chooses an informative default visual title.'
ARG['hidden']='Column names to hide in pbi_data(); a scalar logical for column/page visibility elsewhere. Hiding is never security.'
ARG['text_size']='Named alias for theme font_size; title_size remains separate.'
ARG['table']='Model table name. NULL normally selects the first table; qualify dimension fields explicitly.'
ARG['id']='Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.'
ARG['size']='Page-size preset or numeric c(width, height). For text, an alias for font_size; for scatter, the bubble field.'

# These small visual examples use only the stable, six-column demo fixture.
for _name in ('pbi_layout', 'pbi_page', 'pbi_span'):
    _parts = list(DOC[_name])
    _parts[4] = _parts[4].replace('"profit"', '"cost"')
    DOC[_name] = tuple(_parts)

source='\n'.join(p.read_text() for p in (ROOT/'R').glob('*.R'))
exports=sorted(re.findall(r'^export\((pbi_[a-z_]+)\)$',(ROOT/'NAMESPACE').read_text(),re.M))
assert set(exports)==set(DOC),(set(exports)-set(DOC),set(DOC)-set(exports))
(ROOT/'man').mkdir(exist_ok=True)
for old in (ROOT/'man').glob('*.Rd'): old.unlink()
for name in exports:
    title,desc,details,value,example=DOC[name]
    sig=get_signature(source,name)
    args=split_args(sig)
    specific={}
    if name=='pbi_layout': specific['type']='Layout type: grid, sidebar, focus or free.'
    if name=='pbi_column': specific['type']='Semantic type: string, int64, double, decimal, boolean, date or dateTime. A supplied type normalizes the copied values and revalidates relationships.'
    if name=='pbi_filter': specific.update(values='Nonempty atomic values, including NA for blank. Values are validated against the column type.', **{'...':'Positional field, values, table, exclude, optionally preceded by a dashboard/visual. Do not supply unknown named arguments.'})
    if name=='pbi_span': specific.update(columns='Positive integer grid-column span.',rows='Positive integer grid-row span.')
    if name=='pbi_table': specific['columns']='NULL selects visible columns; otherwise a character vector or list of column and measure references.'
    if name=='pbi_example': specific['name']='Named alias for id. Use one, not both.'
    if name=='pbi_data': specific['hidden']='Original vector of column names to hide. A logical scalar is accepted as a table_hidden alias.'
    if name=='pbi_relationship': specific.update(from_table='Named alias for from.', to_table='Named alias for to.')
    if name in ('pbi_filters','pbi_where'): specific['...']='One or more reusable pbi_filter() objects, or lists of those objects.'
    if name=='pbi_bundle': specific['overwrite']='Replace an existing ZIP transactionally; does not recompile the project.'
    assert all(a in ARG or a in specific for a in args),(name,args)
    usage=name+'('+sig+')'
    body='\\name{'+name+'}\n\\alias{'+name+'}\n\\title{'+rd(title)+'}\n'
    body+='\\description{'+rd(desc)+'}\n\\usage{\n'+usage.replace('%',r'\%')+'\n}\n'
    if args: body+='\\arguments{\n'+''.join('  \\item{'+a+'}{'+rd(specific.get(a) or ARG[a])+'}\n' for a in args)+'}\n'
    body+='\\details{\n'+rd(details)+'\n}\n\\value{'+rd(value)+'}\n'
    body+='\\seealso{\\code{\\link{pbi_dashboard}}, \\code{\\link{pbi_compile}}, \\code{\\link{pbi_check}}}\n'
    body+='\\examples{\n'+example.replace('%',r'\%')+'\n}\n'
    (ROOT/'man'/f'{name}.Rd').write_text(body)
(ROOT/'man'/'pipe.Rd').write_text(r'''\name{pipe}
\alias{\%>\%}
\title{Pipe a specification into the next construction step}
\description{Reexports the magrittr forward pipe. This is ordinary R execution, not a runtime reactive operator.}
\usage{lhs \%>\% rhs}
\arguments{\item{lhs}{The value passed into the next call.}\item{rhs}{The next function call, using a dot placeholder where needed.}}
\details{Preparation and constructor calls execute when the R script runs. Report-viewer selections are handled later by Power BI, not by this pipe or an R server.}
\value{The result of the right-hand expression.}
\examples{
x <- pbi_dashboard("Piped", pbi_demo_data()) \%>\%
  pbi_page("Summary", pbi_card("revenue"))
pbi_validate(x)$valid
}
''')
(ROOT/'man'/'pbiweave-package.Rd').write_text(r'''\name{pbiweave-package}
\alias{pbiweave}
\alias{pbiweave-package}
\docType{package}
\title{Declarative Power BI reports with portable embedded snapshots}
\description{Prepare data in R and generate native report definitions with a TMDL or TMSL semantic model.}
\details{On FIRST OPEN select Home -> Refresh in Power BI Desktop. Then inspect the report and Save As .pbix to include the loaded data. R performs build-time preparation; the report has native filtering and aggregation, not R callbacks. See the README for both complete flights tutorials and all function examples. Installed guides are in system.file("doc", package = "pbiweave").}
\seealso{\code{\link{pbi_example}}, \code{\link{pbi_compile}}, \code{\link{pbi_input}}}
''')
ref=[f'# pbiweave {VERSION} function reference','','Each of the 49 package functions has an installed help topic with arguments, explanations, return values and an example. `%>%` is reexported from magrittr and has a separate help topic.',
     '**FIRST OPEN: Home ➜ Refresh in Power BI Desktop, inspect, then Save As `.pbix`.**','']
for name in exports:
    title,desc,details,value,example=DOC[name]
    ref += [f'## `{name}()` – {title}','',desc,'','```r',name+'('+get_signature(source,name)+')','```','',details,'',f'**Returns:** {value}','','```r',example,'```','']
ref += ['## `%>%` – build-time piping','','This is magrittr’s ordinary forward pipe, not an R callback inside Power BI.','', '```r','pbi_demo_data() %>% pbi_prepare(identity)','```','']
(ROOT/'REFERENCE.md').write_text('\n'.join(ref))
(ROOT/'tools'/'help-metadata.json').write_text(json.dumps({k:{'title':v[0],'example':v[4]} for k,v in DOC.items()},indent=2))
print(f'Generated {len(exports)} function topics, pipe, package help and REFERENCE.md')
