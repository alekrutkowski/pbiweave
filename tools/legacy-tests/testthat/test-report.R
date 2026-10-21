report_fixture <- function() {
  pbi_dashboard("Revenue", data.table::data.table(
    region = c("East", "West", "East"),
    product = c("A", "B", "C"),
    revenue = c(100, 200, 150),
    units = c(1L, 2L, 3L),
    date = as.Date(c("2026-01-01", "2026-01-02", "2026-02-01")),
    active = c(TRUE, FALSE, TRUE)))
}

test_that("visual roles bind native queries with correct aggregation semantics", {
  d <- report_fixture()
  bar <- visual_query(d, pbi_bar("region", "revenue", legend = "product"))
  expect_named(bar$queryState, c("Category", "Y", "Series"))
  expect_equal(bar$queryState$Category$projections[[1]]$field$Column$Property, "region")
  expect_equal(bar$queryState$Y$projections[[1]]$field$Aggregation$Function, 0L)
  expect_equal(bar$queryState$Y$projections[[1]]$queryRef, "Sum(data.revenue)")
  count <- visual_query(d, pbi_card("product", aggregate = "count"))
  distinct <- visual_query(d, pbi_card("product", aggregate = "distinct_count"))
  expect_equal(count$queryState$Data$projections[[1]]$field$Aggregation$Function, 5L)
  expect_equal(distinct$queryState$Data$projections[[1]]$field$Aggregation$Function, 2L)
  expect_named(visual_query(d, pbi_matrix("region", "revenue", "product"))$queryState,
               c("Rows", "Columns", "Values"))
  expect_named(visual_query(d, pbi_treemap("region", "revenue"))$queryState,
               c("Group", "Values"))
  expect_named(visual_query(d, pbi_scatter("units", "revenue", size = "units",
    details = "product", legend = "region"))$queryState,
    c("X", "Y", "Size", "Category", "Series"))
  expect_named(visual_query(d, pbi_gauge("revenue", "units", "units", "units"))$queryState,
               c("Y", "TargetValue", "MinValue", "MaxValue"))
})

test_that("value sorting uses the exact aggregated expression projected by the chart", {
  d <- report_fixture()
  chart <- pbi_sort(pbi_bar("region", "revenue", aggregate = "average"), "revenue", descending = TRUE)
  query <- visual_query(d, chart)
  expect_identical(query$sortDefinition$sort[[1]]$field,
                   query$queryState$Y$projections[[1]]$field)
  expect_identical(query$sortDefinition$sort[[1]]$direction, "Descending")
  line <- visual_query(d, pbi_line("date", "revenue"))
  expect_identical(line$sortDefinition$sort[[1]]$field,
                   line$queryState$Category$projections[[1]]$field)
  expect_identical(line$sortDefinition$sort[[1]]$direction, "Ascending")
})

test_that("dotted identifiers cannot collide in native query references", {
  first <- list(table = "A.B", name = "C", kind = "column", aggregate = NULL)
  second <- list(table = "A", name = "B.C", kind = "column", aggregate = NULL)
  expect_false(identical(field_query_ref(first), field_query_ref(second)))
  expect_identical(field_query_ref(first), field_query_ref(first))
  expect_equal(field_expression(first)$Column$Expression$SourceRef$Entity, "A.B")
})

test_that("tooltip text is retained while numeric fields aggregate", {
  d <- report_fixture()
  tooltip <- visual_query(d, pbi_bar("region", "revenue", tooltip = c("product", "units")))$queryState$Tooltips
  expect_equal(tooltip$projections[[1]]$field$Column$Property, "product")
  expect_equal(tooltip$projections[[2]]$field$Aggregation$Function, 0L)
})

test_that("automatic table columns cannot silently produce an empty native query", {
  d <- report_fixture()
  d$tables$data$columns <- lapply(d$tables$data$columns, function(column) {
    column$hidden <- TRUE
    column
  })
  expect_error(visual_query(d, pbi_table()), "at least one visible")
  expect_length(visual_query(d, pbi_table("region"))$queryState$Values$projections, 1L)
})

test_that("native chart variants and latest card type are selected explicitly", {
  expect_identical(native_visual_type(pbi_card("revenue")), "cardVisual")
  expect_identical(native_visual_type(pbi_bar("region", "revenue")), "clusteredColumnChart")
  expect_identical(native_visual_type(pbi_bar("region", "revenue", horizontal = TRUE)), "clusteredBarChart")
  expect_identical(native_visual_type(pbi_bar("region", "revenue", stacked = TRUE)), "columnChart")
  expect_identical(native_visual_type(pbi_bar("region", "revenue", percent = TRUE)), "hundredPercentStackedColumnChart")
  expect_identical(native_visual_type(pbi_area("date", "revenue", stacked = TRUE)), "stackedAreaChart")
})

test_that("grouping roles reject aggregated axes and legends", {
  d <- report_fixture()
  expect_error(visual_query(d, pbi_bar(pbi_field("region", aggregate = "count"), "revenue")),
               "Grouping roles require unaggregated columns")
  expect_error(visual_query(d, pbi_bar("region", "revenue", legend = pbi_field("product", aggregate = "count"))),
               "Grouping roles require unaggregated columns")
})

test_that("categorical filters have typed escaped literals and query aliases", {
  d <- report_fixture()
  includes <- compile_filters(d, list(pbi_filter("region", c("O'Connell", NA))), "report")$filters[[1]]
  expect_equal(includes$field$Column$Expression$SourceRef$Entity, "data")
  predicate <- includes$filter$Where[[1]]$Condition$In
  expect_equal(predicate$Expressions[[1]]$Column$Expression$SourceRef$Source, "s")
  expect_equal(predicate$Values[[1]][[1]]$Literal$Value, "'O''Connell'")
  expect_equal(predicate$Values[[2]][[1]]$Literal$Value, "null")
  excludes <- compile_filters(d, list(pbi_filter("region", "West", exclude = TRUE)), "page1")$filters[[1]]
  expect_named(excludes$filter$Where[[1]]$Condition, "Not")
  expect_false(identical(includes$name, excludes$name))
  dates <- compile_filters(d, list(pbi_filter("date", as.Date("2026-01-01"))), "page2")$filters[[1]]
  expect_equal(dates$filter$Where[[1]]$Condition$In$Values[[1]][[1]]$Literal$Value,
               "datetime'2026-01-01T00:00:00'")
  expect_error(compile_filters(d, list(pbi_filter(pbi_field("revenue", aggregate = "sum"), 1)), "bad"),
               "unaggregated column")
  expect_error(compile_filters(d, list(pbi_filter("active", "bogus")), "bad"))
  expect_equal(query_literal("922337203685477.5807", "decimal"), "922337203685477.5807M")
  expect_equal(query_literal("-922337203685477.5808", "decimal"), "-922337203685477.5808M")
  expect_equal(query_literal("9007199254740993", "int64"), "9007199254740993L")
})

test_that("cards and slicers include their actual native field wells and accessibility text", {
  d <- report_fixture()
  pos <- list(x = 24, y = 24, z = 1000, width = 400, height = 240, tabOrder = 1000)
  card <- compile_visual(d, pbi_card("revenue", title = "Total revenue", alt = "Revenue in euros"),
                         pos, "v001_001", "p1v1")
  expect_equal(card$visual$visualType, "cardVisual")
  expect_named(card$visual$query$queryState, "Data")
  expect_equal(card$visual$visualContainerObjects$general[[1]]$properties$altText$expr$Literal$Value,
               "'Revenue in euros'")
  slicer <- compile_visual(d, pbi_slicer("region", sync = "Region"), pos, "v001_002", "p1v2")
  expect_named(slicer$visual$query$queryState, "Values")
  expect_equal(slicer$visual$syncGroup, list(groupName = "Region", fieldChanges = TRUE, filterChanges = TRUE))
  expect_equal(slicer$visual$objects$data[[1]]$properties$mode$expr$Literal$Value, "'Dropdown'")
  text <- compile_visual(d, pbi_text("Line one\nLine two"), pos, "v001_003", "p1v3")
  expect_null(text$visual$query)
  expect_length(text$visual$objects$general[[1]]$properties$paragraphs, 2L)
})

test_that("reports resolve local model and theme resources and preserve array shapes", {
  d <- pbi_page(report_fixture(), "Overview", pbi_bar("region", "revenue"),
                pbi_slicer("region"), interactions = "filter")
  path <- tempfile()
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  compile_report(d, path, "Revenue.SemanticModel")
  read <- function(...) jsonlite::fromJSON(file.path(path, ...), simplifyVector = FALSE)
  pbir <- read("definition.pbir")
  expect_equal(pbir$datasetReference$byPath$path, "../Revenue.SemanticModel")
  expect_equal(pbir$version, "4.0")
  report <- read("definition", "report.json")
  theme_name <- report$themeCollection$customTheme$name
  expect_true(file.exists(file.path(path, "StaticResources", "RegisteredResources", theme_name)))
  expect_equal(report$resourcePackages[[1]]$items[[1]]$path, theme_name)
  pages <- read("definition", "pages", "pages.json")
  expect_type(pages$pageOrder, "list")
  page <- read("definition", "pages", pages$pageOrder[[1]], "page.json")
  expect_length(page$visualInteractions, 2L)
  expect_true(all(vapply(page$visualInteractions, function(x) x$type == "DataFilter", logical(1))))
  visual <- read("definition", "pages", pages$pageOrder[[1]], "visuals", "v001_001", "visual.json")
  expect_type(visual$visual$query$queryState$Y$projections, "list")
  expect_type(visual$visual$visualContainerObjects$title, "list")
})
