test_that("snapshots are independent of caller and specifications", {
  d <- data.table::data.table(group = c("A", "B"), value = 1:2)
  a <- pbi_dashboard("Snapshot", d)
  data.table::set(d, j = "value", value = 8:9)
  expect_identical(a$tables$data$data$value, 1:2)
  b <- a %>% pbi_measure("Total", column = "value")
  expect_length(a$measures, 0L)
  expect_length(b$measures, 1L)
  c <- b %>% pbi_page("Summary", pbi_card("Total"))
  expect_length(b$pages, 0L)
  expect_equal(nrow(pbi_validate(c)), 0L)
})

test_that("input invariants fail before compiling", {
  expect_error(pbi_dashboard("Bad", data.frame(A = 1, a = 2)), "unique")
  expect_error(pbi_dashboard("Bad", data.frame(x = Inf)), "infinite")
  expect_error(pbi_dashboard("Bad", data.frame(x = complex(real = 1))), "Unsupported")
  expect_error(pbi_dashboard("Bad", data.frame(x = I(list(1:3)))), "Unsupported")
  expect_error(pbi_theme(colors = "blue"), "RRGGBB")
  expect_error(pbi_field("x", aggregate = "median"), "arg")
  expect_error(pbi_dashboard("Report", mtcars) %>% pbi_data("data", mtcars), "exists")
})

test_that("DAX escaping, references and aggregation defaults are coherent", {
  d <- data.frame(check.names = FALSE, `amount]` = c(1, 2), city = c("a", "b"))
  x <- pbi_dashboard("Quotes", d, table = "Owner's data") %>%
    pbi_measure("Gross", column = "amount]") %>%
    pbi_page("Summary", pbi_card(pbi_ref("Gross")))
  expect_identical(x$measures[[1]]$expression, "SUM('Owner''s data'[amount]]])")
  expect_identical(pbiweave:::resolve_field(x, "Gross")$kind, "measure")
  expect_error(pbiweave:::resolve_field(x, pbi_field("Gross")), "Unknown")
  expect_error(pbi_measure(x, "City sum", column = "city"), "non-numeric")
  expect_error(pbi_measure(x, "Gross", expression = "1"), "Duplicate")
})

test_that("relationships and calendar maintain usable model semantics", {
  x <- pbi_dashboard("Model", list(fact = data.frame(key = c(1L, 2L, 9L), value = 1:3),
                                   dim = data.frame(key = 1:2))) %>%
    pbi_relationship("fact", "key", "dim", "key") %>%
    pbi_date_table("2024-01-01", "2024-12-31") %>%
    pbi_page("Summary", pbi_card("value"))
  expect_equal(nrow(x$tables$Calendar$data), 366L)
  expect_true(x$tables$Calendar$date_table)
  expect_true("orphan_keys" %in% pbi_validate(x)$code)
  expect_error(pbi_validate(x, strict = TRUE, stop_on_error = TRUE), "no match")
  expect_error(pbi_relationship(x, "fact", "key", "dim", "key"), "already")
})

test_that("query preflight catches missing fields and semantic visual limits", {
  x <- pbi_dashboard("Bindings", data.frame(x = letters[1:3], y = 1:3, z = 4:6))
  bad <- x %>% pbi_page("Wrong", pbi_bar("absent", "y"))
  expect_true("field_binding" %in% pbi_validate(bad)$code)
  expect_error(pbi_validate(bad, stop_on_error = TRUE), "Unknown")
  bad <- x %>% pbi_page("Wrong", pbi_bar("x", c("y", "z"), legend = "x"))
  expect_true("multiple_values_with_legend" %in% pbi_validate(bad)$code)
  bad <- x %>% pbi_page("Wrong", pbi_slicer("x", style = "between"))
  expect_true("invalid_slicer" %in% pbi_validate(bad)$code)
  good <- x %>% pbi_page("Good", pbi_bar("x", "y") %>% pbi_sort("y", descending = TRUE))
  expect_equal(nrow(pbi_validate(good)), 0L)
})
