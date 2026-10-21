# New gates augment, rather than replace, the original behavior tests.
consolidated_dashboard <- function() {
  pbi_dashboard("Consolidation", data.frame(group = c("A", "B"), amount = c(10, 20))) %>%
    pbi_page("Overview", pbi_slicer("group"), pbi_bar("group", "amount"), pbi_card("amount"))
}

test_that("the public surface is the union of both historical releases", {
  restored <- c("pbi_bundle", "pbi_date_table", "pbi_filters", "pbi_where", "pbi_inspect")
  added <- c("pbi_prepare", "pbi_column", "pbi_aggregate", "pbi_ratio", "pbi_calendar",
             "pbi_input", "pbi_output", "pbi_screen", "pbi_bind", "pbi_flow")
  expect_true(all(c(restored, added) %in% getNamespaceExports("pbiweave")))
  expect_length(getNamespaceExports("pbiweave"), 50L)
})

test_that("TMDL is the default while TMSL remains explicit", {
  root <- tempfile(); dir.create(root); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  a <- pbi_compile(consolidated_dashboard(), file.path(root, "tmdl"), bundle = TRUE)
  b <- pbi_compile(consolidated_dashboard(), file.path(root, "tmsl"), model_format = "tmsl")
  expect_identical(a$model_format, "tmdl")
  expect_true(file.exists(file.path(a$model, "definition", "database.tmdl")))
  expect_false(file.exists(file.path(a$model, "model.bim")))
  expect_true(file.exists(file.path(b$model, "model.bim")))
  expect_false(dir.exists(file.path(b$model, "definition")))
  expect_identical(a$pbip, a$project_file)
  expect_true(pbi_check(a, verify_hashes = TRUE)$valid)
  expect_identical(pbi_check(a)$embedded_tables_checked, 1L)
  expect_true(is.na(pbi_check(a)$data_loaded))
  expect_false(pbi_check(a)$runtime_checked)
  expect_message(refresh_notice(), "Home -> Refresh")
})

test_that("both output representations contain the same prepared tables and payload", {
  root <- tempfile(); dir.create(root); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  d <- pbi_example("star")
  a <- pbi_compile(d, file.path(root, "a"))
  b <- pbi_compile(d, file.path(root, "b"), model_format = "tmsl")
  inv <- read_tmdl_inventory(file.path(a$model, "definition"))
  ref <- jsonlite::fromJSON(file.path(b$model, "model.bim"), simplifyVector = FALSE)$model$tables
  expect_setequal(names(inv), vapply(ref, `[[`, character(1), "name"))
  invisible(lapply(ref, function(t) {
    expect_identical(unname(inv[[t$name]]$columns), vapply(t$columns, `[[`, character(1), "name"))
    # M expressions are verbatim inside a TMDL fence, indented by three tabs.
    m <- paste0("\t\t\t", unlist(t$partitions[[1]]$source$expression))
    expect_true(all(vapply(m, grepl, logical(1), x = inv[[t$name]]$expression, fixed = TRUE)))
  }))
})

test_that("TMDL escapes names and keeps optional formats genuinely optional", {
  expect_identical(tmdl_name("O'Brien.A"), "'O''Brien.A'")
  expect_identical(tmdl_text('A "quote"'), '"A ""quote"""')
  d <- pbi_dashboard("Quoted", setNames(data.frame(x = 1), "A.B"), table = "O'Brien") %>%
    pbi_measure("Unformatted", "1 +\n  2", description = "First line\nSecond line")
  model <- model_definition(d)
  text <- tmdl_table(model$model$tables[[1]])
  measure_at <- grep("measure 'Unformatted'", text, fixed = TRUE)
  expect_length(measure_at, 1L)
  expect_true(any(grepl("/// Second line", text, fixed = TRUE)))
  expect_false(any(grepl("formatString:", tmdl_measure(model$model$tables[[1]]$measures[[1]]), fixed = TRUE)))
  expect_error(tmdl_expression("measure X", "1\n```\n2", "\t"), "fence")
  expect_error(tmdl_text("bad\nproperty"), "line breaks")
})

test_that("old positional constructors and safe new aliases coexist", {
  values <- data.frame(id = 1:2, value = c(5, 10))
  a <- pbi_data(pbi_dashboard("Names"), "Facts", values)
  b <- pbi_data(pbi_dashboard("Names"), values, "Facts")
  expect_identical(a, b)
  expect_identical(pbi_bar("id", "value", legend = "id"),
                   pbi_bar("id", "value", series = "id"))
  expect_identical(pbi_sort(pbi_bar("id", "value"), "value", TRUE),
                   pbi_sort(pbi_bar("id", "value"), "value", direction = "descending"))
  expect_identical(pbi_theme(font_size = 12), pbi_theme(text_size = 12))
  expect_identical(pbi_text("Hi", font_size = 14), pbi_text("Hi", size = 14))
  expect_error(pbi_bar("id", "value", legend = "id", series = "id"), "not both")
  expect_error(pbi_theme(colors = c("#112233", "#223344", "#334455"), palette = c("#112233", "#223344", "#334455")), "not both")
  expect_identical(names(formals(pbi_compile))[1:6], c("x", "path", "overwrite", "bundle", "compression", "open"))
  expect_identical(names(formals(pbi_scatter))[1:5], c("x", "y", "size", "details", "legend"))
  expect_identical(pbi_example("quickstart"), pbi_example(name = "quickstart"))
})

test_that("default data and chart meanings are those of 0.1.0", {
  d <- pbi_demo_data()
  expect_identical(names(d), c("date", "region", "product", "units", "revenue", "cost"))
  expect_equal(nrow(d), 288L)
  expect_equal(sum(d$revenue), 929888)
  expect_equal(sum(d$cost), 576336.64)
  expect_equal(sum(d$units), 18368L)
  expect_identical(names(pbi_dashboard("Data", d)$tables), "data")
  expect_false(pbi_bar("region", "revenue")$options$horizontal)
  expect_identical(native_visual_type(pbi_card(c("revenue", "cost"))), "cardVisual")
})

test_that("preparation is immediate and copy-safe", {
  input <- data.table::data.table(value = 1:2)
  n <- 0L
  out <- pbi_prepare(input, function(d) { n <<- n + 1L; d[, value := value * 2L]; d })
  expect_identical(n, 1L)
  expect_identical(input$value, 1:2)
  expect_identical(out$value, c(2L, 4L))
  expect_error(pbi_prepare(input, function(d) 1), "return a data frame")
})

test_that("column conversion uses the original typed normalizers", {
  d <- pbi_dashboard("Exact", data.frame(id = c("01", "+1"), cash = c(".25", "1")))
  out <- d %>% pbi_column("id", type = "int64") %>% pbi_column("cash", type = "decimal")
  expect_identical(out$tables$data$data$id, c("1", "1"))
  expect_identical(out$tables$data$data$cash, c("0.2500", "1.0000"))
  expect_identical(d$tables$data$data$id, c("01", "+1"))
  expect_error(pbi_column(d, "id", type = "date"), "ISO")
  expect_error(normalize_decimal(0.000000001, "cash"), "four decimal")
  expect_error(normalize_decimal("922337203685477.5808", "cash"), "overflow")
})

test_that("metadata edits revalidate existing relationship keys", {
  d <- pbi_dashboard("Keys", data.frame(id = c("01", "1")), table = "Fact") %>%
    pbi_data("Dim", data.frame(id = c("01", "1"))) %>%
    pbi_relationship("Fact", "id", "Dim", "id")
  expect_error(pbi_column(d, "id", table = "Dim", type = "int64"), "key types must match")
  d$tables$Dim$data$id <- c("A", "a")
  expect_true("relationship_keys" %in% pbi_validate(d)$code)
})

test_that("unmatched-key policies distinguish warnings from strict failures", {
  d <- pbi_dashboard("Keys", data.frame(id = c("A", " B", NA)), table = "Fact") %>%
    pbi_data("Dim", data.frame(id = c("A", "B")))
  expect_error(pbi_relationship(d, "Fact", "id", "Dim", "id", unmatched = "error"), "unmatched")
  w <- pbi_relationship(d, "Fact", "id", "Dim", "id") %>% pbi_page("Keys", pbi_table(table = "Fact"))
  expect_true("orphan_keys" %in% pbi_validate(w)$code)
  expect_error(pbi_validate(w, strict = TRUE, stop_on_error = TRUE), "no match")
  a <- pbi_relationship(d, from_table = "Fact", from_column = "id", to_table = "Dim", to_column = "id", unmatched = "allow") %>%
    pbi_page("Keys", pbi_table(table = "Fact"))
  expect_false("orphan_keys" %in% pbi_validate(a)$code)
})

test_that("both filter interfaces preserve typed values and blanks", {
  d <- consolidated_dashboard()
  f <- pbi_filter("group", c("A", NA))
  a <- pbi_filters(d, f)
  b <- pbi_filter(d, "group", c("A", NA))
  c <- pbi_filter(x = d, field = "group", values = c("A", NA))
  expect_identical(a, b); expect_identical(a, c)
  v <- pbi_bar("group", "amount")
  expect_identical(pbi_where(v, pbi_filter("group", "A")), v %>% pbi_filter("group", "A"))
  expect_true(pbi_validate(a)$valid)
  expect_true(pbi_validate(d %>% pbi_filter("amount", "oops"))$valid == FALSE)
  scoped <- d %>% pbi_filter("group", "A", page = "Overview")
  expect_length(scoped$filters, 0L)
  expect_length(scoped$pages[[1]]$filters, 1L)
})

test_that("query references and numeric-none tooltips retain their semantics", {
  d <- pbi_dashboard("References", data.frame(C = c(1, 2)), table = "A.B") %>%
    pbi_data("A", setNames(data.frame(x = c(1, 2)), "B.C"))
  f1 <- resolve_field(d, pbi_field("C", "A.B"))
  f2 <- resolve_field(d, pbi_field("B.C", "A"))
  expect_false(identical(field_query_ref(f1), field_query_ref(f2)))
  d <- consolidated_dashboard()
  q <- visual_query(d, pbi_bar("group", "amount", tooltip = list("group", pbi_field("amount", aggregate = "none"))))
  expect_true(!is.null(q$queryState$Tooltips$projections[[1]]$field$Column))
  expect_true(!is.null(q$queryState$Tooltips$projections[[2]]$field$Column))
  expect_error(visual_query(d, pbi_bar("group", pbi_field("amount", aggregate = "none"))), "require an aggregation")
})

test_that("visual labels formats descriptions and gauge constants survive", {
  d <- consolidated_dashboard()
  v <- pbi_bar("group", pbi_aggregate("amount", label = "Net amount", format = "$#,0"), alt = "An accessible comparison")
  q <- visual_query(d, v)
  expect_identical(q$queryState$Y$projections[[1]]$nativeQueryRef, "Net amount")
  expect_length(visual_field_formats(d, v), 1L)
  expect_identical(visual_container_style(v, d$theme, "Title")$general[[1]]$properties$altText$expr$Literal$Value,
                   "'An accessible comparison'")
  expect_identical(pbi_gauge("amount", target = 20, minimum = 0, maximum = 100)$options$constants,
                   list(target = 20, min = 0, max = 100))
  expect_error(pbi_gauge("amount", min = 10, max = 1), "less than")
})

test_that("both calendar interfaces preserve rich attributes", {
  d <- pbi_dashboard("Days", data.frame(day = as.Date("2025-01-01") + 0:3))
  standalone <- pbi_date_table(d, "2025-01-01", "2025-12-31")
  related <- pbi_calendar(d, "day")
  expect_true(all(c("Quarter", "YearMonth", "WeekdayName", "Day") %in% names(related$tables$Calendar$columns)))
  expect_equal(nrow(standalone$tables$Calendar$data), 365)
  expect_length(standalone$relationships, 0L)
  expect_length(related$relationships, 1L)
  expect_identical(related$tables$Calendar$columns$MonthName$sort_by, "Month")
})

test_that("sidebar policies are explicit and original layout controls remain", {
  d <- pbi_dashboard("Layout", data.frame(group = c("A", "B"), value = 1:2))
  a <- pbi_page(d, "Page", pbi_slicer("group"), pbi_slicer("value"), pbi_card("value"),
                layout = pbi_layout("sidebar"))
  b <- pbi_page(d, "Page", pbi_slicer("group"), pbi_slicer("value"), pbi_card("value"),
                layout = pbi_layout("sidebar", sidebar_mode = "slicers"))
  pa <- layout_page(a$pages[[1]]); pb <- layout_page(b$pages[[1]])
  expect_true(pa[[2]]$x > pa[[1]]$x)
  expect_equal(pb[[1]]$x, pb[[2]]$x)
  expect_true(pb[[3]]$x > pb[[1]]$x)
  expect_identical(pbi_layout(header = 0, focus_ratio = .7)$header, 0)
  page <- pbi_page(d, "Hidden", pbi_card("value"), hidden = TRUE, background = "#112233")$pages[[1]]
  expect_true(page$hidden); expect_identical(page$background, "#112233")
})

test_that("explicit interaction edges are inspectable and replaceable", {
  d <- pbi_example("shiny")
  expect_equal(nrow(pbi_flow(d)), 6L)
  changed <- pbi_bind(d, "region", "trend", mode = "none")
  expect_equal(nrow(pbi_flow(changed)), 5L)
  enabled <- pbi_bind(changed, "region", "trend", mode = "native")
  edge <- pbi_flow(enabled)
  expect_equal(sum(edge$source == "region" & edge$target == "trend"), 1L)
  expect_error(pbi_bind(d, "region", "missing"), "missing")
  expect_error(pbi_bind(d, "revenue", "trend"), "source")
  expect_true(pbi_validate(d)$valid)
})

test_that("same-named sync groups cannot bind different model columns", {
  d <- consolidated_dashboard() %>%
    pbi_page("Sync A", pbi_slicer("group", sync = "same")) %>%
    pbi_page("Sync B", pbi_slicer("amount", sync = "same"))
  expect_true("invalid_slicer" %in% pbi_validate(d)$code)
})

test_that("diagnostics remain a data.table with compatibility accessors", {
  d <- pbi_validate(consolidated_dashboard())
  expect_s3_class(d, "data.table")
  expect_identical(names(d), c("severity", "code", "location", "message"))
  expect_true(d$valid); expect_length(d$errors, 0L)
  expect_true(all(c("tables", "pages", "diagnostics") %in% names(pbi_inspect(consolidated_dashboard()))))
})

test_that("overwrite preserves the old project and commits both outputs", {
  root <- tempfile(); dir.create(root); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  a <- pbi_compile(consolidated_dashboard(), file.path(root, "app"), bundle = TRUE)
  writeLines("Preserve Desktop edits", file.path(a$path, "notes.txt"))
  b <- pbi_compile(consolidated_dashboard(), a$path, overwrite = TRUE, bundle = TRUE)
  expect_true(file.exists(file.path(b$backup, "notes.txt")))
  expect_true(file.exists(b$bundle_backup))
  expect_false(file.exists(file.path(b$path, "notes.txt")))
  expect_true(pbi_check(b, verify_hashes = TRUE)$valid)
})

test_that("old and newer manifests are accepted but contradictions are rejected", {
  root <- tempfile(); dir.create(root); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  p <- pbi_compile(consolidated_dashboard(), file.path(root, "app"), model_format = "tmsl")
  manifest <- jsonlite::fromJSON(file.path(p$path, "pbiweave.json"), simplifyVector = FALSE)
  manifest$packageVersion <- "0.1.0"
  write_json(manifest, file.path(p$path, "pbiweave.json"))
  expect_true(pbi_check(p)$valid)
  write_json(manifest, file.path(p$path, "pbiweave-manifest.json"))
  expect_false(pbi_check(p, stop_on_error = FALSE)$valid)
  unlink(file.path(p$path, "pbiweave.json"))
  expect_true(pbi_check(p)$valid)
  dir.create(file.path(p$model, "definition"))
  expect_error(pbi_check(p), "exactly one")
})

test_that("payload and hash checks catch damage independently", {
  root <- tempfile(); dir.create(root); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  p <- pbi_compile(consolidated_dashboard(), file.path(root, "app"))
  path <- list.files(file.path(p$model, "definition", "tables"), full.names = TRUE)[1]
  text <- readLines(path, warn = FALSE)
  writeLines(c(text, ""), path)
  expect_error(pbi_check(p, verify_hashes = TRUE), "hash mismatch")
  expect_true(pbi_check(p, check_data = TRUE)$valid)
  bad <- sub('Payload = Text.Combine\\(\\{"[A-Za-z0-9+/=]+"', 'Payload = Text.Combine({"YWJj"', text)
  writeLines(bad, path)
  expect_false(pbi_check(p, stop_on_error = FALSE)$valid)
  expect_true(pbi_check(p, check_data = FALSE)$valid)
})

test_that("bundling retains edited source and omits only local cache files", {
  root <- tempfile(); dir.create(root); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  p <- pbi_compile(consolidated_dashboard(), file.path(root, "app"))
  dir.create(file.path(p$model, ".pbi"))
  writeLines("cache", file.path(p$model, ".pbi", "cache.abf"))
  write_json(list(), file.path(p$model, ".pbi", "localSettings.json"))
  write_json(list(), file.path(p$model, ".pbi", "editorSettings.json"))
  writeLines("Human notes", file.path(p$path, "NOTES.md"))
  file <- pbi_bundle(p)
  entries <- zip::zip_list(file)$filename
  expect_false(any(grepl("cache.abf|localSettings.json", entries)))
  expect_true(any(grepl("editorSettings.json", entries)))
  expect_true("NOTES.md" %in% entries)
  expect_error(pbi_bundle(p, file.path(p$path, "inside.zip")), "outside")
})

test_that("symlinked destinations do not allow replacement of unrelated data", {
  skip_on_os("windows")
  root <- tempfile(); dir.create(root); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  original <- file.path(root, "original"); dir.create(original)
  writeLines("keep", file.path(original, "user.txt"))
  link <- file.path(root, "linked")
  skip_if_not(file.symlink(original, link))
  expect_error(pbi_compile(consolidated_dashboard(), link, overwrite = TRUE), "symlink")
  expect_identical(readLines(file.path(original, "user.txt")), "keep")
})

test_that("all original examples plus the additive example validate", {
  expected <- c("quickstart", "typed", "themes", "grid", "sidebar", "focus", "free", "measures",
                "star", "time", "filters", "scatter", "tables", "gallery", "types", "showcase", "shiny")
  expect_identical(names(.pbi_examples), expected)
  invisible(lapply(expected, function(name) expect_true(pbi_validate(pbi_example(name))$valid, info = name)))
})
