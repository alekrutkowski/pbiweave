test_that("adding data snapshots caller-owned data.tables", {
  source <- data.table::data.table(label = c("A", "B"), amount = c(1, 2))
  dashboard <- pbi_dashboard("Snapshot", source)
  data.table::set(source, i = 1L, j = "amount", value = 999)
  expect_identical(dashboard$tables$data$data$amount, c(1, 2))
  expect_identical(source$amount, c(999, 2))
  newer <- pbi_data(dashboard, "Other", data.frame(id = 1L))
  expect_identical(names(dashboard$tables), "data")
  expect_identical(names(newer$tables), c("data", "Other"))
})

test_that("int64 text is canonical before uniqueness checks", {
  input <- c("0001", "+01", "-0", "000", "-001", NA_character_,
             "9223372036854775807", "-9223372036854775808")
  dashboard <- pbi_data(pbi_dashboard("IDs"), "IDs", data.frame(id = input),
                        types = c(id = "int64"))
  expect_identical(dashboard$tables$IDs$data$id,
                   c("1", "1", "0", "0", "-1", NA_character_,
                     "9223372036854775807", "-9223372036854775808"))
  expect_error(pbi_data(pbi_dashboard("Overflow"), "D", data.frame(id = "9223372036854775808"),
                        types = c(id = "int64")), "overflow")
  expect_error(pbi_data(pbi_dashboard("Fraction"), "D", data.frame(id = 1.5),
                        types = c(id = "int64")), "exact integers")
  related <- pbi_data(pbi_dashboard("Keys", data.frame(id = 1L)), "dim",
                      data.frame(id = c("01", "1")), types = c(id = "int64"))
  expect_error(pbi_relationship(related, "data", "id", "dim", "id"), "unique")
})

test_that("integer64 class values retain precision", {
  skip_if_not_installed("bit64")
  input <- bit64::as.integer64(c("9007199254740993", "9223372036854775807", NA))
  dashboard <- pbi_dashboard("Large IDs", data.frame(id = input))
  expect_identical(dashboard$tables$data$data$id,
                   c("9007199254740993", "9223372036854775807", NA_character_))
})

test_that("fixed decimal boundaries and scale are checked exactly", {
  normalize <- function(x) pbi_data(pbi_dashboard("Money"), "D", data.frame(amount = x),
                                    types = c(amount = "decimal"))$tables$D$data$amount
  expect_identical(normalize(c("922337203685477.5807", "-922337203685477.5808", "-000.0", ".25")),
                   c("922337203685477.5807", "-922337203685477.5808", "0.0000", "0.2500"))
  expect_error(normalize("922337203685477.5808"), "overflow")
  expect_error(normalize("-922337203685477.5809"), "overflow")
  expect_error(normalize("0.12345"), "four decimal")
  expect_error(normalize(0.12345), "four decimal")
  expect_identical(normalize(c(0.1, 1.2345, -12, NA_real_)),
                   c("0.1000", "1.2345", "-12.0000", NA_character_))
})

test_that("relationships reject case and trailing-space key collisions", {
  relationship <- function(keys) {
    dashboard <- pbi_data(pbi_dashboard("Keys", data.frame(id = "A")), "Dim", data.frame(id = keys))
    pbi_relationship(dashboard, "data", "id", "Dim", "id")
  }
  expect_error(relationship(c("A", "a")), "unique")
  expect_error(relationship(c("A", "A ")), "unique")
  expect_s3_class(relationship(c("A", " A")), "pbi_dashboard")
})

test_that("sort-by mappings cannot be ambiguous or circular", {
  add <- function(data, sort_by) pbi_data(pbi_dashboard("Sort"), "D", data, sort_by = sort_by)
  expect_error(add(data.frame(label = c("Jan", "Jan"), order = 1:2), c(label = "order")), "exactly one")
  expect_error(add(data.frame(label = c("Jan", "JAN "), order = 1:2), c(label = "order")), "exactly one")
  expect_error(add(data.frame(a = 1:2, b = 2:1), c(a = "a")), "itself")
  expect_error(add(data.frame(a = 1:2, b = 2:1), c(a = "b", b = "a")), "circular")
  expect_s3_class(add(data.frame(label = c("Jan", "Jan", "Feb"), order = c(1L, 1L, 2L)),
                     c(label = "order")), "pbi_dashboard")
})

test_that("filter normalization preserves blanks and rejects type mismatches", {
  expect_identical(normalize_filter_values(c("0001", NA), "int64"), c("1", NA_character_))
  expect_identical(normalize_filter_values(NA, "int64"), NA_character_)
  expect_identical(normalize_filter_values(c("true", "FALSE", NA), "boolean"), c(TRUE, FALSE, NA))
  expect_identical(normalize_filter_values(c("2024-02-29", NA), "date"),
                   as.Date(c("2024-02-29", NA)))
  expect_s3_class(normalize_filter_values(NA, "dateTime"), "POSIXct")
  expect_error(normalize_filter_values("not-boolean", "boolean"), "requires logical")
  expect_error(normalize_filter_values("1.5", "int64"), "Invalid int64")
  expect_error(normalize_filter_values("not-number", "double"), "invalid")
  expect_error(normalize_filter_values("2023-02-29", "date"), "Invalid dates")
})

test_that("timestamps preserve instants while adopting UTC", {
  instant <- as.POSIXct("2026-07-01 12:30:00", tz = "Europe/Berlin")
  dashboard <- pbi_dashboard("Time", data.frame(instant = instant))
  actual <- dashboard$tables$data$data$instant
  expect_equal(as.numeric(actual), as.numeric(instant))
  expect_identical(attr(actual, "tzone"), "UTC")
  expect_identical(format(actual, "%Y-%m-%d %H:%M:%S", tz = "UTC"), "2026-07-01 10:30:00")
  expect_error(pbi_dashboard("Bad date", data.frame(date = structure(Inf, class = "Date"))), "Infinite dates")
})

test_that("theme and text colors are scalar except categorical palettes", {
  expect_error(pbi_theme(background = c("#112233", "#223344")), "single")
  expect_error(pbi_theme(accent = c("#112233", "#223344")), "single")
  expect_error(pbi_text("Hello", color = c("#112233", "#223344")), "single")
  expect_s3_class(pbi_theme(colors = c("#112233", "#223344", "#334455")), "pbi_theme")
})

test_that("quoted model identifiers produce escaped DAX", {
  input <- setNames(data.frame(amount = c(1, 2)), "Value ] gross")
  dashboard <- pbi_data(pbi_dashboard("Quoted"), "O'Brien sales", input)
  dashboard <- pbi_measure(dashboard, "Gross total", table = "O'Brien sales", column = "Value ] gross")
  expect_identical(dashboard$measures[[1L]]$expression, "SUM('O''Brien sales'[Value ]] gross])")
  expect_identical(names(dashboard$tables[[1L]]$columns), "Value ] gross")
})
