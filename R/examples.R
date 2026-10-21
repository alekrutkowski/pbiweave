# Deterministic example sales data
#
# A synthetic monthly sales panel covering January 2025 through December 2026,
# with three regions and four products. No random-number generator is used.
# @return A fresh data.table with 288 rows and date, region, product, units,
#   revenue, and cost columns. Monetary values are illustrative, not observations.
# @export
# @examples
# pbi_demo_data() %>% .[region == "West"]
pbi_demo_data <- function() {
  data.table::CJ(date = seq.Date(as.Date("2025-01-01"), by = "month", length.out = 24L),
                region = c("Central", "East", "West"),
                product = c("Atlas", "Beacon", "Cedar", "Delta")) %>%
    .[, units := as.integer(25L + (seq_len(.N) * 7L + as.integer(format(date, "%m")) * 3L) %% 80L)] %>%
    .[, revenue := as.numeric(units * c(24, 39, 57, 82)[match(product, c("Atlas", "Beacon", "Cedar", "Delta"))])] %>%
    .[, cost := round(revenue * (0.52 + c(0.04, 0.10, 0.16)[match(region, c("Central", "East", "West"))]), 2)] %>%
    .[]
}

# Ready-to-compile pedagogical reports
#
# Seventeen complete examples complement the README. They return specifications and
# perform no file writes. The default showcase has three pages.
# @param id Example name, or an integer from 1 to 17. Names in order are
#   quickstart, typed, themes, grid, sidebar, focus, free, measures, star, time,
#   filters, scatter, tables, gallery, types, showcase, and shiny.
# @param theme Optional theme preset or pbi_theme object overriding the example.
# @return A pbi_dashboard specification.
# @export
# @examples
# pbi_example("quickstart")
# pbi_example("showcase", theme = "midnight")
pbi_example <- function(id = "showcase", theme = NULL, name = NULL) {
  if (!is.null(name)) {
    if (!missing(id)) abort("Use id or name, not both.")
    id <- name
  }
  ids <- names(.pbi_examples)
  if (is.numeric(id)) {
    number(id, "id", 1L, length(ids), whole = TRUE)
    id <- ids[[as.integer(id)]]
  }
  scalar_string(id, "id")
  if (!id %in% ids) abort("Unknown example. Choose: ", paste(ids, collapse = ", "), ".")
  out <- .pbi_examples[[id]]()
  if (!is.null(theme)) {
    if (is.character(theme)) theme <- pbi_theme(theme)
    if (!inherits(theme, "pbi_theme")) abort("theme must be a preset name or pbi_theme.")
    out$theme <- theme
  }
  out
}

.pbi_examples <- list(
  quickstart = function() {
    pbi_dashboard("Sales overview", pbi_demo_data(), table = "Sales") %>%
      pbi_page("Overview",
        pbi_card("revenue", title = "Sales revenue"),
        pbi_bar("region", "revenue", horizontal = TRUE, title = "Revenue by region"),
        pbi_line("date", "revenue", title = "Monthly revenue"),
        pbi_slicer("product", title = "Choose products"))
  },
  typed = function() {
    visits <- data.table::data.table(
      day = as.Date("2026-01-01") + 0:3,
      visitors = c(120L, 145L, 132L, 158L),
      conversion = c(0.12, 0.14, 0.11, 0.16),
      budget = c("350.2500", "400.5000", "375.0000", "450.7500"),
      campaign = c(TRUE, TRUE, FALSE, TRUE))
    pbi_dashboard("Typed data") %>%
      pbi_data("Visits", visits, types = c(budget = "decimal"),
        formats = c(conversion = "0.0%", budget = "$#,0.00"),
        descriptions = c(conversion = "Completed visits divided by all visits")) %>%
      pbi_page("Daily activity",
        pbi_line("day", "visitors", title = "Visitors per day"),
        pbi_table(c("day", "visitors", "conversion", "budget", "campaign"),
          title = "Explicit types and formatting"))
  },
  themes = function() {
    pbi_dashboard("A consistent visual language", pbi_demo_data(), theme = "ocean") %>%
      pbi_page("Theme sampler",
        pbi_bar("product", "revenue", title = "Revenue by product", labels = TRUE),
        pbi_donut("region", "revenue", title = "Regional mix"),
        pbi_line("date", "revenue", legend = "region", title = "Regional trends"),
        pbi_card("units", title = "Units sold"))
  },
  grid = function() {
    pbi_dashboard("A structured grid", pbi_demo_data()) %>%
      pbi_page("Summary",
        pbi_card("revenue", title = "Revenue"),
        pbi_card("cost", title = "Cost"),
        pbi_card("units", title = "Units"),
        pbi_line("date", "revenue", title = "A chart spanning two columns") %>%
          pbi_span(columns = 2),
        pbi_bar("region", "revenue", title = "Regional revenue"),
        layout = pbi_layout("grid", columns = 3, gap = 18))
  },
  sidebar = function() {
    pbi_dashboard("Explore with a sidebar", pbi_demo_data(), theme = "forest") %>%
      pbi_page("Explore",
        pbi_slicer("region", style = "list", title = "Choose a region"),
        pbi_line("date", "revenue", title = "Revenue over time"),
        pbi_bar("product", "revenue", title = "Product sales"),
        pbi_card("units", title = "Units in selection"),
        layout = pbi_layout("sidebar", sidebar_width = 0.23),
        interactions = "filter")
  },
  focus = function() {
    pbi_dashboard("One central story", pbi_demo_data(), theme = "ink") %>%
      pbi_page("Trend in focus",
        pbi_line("date", "revenue", legend = "region", title = "The main comparison"),
        pbi_card("revenue", title = "Total revenue"),
        pbi_donut("product", "revenue", title = "Product contribution"),
        pbi_slicer("region", title = "Select regions"),
        layout = pbi_layout("focus", columns = 3, focus_ratio = 0.65))
  },
  free = function() {
    pbi_dashboard("An exact canvas", pbi_demo_data(), theme = "linen") %>%
      pbi_page("Designed composition",
        pbi_text("Select a region to update the summary and trend.", font_size = 16) %>%
          pbi_place(24, 88, 1232, 48),
        pbi_card("revenue", title = "Revenue") %>% pbi_place(24, 154, 380, 136),
        pbi_card("units", title = "Units") %>% pbi_place(424, 154, 380, 136),
        pbi_line("date", "revenue", title = "Monthly performance") %>%
          pbi_place(24, 310, 780, 386),
        pbi_bar("region", "revenue", horizontal = TRUE, title = "Regional contribution") %>%
          pbi_place(824, 154, 432, 542),
        layout = pbi_layout("free"), size = "wide", interactions = "filter")
  },
  measures = function() {
    pbi_dashboard("Measures and ratios", pbi_demo_data(), table = "Sales") %>%
      pbi_measure("Total revenue", column = "revenue", format = "$#,0") %>%
      pbi_measure("Total cost", column = "cost", format = "$#,0") %>%
      pbi_measure("Gross profit", "[Total revenue] - [Total cost]", format = "$#,0") %>%
      pbi_measure("Gross margin", "DIVIDE([Gross profit], [Total revenue])", format = "0.0%") %>%
      pbi_page("Profitability",
        pbi_card(pbi_ref("Total revenue"), title = "Revenue"),
        pbi_card(pbi_ref("Gross margin"), title = "Margin on selected sales"),
        pbi_bar("product", pbi_ref("Gross profit"), title = "Profit by product"),
        pbi_line("date", pbi_ref("Gross margin"), title = "Margin over time"))
  },
  star = function() {
    products <- data.table::data.table(
      product = c("Atlas", "Beacon", "Cedar", "Delta"),
      category = c("Software", "Software", "Hardware", "Hardware"))
    pbi_dashboard("A small star schema", pbi_demo_data(), table = "Sales") %>%
      pbi_data("Products", products) %>%
      pbi_relationship("Sales", "product", "Products", "product") %>%
      pbi_measure("Total revenue", column = "revenue", table = "Sales", format = "$#,0") %>%
      pbi_page("Categories",
        pbi_slicer(pbi_field("category", "Products"), title = "Product category"),
        pbi_bar(pbi_field("category", "Products"), pbi_ref("Total revenue"),
          title = "Dimension filters flow to sales"),
        pbi_matrix(rows = pbi_field("product", "Products"),
          values = pbi_ref("Total revenue"), title = "Product detail"))
  },
  time = function() {
    pbi_dashboard("Time intelligence", pbi_demo_data(), table = "Sales") %>%
      pbi_date_table("2025-01-01", "2026-12-31") %>%
      pbi_relationship("Sales", "date", "Calendar", "Date") %>%
      pbi_measure("Sales amount", column = "revenue", table = "Sales", format = "$#,0") %>%
      pbi_measure("Prior year", "CALCULATE([Sales amount], SAMEPERIODLASTYEAR('Calendar'[Date]))",
        table = "Sales", format = "$#,0") %>%
      pbi_measure("Year-on-year", "DIVIDE([Sales amount] - [Prior year], [Prior year])",
        table = "Sales", format = "0.0%") %>%
      pbi_page("2026 compared with 2025",
        pbi_line(pbi_field("YearMonth", "Calendar"),
          list(pbi_ref("Sales amount"), pbi_ref("Prior year")), title = "Current and previous year"),
        pbi_card(pbi_ref("Year-on-year"), title = "Year-on-year change"),
        filters = list(pbi_filter(pbi_field("Year", "Calendar"), 2026L)))
  },
  filters = function() {
    pbi_dashboard("Three filter scopes", pbi_demo_data()) %>%
      pbi_filters(pbi_filter("region", c("Central", "West"))) %>%
      pbi_page("Overview",
        pbi_slicer("product", sync = "product-selection", title = "Shared product selection"),
        pbi_line("date", "revenue", title = "Revenue excluding Delta") %>%
          pbi_where(pbi_filter("product", "Delta", exclude = TRUE)),
        pbi_card("revenue", title = "All selected products"),
        filters = list(pbi_filter("date", seq.Date(as.Date("2026-01-01"), by = "month", length.out = 12))),
        interactions = "filter") %>%
      pbi_page("Detail",
        pbi_slicer("product", sync = "product-selection", title = "The same product selection"),
        pbi_bar("region", "revenue", title = "Regional sales"),
        pbi_table(c("date", "region", "product", "revenue"), title = "Underlying snapshot"),
        layout = pbi_layout("sidebar"))
  },
  scatter = function() {
    cars <- data.table::as.data.table(mtcars, keep.rownames = "car") %>%
      .[, cyl := as.character(cyl)]
    pbi_dashboard("Fuel economy", cars, theme = "accessible") %>%
      pbi_page("Compare cars",
        pbi_scatter("wt", "mpg", size = "hp", details = "car", legend = "cyl",
          aggregate = "average", tooltip = c("disp", "qsec"),
          title = "Fuel economy and weight", alt = "Fuel economy in miles per gallon versus vehicle weight; bubble size is horsepower."),
        pbi_slicer("cyl", style = "list", title = "Cylinder count"),
        layout = pbi_layout("focus", columns = 1, focus_ratio = 0.72))
  },
  tables = function() {
    pbi_dashboard("Tables and matrices", pbi_demo_data(), table = "Sales", theme = "ink") %>%
      pbi_measure("Total revenue", column = "revenue", format = "$#,0") %>%
      pbi_measure("Total units", column = "units", format = "#,0") %>%
      pbi_page("Comparative detail",
        pbi_table(list("region", "product", pbi_ref("Total revenue"), pbi_ref("Total units")),
          title = "Grouped table with explicit measures"),
        pbi_matrix(rows = "region", columns = "product", values = pbi_ref("Total revenue"),
          title = "Region by product"))
  },
  gallery = function() {
    pipeline <- data.table::data.table(
      stage = c("Leads", "Qualified", "Proposals", "Won"),
      prospects = c(2400L, 1100L, 520L, 180L), order = 1:4)
    bridge <- data.table::data.table(
      step = c("Opening", "New business", "Expansion", "Churn"),
      change = c(150, 40, 20, -35), order = 1:4)
    pbi_dashboard("Native chart gallery", pbi_demo_data(), table = "Sales", theme = "midnight") %>%
      pbi_data("Pipeline", pipeline, sort_by = c(stage = "order"), hidden = "order") %>%
      pbi_data("Bridge", bridge, sort_by = c(step = "order"), hidden = "order") %>%
      pbi_measure("Current sales", column = "revenue", table = "Sales", format = "$#,0") %>%
      pbi_measure("Sales target", "900000", table = "Sales", format = "$#,0") %>%
      pbi_measure("Gauge maximum", "1200000", table = "Sales") %>%
      pbi_measure("Gauge minimum", "0", table = "Sales") %>%
      pbi_page("Four visual forms",
        pbi_gauge(pbi_ref("Current sales"), target = pbi_ref("Sales target"),
          min = pbi_ref("Gauge minimum"), max = pbi_ref("Gauge maximum"), title = "Progress toward target"),
        pbi_treemap("product", "revenue", table = "Sales", title = "Product composition"),
        pbi_funnel("stage", "prospects", table = "Pipeline", title = "Sales pipeline") %>% pbi_sort("stage"),
        pbi_waterfall("step", "change", table = "Bridge", title = "Change in recurring revenue") %>% pbi_sort("step"))
  },
  types = function() {
    places <- data.table::data.table(
      city = c("\u0141\u00f3d\u017a", "M\u00fcnchen", "\u6771\u4eac", NA_character_),
      id = c("9007199254740993", "9007199254740994", "9007199254740995", "9007199254740996"),
      value = c(12.5, NA_real_, 18.75, 0),
      observed = as.POSIXct(c("2026-01-01 12:00:00", "2026-01-02 13:00:00",
                             "2026-01-03 14:00:00", NA_character_), tz = "UTC"))
    pbi_dashboard("Unicode and missing observations") %>%
      pbi_data("Places", places, types = c(id = "int64"), formats = c(value = "0.00")) %>%
      pbi_page("Typed edge cases",
        pbi_table(c("city", "id", "value", "observed"), title = "Values retain their intended types"),
        pbi_card("id", aggregate = "distinct_count", title = "Distinct location IDs"),
        pbi_bar("city", "value", title = "Available observations"),
        pbi_slicer("city", title = "Blank is a selectable value"))
  },
  showcase = function() {
    pbi_dashboard("Northstar | Commercial performance", pbi_demo_data(), table = "Sales", theme = "linen") %>%
      pbi_measure("Total revenue", column = "revenue", format = "$#,0") %>%
      pbi_measure("Total cost", column = "cost", format = "$#,0") %>%
      pbi_measure("Gross profit", "[Total revenue] - [Total cost]", format = "$#,0") %>%
      pbi_measure("Gross margin", "DIVIDE([Gross profit], [Total revenue])", format = "0.0%") %>%
      pbi_page("Executive overview",
        pbi_card(pbi_ref("Total revenue"), title = "Revenue") %>% pbi_place(24, 88, 398, 126),
        pbi_card(pbi_ref("Gross profit"), title = "Gross profit") %>% pbi_place(441, 88, 398, 126),
        pbi_card(pbi_ref("Gross margin"), title = "Gross margin") %>% pbi_place(858, 88, 398, 126),
        pbi_line("date", pbi_ref("Total revenue"), title = "Monthly revenue") %>% pbi_place(24, 234, 816, 462),
        pbi_bar("region", pbi_ref("Total revenue"), horizontal = TRUE, title = "Revenue by region") %>%
          pbi_place(860, 234, 396, 462),
        layout = pbi_layout("free"), interactions = "filter") %>%
      pbi_page("Products and mix",
        pbi_slicer("region", style = "list", sync = "regions", title = "Region"),
        pbi_treemap("product", pbi_ref("Total revenue"), title = "Revenue contribution"),
        pbi_bar("product", pbi_ref("Gross profit"), title = "Profit contribution"),
        pbi_donut("product", "units", title = "Unit mix"),
        pbi_matrix("region", pbi_ref("Gross margin"), columns = "product", title = "Margin by region and product"),
        layout = pbi_layout("sidebar"), interactions = "filter") %>%
      pbi_page("Trends and evidence",
        pbi_slicer("region", style = "list", sync = "regions", title = "Region"),
        pbi_area("date", pbi_ref("Total revenue"), legend = "product", stacked = TRUE, title = "Sales composition over time"),
        pbi_table(list("region", "product", pbi_ref("Total revenue"), pbi_ref("Gross profit")), title = "Supporting detail"),
        pbi_text("Source: deterministic synthetic sales panel.\nJanuary 2025 to December 2026. Values are illustrative.", font_size = 15),
        layout = pbi_layout("sidebar"))
  }
)

# A seventeenth example adds explicit interactions without replacing the
# original sixteen declarations or their deterministic data fixture.
.pbi_examples$shiny <- function() {
  pbi_dashboard("Explicit interaction flows", pbi_demo_data(), table = "Sales") %>%
    pbi_screen("Explore",
      pbi_input("region", "region", label = "Choose regions"),
      pbi_input("product", "product", label = "Choose products"),
      pbi_output("revenue", pbi_card("revenue", title = "Selected revenue")),
      pbi_output("trend", pbi_line("date", "revenue", title = "Selected monthly revenue")),
      pbi_output("detail", pbi_table(c("region", "product", "units", "revenue")))) %>%
    pbi_bind("region", c("revenue", "trend", "detail")) %>%
    pbi_bind("product", c("revenue", "trend", "detail"))
}

utils::globalVariables(c(".", ".N", "date", "region", "product", "units", "revenue", "cost", "cyl", ":="))
