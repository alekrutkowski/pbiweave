# pbiweave 0.3.1

**Prepare data in R. Declare a report. Compile portable native Power BI source.**

> ## FIRST OPEN: **Home ➜ Refresh** is mandatory
>
> Open the generated `.pbip` in Power BI Desktop, then immediately select **Home ➜ Refresh**. Empty visual containers and “Some of the tables have incomplete or no data” before this first refresh are expected: the source contains the embedded snapshot, but not Power BI's processed data cache. After refreshing, inspect the visuals and interactions, then **File ➜ Save As ➜ `.pbix`**. Save, close, and reopen that file to check it contains the loaded data.
>
> `pbi_check(project)$valid` means structural checks passed. **It does not mean data are loaded, TMDL was accepted by Microsoft's engine, or the report rendered successfully.** The package prints this reminder and writes `FIRST-OPEN.md` into every compiled project.

This release consolidates the supplied 0.1.0 implementation and 0.2.0 additions. It retains **all 40 original exports**, adds the **10 newer exports**, restores the original compatibility and correctness safeguards, and defaults to **TMDL**. Both serializers use one validated model representation. Explicit `model_format = "tmsl"` retains `model.bim` output.

**Acceptance status:** this delivery includes implementation, regression tests and reproducible acceptance tools. Executed static checks and source-provenance checks are listed in [VALIDATION.md](VALIDATION.md). A new R test/check run, Microsoft TOM parse, Power BI refresh/render and publication pass are **not claimed**. Keep your accepted 0.1.0 projects and generate into a new directory until acceptance is complete.

## Windows compilation fix in 0.3.1

If 0.3.0 reported `Project path escapes the project: .gitignore`, upgrade to
0.3.1. The filename `.gitignore` belongs inside each generated project; it
must not be rejected. This was a path-validation bug, **not** a Power BI or
model-data error. Running with `bundle = FALSE` would not have prevented the
error because project verification occurs before ZIP creation. The new path
checker inspects the canonical parent directory, rather than treating
Windows differences in normalized *file* paths as escapes.

Install the 0.3.1 archive from a fresh R session and rerun the same expression
using a new output directory (or `overwrite = TRUE` when explicitly replacing
an existing pbiweave project). The first-open **Home ➜ Refresh** requirement
has not changed.

## Start here

[Beginner flights tutorial](#beginner-tutorial-one-data-frame-to-a-two-page-report) · [Three-data-frame tutorial](#intermediate-tutorial-three-data-frames-and-an-r-preaggregated-model) · [Sixteen original examples](#sixteen-pedagogical-examples) · [Every-function index](#every-public-function) · [Shiny guide](pbiweave-for-shiny-developers.md) · [Reference](REFERENCE.md) · [Migration](MIGRATION.md) · [Consolidation audit map](CONSOLIDATION.md).

## Install

R 4.1 or newer is required. R-side preparation and compilation target Windows and Linux; the Desktop opening/final native file step targets Windows. A WSL2-generated project can be copied to a normal Windows directory.

```r
install.packages(c("data.table", "jsonlite", "base64enc", "magrittr", "digest", "zip"))
install.packages("pbiweave_0.3.1.tar.gz", repos = NULL, type = "source")
library(pbiweave)
library(data.table)
```

For the two full tutorials also install `nycflights13`; `bit64` is optional for its native large-integer vectors. Neither is a runtime dependency of a compiled report. Use the separate-library procedure in [MIGRATION.md](MIGRATION.md) to keep an older installed version unchanged.

## The complete first workflow

```r
library(pbiweave)
library(data.table)

project <- pbi_example("showcase", theme = "midnight") %>%
  pbi_compile("commercial-dashboard-v031", bundle = TRUE)

check <- pbi_check(project, verify_hashes = TRUE)
stopifnot(check$valid)
check[c("model_format", "data_loaded", "runtime_checked")]
# TMDL; unknown loaded state (NA); native runtime not checked (FALSE).

# Opens the .pbip on Windows and prints the required first-refresh instruction.
pbi_open(project)
```

Now **Home ➜ Refresh**, inspect, and save as `.pbix`. Do not send the `.pbip` entry file alone: distribute the **entire project directory**, its ZIP, or the refreshed and saved `.pbix`. The generated source has no external CSV, database credential or R process dependency. It contains the underlying data and must be handled accordingly.

For legacy model output, use a different directory:

```r
legacy <- pbi_example("quickstart") %>%
  pbi_compile("quickstart-tmsl", model_format = "tmsl")
```

A model contains **either** `definition/*.tmdl` and table files **or** `model.bim`, never both. TMDL is a model representation, not a replacement for refresh. Microsoft documents these representations and the optional cache in its [semantic-model project reference](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset). The package produces dashboard-style **reports**, not Power BI Service pinned-tile dashboards; there is no implemented headless `.pbix` or authenticated publication service.

## Which work happens where?

| Build time in R | Viewing time in Power BI |
|---|---|
| Read data.frames; clean values; join tables; derive variables; fit models and predictions; choose aggregation grain. | Apply slicers, cross-filter charts, propagate filters through model relationships. |
| Snapshot data; validate typed columns and keys; generate model, native visual queries, layouts and theme. | Evaluate native aggregations and optional measures against the selected data. |
| Rebuild when data or computations change. | Refresh the embedded snapshot, without rerunning the R preparation. |

There are no R callbacks in the exported report. Precomputing everything for every possible selection is often impractical: retain observation rows or additive sufficient statistics so native summaries remain correct. For example, a filtered average of preaggregated cells requires **sum of values / count of observed values**, not an average of cell averages.

## Beginner tutorial: one data frame to a two-page report

### 1. Start from a rich ordinary data.frame

The source is `nycflights13::flights`, converted explicitly to a base `data.frame`. It has dates, airport and airline codes, scheduled/actual times, delays, distance and duration. The [dataset documentation](https://nycflights13.tidyverse.org/reference/flights.html) defines delay in minutes and distance in miles. Negative delays mean early arrival/departure; `hour` is the **scheduled departure** hour.

The goal is a two-page report with KPIs, a daily series, airline and destination comparisons, a matrix, a detail table, and synchronized airport/carrier/date controls. The full script is also installed as `system.file("examples", "01-flights-beginner.R", package = "pbiweave")`.

```r
install.packages("nycflights13")
```

### 2. Prepare values, then declare the complete report

The code below executes top-to-bottom. `pbi_prepare()` passes a private data.table copy to the ordinary R function; it does not register a reactive expression. The flight identifier prevents identical projected detail rows from being grouped together. The ordered text bands sort sensibly without later DAX calculations.

An unknown arrival outcome stays **NA**, not “on time”. The late-arrival percentage is among **observed arrivals**, not among all scheduled records. The count card deliberately uses a separate `flight_count = 1L` column. The date range control uses a Date, not a formatted date string.

```r
# A complete beginner tutorial. Run from a directory where you can create output.
# install.packages(c("data.table", "nycflights13"))
library(pbiweave)
library(data.table)

# A genuine ordinary data.frame, with 19 source variables.
flights <- as.data.frame(nycflights13::flights)
stopifnot(ncol(flights) == 19L, nrow(flights) == 336776L)

# Every transformation below happens in R, once, before compilation.
# Keep unknown arrival outcomes as NA: they must not count as on-time arrivals.
prepared <- flights %>%
  pbi_prepare(function(d) d %>%
    .[, `:=`(
      flight_id = seq_len(.N),
      flight_date = as.Date(sprintf("%04d-%02d-%02d", year, month, day)),
      flight_count = 1L,
      arrival_observed = as.integer(!is.na(arr_delay)),
      late_15 = fifelse(is.na(arr_delay), NA_real_, as.numeric(arr_delay >= 15)),
      departure_band = fcase(hour < 6, "01 Overnight", hour < 12, "02 Morning",
                             hour < 18, "03 Afternoon", default = "04 Evening"),
      distance_band = fcase(distance < 500, "01 Under 500 miles", distance < 1500,
                            "02 500-1499 miles", default = "03 1500+ miles")
    )] %>%
    .[, .(flight_id, flight_date, month, carrier, origin, dest, departure_band,
           distance_band, distance, air_time, dep_delay, arr_delay,
           flight_count, arrival_observed, late_15)])

# The reference values are computed in R, not copied from an unverified screenshot.
expected <- prepared[, .(
  flights = sum(flight_count),
  observed_arrivals = sum(arrival_observed),
  late_rate = mean(late_15, na.rm = TRUE),
  mean_arrival_delay = mean(arr_delay, na.rm = TRUE)
)]
print(expected)

# Basic aggregation remains native so slicer choices update totals correctly.
# No handwritten DAX is needed for this observation-level model.
dashboard <- pbi_dashboard("NYC flights | 2013", prepared, table = "Flights", theme = "midnight") %>%
  pbi_column("late_15", format = "0.0%") %>%
  pbi_column("arr_delay", format = "0.0") %>%
  pbi_column("flight_id", hidden = TRUE, summarize = "none") %>%
  pbi_page(
    "Overview",
    pbi_slicer("origin", title = "Origin airport", sync = "origin"),
    pbi_slicer("carrier", title = "Carrier", sync = "carrier"),
    pbi_slicer("flight_date", title = "Date range", style = "between", sync = "date"),
    pbi_card("flight_count", title = "Flight records"),
    pbi_card(pbi_aggregate("late_15", "average"), title = "Late arrivals | 15+ minutes"),
    pbi_line("flight_date", "flight_count", title = "Flights per day"),
    pbi_bar("carrier", pbi_aggregate("arr_delay", "average"), title = "Mean arrival delay | minutes"),
    layout = pbi_layout("sidebar", columns = 2, sidebar_mode = "slicers"), interactions = "filter"
  ) %>%
  pbi_page(
    "Explore routes",
    pbi_slicer("origin", title = "Origin airport", sync = "origin"),
    pbi_slicer("carrier", title = "Carrier", sync = "carrier"),
    pbi_slicer("flight_date", title = "Date range", style = "between", sync = "date"),
    pbi_bar("dest", "flight_count", title = "Flight volume by destination"),
    pbi_matrix("departure_band", pbi_aggregate("late_15", "average"),
               columns = "origin", title = "Late-arrival rate by departure period"),
    pbi_bar("distance_band", pbi_aggregate("arr_delay", "average"),
            title = "Mean delay by distance band"),
    pbi_table(c("flight_id", "flight_date", "carrier", "origin", "dest", "dep_delay", "arr_delay"),
              title = "Detail | filter before inspecting"),
    layout = pbi_layout("sidebar", columns = 2, sidebar_mode = "slicers")
  )

pbi_validate(dashboard)
project <- pbi_compile(dashboard, "nyc-flights-beginner", bundle = TRUE)
stopifnot(pbi_check(project)$valid)
# Opening is optional in automated runs. On Windows, uncomment:
# pbi_open(project)
# REQUIRED IN DESKTOP: Home -> Refresh. Then inspect and File -> Save As -> .pbix.
```

### 3. Finish in Desktop and test a known selection

Open `project$pbip` or call `pbi_open(project)`, then **Home ➜ Refresh**. Clear all selections and compare the cards with the printed `expected` values. Select a carrier and origin, compute the same R subset, and compare again:

```r
prepared[carrier == "UA" & origin == "EWR", .(
  flights = sum(flight_count),
  late_rate = mean(late_15, na.rm = TRUE),
  mean_arrival_delay = mean(arr_delay, na.rm = TRUE)
)]
```

Check the synchronized date, carrier and origin choices on both pages. A table visual is not a guaranteed full-data export: filter before inspecting, and remember native data reduction/display limits. Review label fit at your intended screen size, then save and reopen `.pbix`. This example does not require writing DAX, but native summaries still respond to filters. The category/number/date metadata comes from the prepared data and explicit column settings.

### 4. Change the report in R

Change `theme = "midnight"` to `"linen"`, `"ocean"`, `"forest"`, `"ink"` or `"accessible"`; change titles, layout columns or visible fields; or compute another feature before constructing the dashboard. Recompile to a new directory and reopen Desktop. An already open project does not live-reload external edits. No source data have been fetched by the generated report: its refresh rereads the embedded snapshot.

## Intermediate tutorial: three data frames and an R-preaggregated model

### 1. Choose the fact grain and dimension keys

Start with exactly **three data.frames**: flights, airlines and airports. The report will compare airline performance and destinations. The fact grain is date × carrier × origin × destination × scheduled departure period. R produces additive counts and sums at that grain. The dimensions retain readable names and metadata without duplicating those attributes in each fact row.

Airport metadata can be missing for destination codes present in the fact table. The preparation explicitly creates “Unlisted destination” members instead of dropping flights with an inner join. Dimension keys must be unique and nonmissing; every fact key must match. This example asks `pbi_relationship(..., unmatched = "error")` to enforce that contract.

`pbi_ratio()` adds only the small selection-sensitive division needed after R aggregation. An average of unequal-size cell averages would be wrong; `DIVIDE(SUM(numerator), SUM(denominator))` preserves the required weighting. Blank denominators return a native blank rather than a fabricated zero. The full script is installed as `system.file("examples", "02-flights-three-frames.R", package = "pbiweave")`.

### 2. Prepare all three tables and build both pages

```r
# A complete intermediate tutorial: exactly three input data.frames.
# install.packages(c("data.table", "nycflights13"))
library(pbiweave)
library(data.table)

flights <- as.data.frame(nycflights13::flights)
airlines <- as.data.frame(nycflights13::airlines)
airports <- as.data.frame(nycflights13::airports)

# Grain: one row per date x carrier x origin x destination x departure period.
# All cleaning, feature engineering, and preaggregation take place in R.
facts <- flights %>% pbi_prepare(function(d) d %>%
  .[, `:=`(
    flight_date = as.Date(sprintf("%04d-%02d-%02d", year, month, day)),
    departure_band = fcase(hour < 6, "01 Overnight", hour < 12, "02 Morning",
                           hour < 18, "03 Afternoon", default = "04 Evening")
  )] %>%
  .[, .(
    flight_count = .N,
    arrivals_observed = sum(!is.na(arr_delay)),
    late_arrivals = sum(arr_delay >= 15, na.rm = TRUE),
    arrival_delay_sum = sum(arr_delay, na.rm = TRUE),
    distance_sum = sum(distance, na.rm = TRUE)
  ), by = .(flight_date, carrier, origin, dest, departure_band)])

airline_dim <- airlines %>% pbi_prepare(function(d) d[, .(carrier, airline = name)])
airport_dim <- airports %>% pbi_prepare(function(d) d %>%
  .[faa %chin% unique(facts$dest)] %>%
  .[, .(dest = faa, airport = paste0(name, " [", faa, "]"), latitude = lat, longitude = lon, time_zone = tzone)])

# A left-safe dimension: retain every destination key present in the fact table.
# Never silently drop flights because metadata for a destination is absent.
missing_dest <- setdiff(unique(facts$dest), airport_dim$dest)
if (length(missing_dest)) {
  airport_dim <- rbindlist(list(
    airport_dim,
    data.table(dest = missing_dest, airport = paste("Unlisted destination", missing_dest),
               latitude = NA_real_, longitude = NA_real_, time_zone = NA_character_)
  ), use.names = TRUE)
}
stopifnot(!anyDuplicated(airline_dim$carrier), !anyDuplicated(airport_dim$dest),
          all(facts$carrier %chin% airline_dim$carrier), all(facts$dest %chin% airport_dim$dest),
          sum(facts$flight_count) == nrow(flights))

# Ratios need selection-time division of R-computed sufficient statistics.
# mean(cell_means) would be wrong whenever cells have different row counts.
expected <- facts[, .(
  flights = sum(flight_count),
  late_rate = sum(late_arrivals) / sum(arrivals_observed),
  mean_arrival_delay = sum(arrival_delay_sum) / sum(arrivals_observed)
)]
stopifnot(isTRUE(all.equal(expected$late_rate,
                          mean(flights$arr_delay >= 15, na.rm = TRUE))))
print(expected)

dashboard <- pbi_dashboard("Airline and destination performance", facts,
                            table = "Flights", theme = "ocean") %>%
  pbi_data("Airlines", airline_dim, description = "One row per airline code") %>%
  pbi_data("Airports", airport_dim, description = "One row per destination, including unknown metadata") %>%
  pbi_relationship("Flights", "carrier", "Airlines", "carrier", unmatched = "error") %>%
  pbi_relationship("Flights", "dest", "Airports", "dest", unmatched = "error") %>%
  pbi_column("latitude", table = "Airports", data_category = "Latitude", summarize = "none") %>%
  pbi_column("longitude", table = "Airports", data_category = "Longitude", summarize = "none") %>%
  pbi_ratio("Late-arrival rate", "late_arrivals", "arrivals_observed", format = "0.0%") %>%
  pbi_ratio("Mean arrival delay", "arrival_delay_sum", "arrivals_observed", format = "0.0") %>%
  pbi_page(
    "Performance",
    pbi_slicer("airline", table = "Airlines", title = "Airline", sync = "airline"),
    pbi_slicer("airport", table = "Airports", title = "Destination", sync = "airport"),
    pbi_slicer("flight_date", title = "Date range", style = "between", sync = "date"),
    pbi_card("flight_count", title = "Flights"),
    pbi_card(pbi_ref("Late-arrival rate"), title = "Late-arrival rate"),
    pbi_line("flight_date", pbi_ref("Mean arrival delay"), title = "Daily mean arrival delay"),
    pbi_bar(pbi_field("airline", "Airlines"), pbi_ref("Late-arrival rate"),
            title = "Late-arrival rate by airline"),
    layout = pbi_layout("sidebar", sidebar_mode = "slicers"), interactions = "filter"
  ) %>%
  pbi_page(
    "Destinations",
    pbi_slicer("airline", table = "Airlines", title = "Airline", sync = "airline"),
    pbi_slicer("airport", table = "Airports", title = "Destination", sync = "airport"),
    pbi_slicer("flight_date", title = "Date range", style = "between", sync = "date"),
    pbi_bar(pbi_field("airport", "Airports"), "flight_count", title = "Flight volume"),
    pbi_matrix(pbi_field("airline", "Airlines"), pbi_ref("Mean arrival delay"),
               columns = "origin", title = "Average delay by airline and origin"),
    pbi_table(c("flight_date", "origin", "carrier", "dest", "departure_band",
                "flight_count", "arrivals_observed", "late_arrivals"), title = "Auditable R-prepared cells"),
    layout = pbi_layout("sidebar", sidebar_mode = "slicers")
  )

pbi_validate(dashboard)
project <- pbi_compile(dashboard, "nyc-flights-three-frames", bundle = TRUE)
stopifnot(pbi_check(project)$valid)
# pbi_open(project)
# REQUIRED IN DESKTOP: Home -> Refresh, clear slicers, compare expected, Save As .pbix.
```

### 3. Understand the two dependency systems

Selecting `Airlines[airline]` filters the airline dimension. The active many-to-one relationship lets that dimension filter fact rows; the selected count and ratio summaries then update. A visual interaction edge alone is **not a join**. Conversely, a valid relationship does not override a deliberately disabled visual interaction.

This model can filter by the dimensions retained in the fact grain. It cannot later answer arbitrary questions about an omitted tail number or reconstruct a median from sums. Choose the grain for the questions users must answer. Low-cardinality aggregation can reduce the payload; it does not guarantee an unmeasured refresh or interaction latency.

### 4. Verify, save and maintain

Compare the all-data totals with `expected`, then compare a selected carrier/destination/date range with an equivalent R subset of `facts`. Include a destination with missing metadata, cleared selections, and synchronized slicers across pages. Test zero-observation groups rather than treating blank ratios as zero. Finish with **Home ➜ Refresh**, review and **Save As `.pbix`**. Updating a data source means rerunning the R preparation, compiling a new snapshot and performing the native refresh/save/publication workflow again.

## Available building blocks

Native visual families include bar/column, line, area, scatter/bubble, pie, donut, treemap, funnel, waterfall, modern multi-value card, gauge, table, matrix, slicer and static text. Grid spans, first-visual or all-slicer sidebars, focus compositions and free coordinates are supported. Wide, standard, portrait, A4-proportioned and custom canvases are fixed layouts, not automatic mobile reflow.

The six coordinated themes retain separate base/title text sizes, foreground/background/accent/muted controls, categorical colors and explicit visual/table formatting. Alternative text, hidden pages, optional heading bands, per-page backgrounds, typed static filters, synchronized slicers, full calendars and structured diagnostics are retained from 0.1.0.

## Sixteen pedagogical examples

All blocks below run after `library(pbiweave)` and `library(data.table)` and assign a dashboard
specification to `dashboard`. They use synthetic data from `pbi_demo_data()` or
R's built-in `mtcars` data. The synthetic panel has 288 rows, 24 months, three
regions, and four products; generating it does not change R's random seed.

Compile any block with:

```r
project <- pbi_compile(dashboard, tempfile("my-report-"), bundle = TRUE)
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


## R-first metadata and explicitly wired interactions

The seventeenth built-in example adds Shiny-friendly IDs. Its inputs do not expose R `input$id` values: they create native slicers. Its outputs are native visual specifications, not `renderPlot()` callbacks.

```r
wired <- pbi_example("shiny", theme = "midnight")
pbi_flow(wired)
# Inspect the six enabled input-to-output routes.
pbi_flow(wired, include_disabled = TRUE)
```

Here is a small standalone declaration using all five interaction helpers:

```r
wired <- pbi_dashboard("Explicit selections", pbi_demo_data()) %>%
  pbi_screen("Explore",
    pbi_input("region", "region", label = "Region", style = "list"),
    pbi_output("revenue", pbi_card("revenue")),
    pbi_output("trend", pbi_line("date", "revenue"))) %>%
  pbi_bind("region", c("revenue", "trend"))
pbi_flow(wired)
```

`pbi_screen()` starts with disabled cross-visual edges. `pbi_bind()` names the allowed directed selections. An ordinary `pbi_page()` instead retains native interactions by default. The static flow table does not infer DAX dependencies, relationship propagation or synchronized cross-page state. Read the complete [Shiny-developer guide](pbiweave-for-shiny-developers.md), including finite R-precomputed scenarios and safe handling of an initially unselected scenario.

## Additional function examples

These short independent examples complete public-API coverage. Each runs after the two library calls above. The [function reference](REFERENCE.md) and installed `?function_name` help explain arguments, return values and edge cases.

### `pbi_bundle()`

Bundle an existing project without recompiling it.

```r
p <- pbi_compile(pbi_example("quickstart"), tempfile("bundle-"))
z <- pbi_bundle(p)
stopifnot(file.exists(z))
unlink(c(p$path, z), recursive = TRUE)
```

### `pbi_calendar()`

Build a contiguous calendar in R.

```r
d <- pbi_dashboard("Calendar", pbi_demo_data(), table = "Sales") %>%
  pbi_calendar("date", table = "Sales") %>%
  pbi_page("Monthly", pbi_slicer("Year", table = "Calendar"),
           pbi_bar(pbi_field("MonthName", "Calendar"), "revenue"))
pbi_validate(d)$valid
```

### `pbi_inspect()`

Inspect snapshot sizes and report complexity.

```r
report <- pbi_example("showcase")
info <- pbi_inspect(report)
info$tables
info$pages
info$diagnostics
```

### `pbi_pie()`

Show a small categorical composition.

```r
v <- pbi_pie("region", "revenue", title = "Revenue by region")
d <- pbi_dashboard("Visual example", pbi_demo_data()) %>%
  pbi_page("Example", v)
pbi_validate(d)$valid
```

## Diagnostics and safe project management

```r
spec <- pbi_example("showcase")
diagnostics <- pbi_validate(spec, stop_on_error = FALSE)
diagnostics                    # original structured diagnostic data.table
stopifnot(diagnostics$valid)    # convenience accessor, not a real table column
pbi_inspect(spec)$tables
pbi_inspect(spec)$pages

p <- pbi_compile(spec, tempfile("review-"), bundle = TRUE)
pbi_check(p, verify_hashes = TRUE, check_data = TRUE)
# Check an intentionally Desktop-edited project without assuming the old query payload:
pbi_check(p, check_data = FALSE)
# Bundle an existing source project without recompiling it:
archive <- pbi_bundle(p, file = tempfile(fileext = ".zip"))
```

New builds stage all project files and a requested ZIP before replacing existing generated output. `overwrite = TRUE` retains sibling backups by default; `keep_backup = FALSE` intentionally discards them after a successful commit. Never overwrite an open Desktop project or treat a snapshot archive as a backup of unsaved edits. Compilation rejects symlink destinations and unowned nonempty folders. Avoid concurrent writes to the same destination.

`pbi_check()` understands both historical manifest filenames and both model formats. Hashes detect divergence from the build, not malicious edits to the manifest itself. The generated TMDL inventory is not a general Microsoft TMDL parser. A Desktop-edited model may legitimately require `check_data = FALSE` and native validation; arbitrarily split TMDL declarations require the native TOM parser rather than the lightweight inventory checker.

## Every public function

The table below lists all **50 exports**, including `%>%`. Every function has a call in a README R example and an installed help example; the static checker and R coverage test enforce that requirement. The `REFERENCE.md` entries contain the complete signatures.

| Function | Purpose |
|---|---|
| [`pbi_aggregate()`](REFERENCE.md) | Choose the selection-time summary for a column |
| [`pbi_area()`](REFERENCE.md) | Show a filled trend |
| [`pbi_bar()`](REFERENCE.md) | Compare categories with a bar or column chart |
| [`pbi_bind()`](REFERENCE.md) | Declare which visual selections affect which outputs |
| [`pbi_bundle()`](REFERENCE.md) | Bundle an existing project without recompiling it |
| [`pbi_calendar()`](REFERENCE.md) | Build a contiguous calendar in R |
| [`pbi_card()`](REFERENCE.md) | Present one or several selection-dependent values |
| [`pbi_check()`](REFERENCE.md) | Inspect a generated project without claiming it is refreshed |
| [`pbi_column()`](REFERENCE.md) | Describe a column for the semantic model |
| [`pbi_compile()`](REFERENCE.md) | Compile a portable project using TMDL by default |
| [`pbi_dashboard()`](REFERENCE.md) | Start a declarative report specification |
| [`pbi_data()`](REFERENCE.md) | Embed another data frame in the model |
| [`pbi_date_table()`](REFERENCE.md) | Add a standalone, richly described calendar dimension |
| [`pbi_demo_data()`](REFERENCE.md) | Create deterministic demonstration data without changing the RNG |
| [`pbi_donut()`](REFERENCE.md) | Show a compact part-to-whole composition |
| [`pbi_example()`](REFERENCE.md) | Construct one of the teaching report specifications |
| [`pbi_field()`](REFERENCE.md) | Refer to a model column without writing DAX |
| [`pbi_filter()`](REFERENCE.md) | Apply a static include or exclude filter at a chosen scope |
| [`pbi_filters()`](REFERENCE.md) | Attach reusable filters to the entire report |
| [`pbi_flow()`](REFERENCE.md) | Inspect declared visual-interaction dependencies |
| [`pbi_funnel()`](REFERENCE.md) | Display ordered stages or ranked categories |
| [`pbi_gauge()`](REFERENCE.md) | Compare a value with a target and bounded scale |
| [`pbi_input()`](REFERENCE.md) | Declare a Shiny-style input ID backed by a native slicer |
| [`pbi_inspect()`](REFERENCE.md) | Inspect snapshot sizes and report complexity |
| [`pbi_layout()`](REFERENCE.md) | Declare how visuals occupy a fixed report canvas |
| [`pbi_line()`](REFERENCE.md) | Show a trend or ordered comparison |
| [`pbi_matrix()`](REFERENCE.md) | Cross-tabulate values by row and column groups |
| [`pbi_measure()`](REFERENCE.md) | Define an optional DAX measure |
| [`pbi_open()`](REFERENCE.md) | Open the project and print the mandatory first-refresh instructions |
| [`pbi_output()`](REFERENCE.md) | Give a native visual a stable output ID |
| [`pbi_page()`](REFERENCE.md) | Add a page of native visuals |
| [`pbi_pie()`](REFERENCE.md) | Show a small categorical composition |
| [`pbi_place()`](REFERENCE.md) | Place a visual precisely on a free-layout page |
| [`pbi_prepare()`](REFERENCE.md) | Run a build-time R transformation on a private copy |
| [`pbi_ratio()`](REFERENCE.md) | Combine R-precomputed sufficient statistics correctly |
| [`pbi_ref()`](REFERENCE.md) | Refer to an explicitly defined model measure |
| [`pbi_relationship()`](REFERENCE.md) | Connect a fact table to a unique dimension key |
| [`pbi_scatter()`](REFERENCE.md) | Compare observations or aggregates in two dimensions |
| [`pbi_screen()`](REFERENCE.md) | Add an explicitly wired, Shiny-style screen |
| [`pbi_slicer()`](REFERENCE.md) | Add a viewer-operated filter |
| [`pbi_sort()`](REFERENCE.md) | Set a visual query's sort order |
| [`pbi_span()`](REFERENCE.md) | Give a visual more grid cells |
| [`pbi_table()`](REFERENCE.md) | Show unaggregated detail fields or explicit summaries |
| [`pbi_text()`](REFERENCE.md) | Add static explanatory text |
| [`pbi_theme()`](REFERENCE.md) | Choose coordinated colors and typography |
| [`pbi_treemap()`](REFERENCE.md) | Show a hierarchical area composition |
| [`pbi_validate()`](REFERENCE.md) | Preflight a report specification before writing files |
| [`pbi_waterfall()`](REFERENCE.md) | Explain additive contributions to a total |
| [`pbi_where()`](REFERENCE.md) | Attach reusable filters to one visual |
| `%>%` | Magrittr forward pipe, used throughout the declarations. |

## Limits and correctness decisions

Typed values are validated before compilation. Large Int64 values use exact character or `bit64::integer64` input; fixed decimals reject excess scale or range rather than silently rounding. Filter literals respect column types and accept `NA` for native blanks. Dimension keys are checked for case/trailing-space collisions while preserving leading spaces, and active graph checks conservatively reject cycles or parallel paths. Locale-specific collation still needs native-engine acceptance.

A text tooltip is a text grouping field, not an implicit count. Explicit `pbi_field("numeric_id", aggregate = "none")` preserves a numeric identifier as a grouping field. Native tables group identical projected combinations, so include an ID to distinguish source records. Exact query-reference disambiguation avoids collisions from dots and other punctuation in object names.

Arbitrary DAX is accepted but not evaluated in R. This package does not implement R visual callbacks, custom `.pbiviz` loading, maps, bookmarks, drillthrough, conditional formatting, RLS administration, DirectQuery/Direct Lake, mobile-layout authoring, credentials or Service publishing. Hidden fields, disabled interactions and static filters are **not security**; every embedded row can travel with the project. Remove sensitive data before compilation.

The build temporarily holds the R snapshot, JSON and encoded data. Choose a suitable grain for memory and import performance; no benchmark from 0.1.0 is reused as a claim about 0.3.1. Font family names are references to installed fonts, not embedded font files. “Accessible” is a theme preset, not an accessibility certification; inspect contrast, alternative text, reading order and keyboard behavior in the target viewer.

## Development and acceptance

```sh
# From the extracted source repository, with dependencies installed:
python tools/check-static.py
python tools/test_static.py
R CMD build .
R CMD check --no-manual pbiweave_0.3.1.tar.gz
R CMD INSTALL pbiweave_0.3.1.tar.gz
Rscript tools/run-acceptance.R --flights
python tools/validate_project.py build/examples build/tutorials --json
```

The runner compiles all 17 built-in examples in both formats, runs installed help examples, verifies exported-function coverage, and optionally runs both flight tutorials. CI supplies Windows/Ubuntu package checks plus offline schema validation. `tools/validate-tmdl.ps1` can invoke an explicitly supplied trusted Microsoft TOM assembly and compare TMDL with the same model compiled to TMSL. Passing that parse/metadata comparison still does not run M, DAX or the Desktop renderer.

For the showcase, the all-data expected totals are revenue **929,888.00**, cost **576,336.64**, gross profit **353,551.36**, units **18,368**, and gross margin approximately **38.020854%**. The original deterministic fixture is unchanged. Test totals and selections after refresh and save/reopen before publication. [VALIDATION.md](VALIDATION.md) separates completed source checks from these native acceptance gates.

## Format and dependency references

[Microsoft project format](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview), [semantic model and cache](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset), [TMDL grammar and native serializer](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview), [PBIR report definitions](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report), [native data types](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-data-types), [relationships](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-relationships-understand), [nycflights13 datasets](https://nycflights13.tidyverse.org/reference/flights.html), [Shiny reactive elements](https://shiny.posit.co/r/getstarted/build-an-app/reactivity-essentials/reactive-elements.html).

The exact pinned schema/profile is in [inst/COMPATIBILITY.md](inst/COMPATIBILITY.md). Dependency and schema attribution is in [inst/ACKNOWLEDGEMENTS.md](inst/ACKNOWLEDGEMENTS.md); the bundled Microsoft schemas retain their license. The compiler never silently adopts a newly downloaded schema during a user build.

## License

MIT. **Alek Rutkowski**, <alek.rutkowski@gmail.com>. Dependencies and bundled third-party schemas retain their own licenses. See `LICENSE.md` and the acknowledgements.
