# pbiweave for Shiny developers

## First, a different execution model

A Shiny application runs R while a user interacts with it. A pbiweave report does **not**. Your R code runs when you build the project; the resulting Power BI artifact contains tables, model definitions, report definitions, and native visual interactions. It contains no Shiny session and no R callback registry.

**First opening still requires Home ➜ Refresh in Power BI Desktop.** This processes the embedded snapshot. It does not execute your R preparation again. Save the refreshed report as `.pbix` after checking its results.

For the Shiny side of the comparison, see Posit's explanations of [reactive elements](https://shiny.posit.co/r/getstarted/build-an-app/reactivity-essentials/reactive-elements.html) and [reactive expressions and observers](https://shiny.posit.co/r/getstarted/build-an-app/reactivity-essentials/reactives-observers.html). For Power BI model structure and its optional data cache, see [Microsoft's project documentation](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset).

## The familiar names and the crucial differences

| Shiny concept | Closest pbiweave concept | Important difference |
|---|---|---|
| Data loading and preprocessing | Ordinary R code, optionally `pbi_prepare()` | Runs once at build time, not per session or selection. |
| `selectInput()` / a date control | `pbi_input()` or `pbi_slicer()` | Declares a native field-bound Power BI slicer; there is no R `input$id` value. |
| An output placeholder with an ID | `pbi_output(id, visual)` | Assigns an ID to a complete native visual specification. |
| Page UI | `pbi_screen()` or `pbi_page()` | A fixed report canvas, not HTML/CSS or a browser-responsive layout. |
| A dependency from input to output | `pbi_bind()` plus model relationships | A native cross-visual filter edge, not an R expression dependency. |
| `renderPlot()` / `renderTable()` | `pbi_bar()`, `pbi_line()`, `pbi_table()`, etc. | Declares a native Power BI visual, not an R plotting function. |
| Reactive calculated result | Native grouping/aggregation or a DAX measure | Evaluated by the Power BI engine in filter context; it cannot call R. |
| Reactive graph inspection | `pbi_flow()` | Inspects declared same-page visual edges, not a live invalidation graph. |
| `observeEvent()` and side effects | No equivalent | There is no button-triggered R job, file write, API call, or observer. |
| `reactiveValues()` / session state | No general equivalent | The package does not expose arbitrary per-viewer application state. |

The helpers are intentionally small. Familiar terminology should make layout and dependencies easier to read without pretending to reproduce Shiny's runtime.

## A complete explicitly bound report

This example prepares the data in R, gives controls and outputs stable IDs, and allows one region control to filter two outputs but not a reference KPI.

```r
library(pbiweave)
library(data.table)

sales <- pbi_demo_data() %>%
  pbi_prepare(function(d) d %>%
    .[, profit := revenue - cost] %>%
    .[, profit_per_unit := profit / units])

app <- pbi_dashboard("Regional exploration", sales, table = "Sales", theme = "midnight") %>%
  pbi_ratio("Gross margin", "profit", "revenue", format = "0.0%") %>%
  pbi_screen(
    "Explore",
    pbi_input("region", "region", label = "Region", style = "list"),
    pbi_output("revenue", pbi_card("revenue", title = "Revenue | selected region")),
    pbi_output("trend", pbi_line("date", "revenue", title = "Revenue over time")),
    pbi_output("margin", pbi_card(pbi_ref("Gross margin"), title = "All-region margin")),
    layout = pbi_layout("sidebar"),
    interactions = "none"
  ) %>%
  pbi_bind("region", c("revenue", "trend"))

pbi_flow(app)
# Two enabled edges: region -> revenue and region -> trend.
pbi_flow(app, include_disabled = TRUE)
# Also shows explicitly disabled/default-disabled visual pairs.

pbi_validate(app)
project <- pbi_compile(app, "shiny-style-report", bundle = TRUE)
stopifnot(pbi_check(project)$valid)
if (interactive()) pbi_open(project)
# In Desktop: Home -> Refresh; inspect; Save As .pbix.
```

`pbi_screen()` defaults to `interactions = "none"`. This matters: absent bindings do not accidentally inherit a page-wide filter relationship. By contrast, `pbi_page()` defaults to native interactions. An ordinary slicer on a native page normally participates in Power BI's interactions without calling `pbi_bind()` at all.

The reference margin is protected only against the region visual's selection in this example. Report filters, page filters, other enabled slicers, and model-level context can still affect it. A truly filter-independent benchmark needs deliberately defined measure logic; “unbound” is not synonymous with “ignores every filter.”

## Follow the input → output path

For the revenue card above, the flow is:

```text
BUILD TIME, IN R
raw observations
  -> pbi_prepare(): calculate profit_per_unit, once
  -> pbi_dashboard(): copy the prepared table
  -> pbi_compile(): embed rows and declare native visuals and edges

VIEWING TIME, IN POWER BI
region slicer selection
  -> enabled visual interaction edge
  -> filter context on Sales[region]
  -> native SUM of the visible Sales[revenue] values
  -> updated revenue card
```

Nothing travels back to `pbi_prepare()`. The R process may be closed. There is no dynamically discovered R dependency from reading `input$region`; the relevant dependence is already represented by a field binding and interaction metadata.

In Shiny, a reactive expression can read inputs and other reactive values while it runs, and invalidation follows those recorded dependencies. Here there are two distinct graphs you must reason about: the **visual interaction graph** and the **semantic-model relationship graph**. `pbi_flow()` reports the former only. It does not prove that a relationship path exists, trace DAX dependencies, inspect server requests, or report evaluation timings.

### Dependency changes are specification changes

To allow the region input to affect margin as well, change the specification before compiling:

```r
app <- app %>% pbi_bind("region", "margin")
pbi_flow(app)
```

To disable it again:

```r
app <- app %>% pbi_bind("region", "margin", mode = "none")
```

The last binding for a source-target pair wins. `mode = "native"` emits the native `Default` interaction for that pair and lets native interaction rules decide. Bindings are page-local: supply `page = "Explore"` when editing a page other than the most recently added one.

An interactive chart can also be a source. A card, gauge, or text box cannot. A text box is never a reactive target: `pbi_bind()` rejects a target created by `pbi_text()` rather than silently promising dynamic text.

## Relationships determine whether filters reach data

A slicer can be visually bound to a chart yet still not filter its facts if it selects a disconnected table. Here is a minimal two-table example:

```r
sales <- pbi_demo_data()
products <- unique(sales[, .(product)])[, category := c("Core", "Core", "Premium", "Premium")]

linked <- pbi_dashboard("Products", sales, table = "Sales") %>%
  pbi_data(products, "Products") %>%
  pbi_relationship("Sales", "product", "Products", "product") %>%
  pbi_screen("Compare",
    pbi_input("category", "category", table = "Products", label = "Product category"),
    pbi_output("sales", pbi_bar("product", "revenue"))) %>%
  pbi_bind("category", "sales")
```

The declared relationship runs from the many-side fact key to the one-side dimension key. Its default **filter propagation** is from the dimension to the facts. These are different meanings of “direction”; mixing them up is a common source of confusion. Prefer single-direction relationships unless there is a specific need for bidirectional propagation. Invalid duplicate dimension keys are rejected early, but the compiler conservatively rejects active cycles and parallel paths; locale-specific key equivalence and native behavior still require engine acceptance.

For Microsoft guidance on relationships and filter propagation, see [model relationships](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-relationships-understand).

## Move expensive work to the build, not to a simulated reactive function

Good candidates for R preparation include joins, category labels, binning, explicit missingness indicators, model fitting, predictions, text cleaning, and row-level derived values. A helper such as `pbi_prepare()` is useful for readable pipelines and reference safety, not required for those operations.

```r
prepared <- pbi_demo_data() %>%
  pbi_prepare(function(d) d %>%
    .[, `:=`(
      profit_per_unit = (revenue - cost) / units,
      year = as.integer(format(date, "%Y")),
      size_band = fifelse(units >= 60, "Larger orders", "Smaller orders")
    )])
```

Do not pass `shiny::reactive()` to this interface. Its contract is an ordinary function called immediately with a private copy and returning a data.frame/data.table. Any external work done inside that function happens during the R build, not when a report is viewed.

### Preaggregation changes which questions can still be asked

```r
cells <- pbi_demo_data() %>%
  pbi_prepare(function(d) d[, .(
    revenue_sum = sum(revenue),
    profit_sum = sum(revenue - cost),
    units_sum = sum(units),
    observation_count = .N
  ), by = .(date, region, product)])

summary_report <- pbi_dashboard("Prepared cells", cells, table = "Cells") %>%
  pbi_ratio("Margin", "profit_sum", "revenue_sum") %>%
  pbi_ratio("Revenue per observation", "revenue_sum", "observation_count", format = "$#,0.00") %>%
  pbi_page("Overview", pbi_slicer("region"), pbi_card(pbi_ref("Margin")),
    pbi_line("date", pbi_ref("Revenue per observation")))
```

The report can filter by date, region, and product because those dimensions survive. It cannot filter by units-per-source-record: that observation-level variable was replaced by a cell sum. A variable absent from the source, such as channel in this demo, also cannot become an input. `pbi_ratio()` divides filtered sums rather than averaging percentages or cell means. That small amount of selection-time DAX is necessary unless you retain raw observations or precompute every allowed selection result.

Nonadditive statistics need more care. A median of medians, sum of distinct counts, or mean of fitted coefficients generally does not reproduce a statistic computed on the combined observations. There is no generic aggregation trick that makes arbitrary R analyses reactive after discarding their inputs.

## Offer finite scenarios prepared in R

You can provide useful “what-if” exploration without an R runtime when the offered choices are finite. Precompute a scenario grid, embed the results, and let the viewer select a scenario. This is not an arbitrary continuous numeric input that reruns a model.

```r
sales <- pbi_demo_data()
scenarios <- data.table(
  scenario = c("Base", "Revenue -10%", "Revenue +10%"),
  multiplier = c(1, 0.9, 1.1)
)

scenario_rows <- lapply(seq_len(nrow(scenarios)), function(i) {
  copy(sales)[, `:=`(
    scenario = scenarios$scenario[[i]],
    scenario_revenue = revenue * scenarios$multiplier[[i]],
    scenario_profit = revenue * scenarios$multiplier[[i]] - cost
  )]
}) %>% rbindlist()

scenario_report <- pbi_dashboard("Prepared scenarios", scenario_rows, table = "Scenarios") %>%
  pbi_screen("Compare",
    pbi_input("scenario", "scenario", label = "Scenario", single = TRUE),
    pbi_output("trend", pbi_line("date", "scenario_revenue", series = "scenario")),
    pbi_output("profit", pbi_bar("region", "scenario_profit", series = "scenario")),
    pbi_output("note", pbi_text("Choose a scenario. No R model is fitted at viewing time."))) %>%
  pbi_bind("scenario", c("trend", "profit"))
```

Why retain `series = "scenario"`? The native slicer may begin without a selection, or a user may clear it. Showing separate series prevents accidentally summing duplicated scenario universes into one misleading KPI. `single = TRUE` configures a single-selection control; it is not a general default-value API and does not guarantee that a selection can never be cleared. A production scenario dashboard should explicitly test initial and cleared states.

For an arbitrary continuous slider driving an R fit, a Shiny application remains the appropriate implementation. This package does not conceal that distinction behind similar function names.

## Multiple pages, synchronization, and reusable components

`sync` coordinates slicers of the same field across pages. It is separate from a page-local `pbi_bind()` edge, and it is not included as a cross-page dependency in `pbi_flow()`. Use the same sync group only for the same table and column; preflight validation rejects conflicting fields.

```r
pages <- pbi_dashboard("Two pages", pbi_demo_data()) %>%
  pbi_page("Revenue", pbi_slicer("region", sync = "region"),
    pbi_bar("product", "revenue")) %>%
  pbi_page("Costs", pbi_slicer("region", sync = "region"),
    pbi_bar("product", "cost"))
```

You can use ordinary R functions as reusable specification builders, much as you use UI modules. They are not Shiny modules and have no session namespace: explicitly prefix IDs when combining components on one page.

```r
kpi_pair <- function(prefix) list(
  pbi_output(paste0(prefix, "_revenue"), pbi_card("revenue", title = "Revenue")),
  pbi_output(paste0(prefix, "_profit"), pbi_card("profit", title = "Profit"))
)

component_report <- pbi_dashboard("Reusable components", pbi_demo_data() %>%
  pbi_prepare(function(d) d[, profit := revenue - cost])) %>%
  pbi_page("Overview", kpi_pair("commercial"), layout = pbi_layout("grid"))
```

`pbi_page()` accepts a list of visuals as its single variadic argument. To combine several lists and individual visuals, concatenate them into one visual list with `c()` before passing it. This avoids assuming arbitrary recursive UI-list flattening.

## A practical debugging order

Start with the R snapshot and compute the expected result for one known selection. Then inspect the model keys and their types, the chosen visual field and aggregation, and the page's interaction mode. Use `pbi_flow(..., include_disabled = TRUE)` to distinguish an absent edge from a default-native one. After compilation, `pbi_check()` detects structural and payload inconsistencies but does not evaluate the model.

Finally open the report, **Home ➜ Refresh**, and compare the selected result with R. Test the cleared state, a single selection, multiple selections where allowed, missing categories, and a zero-denominator ratio. Validate both pages when using synced slicers. Save, close, and reopen the `.pbix` before handing it to someone else. These are native acceptance steps, not tests claimed to have run for this release.

Power BI Desktop must be reopened after external file changes; an already open report does not live-reload generated definitions. Build to a new directory when iterating so the native cache and manual edits do not hide what the compiler produced. See [external TMDL changes](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset#make-external-changes-to-tmdl-files).

## Security and deployment are not UI dependencies

A hidden field or disabled input-output edge is not authorization. Report-level filters are not row-level security. Any row embedded in the project travels with the project. Remove sensitive data in R before compiling, and use appropriate platform security for deployed content. This package does not administer workspace permissions or RLS.

A report refresh reloads its fixed embedded payload. It does not contact your R process, update a reactive value, retrain a model, or discover new source observations. For new data, run the R build again and perform the normal native refresh/save/publication steps. The final `.pbix` conversion and rendering acceptance are Desktop tasks; the source archive does not bundle a proprietary Power BI runtime.

## When to choose which tool

Choose pbiweave for declarative, reproducible native Power BI presentation over an R-prepared snapshot, with native filtering and small selection-sensitive aggregations. Choose Shiny when each interaction must execute arbitrary R, trigger side effects, expose custom inputs, manage application state, or dynamically create computations. They can complement each other, but neither is a drop-in runtime replacement for the other.
