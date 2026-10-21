model_fixture <- function() {
  columns <- list(
    text = list(name = "text", type = "string", hidden = FALSE),
    value = list(name = "value", type = "double", hidden = FALSE),
    flag = list(name = "flag", type = "boolean", hidden = FALSE),
    day = list(name = "day", type = "date", hidden = FALSE),
    instant = list(name = "instant", type = "dateTime", hidden = FALSE),
    large_id = list(name = "large_id", type = "int64", hidden = TRUE))
  list(name = "Observations", columns = columns, date_table = FALSE,
       data = data.table::data.table(
         text = c('Łódź "quoted"\nline', "", NA_character_),
         value = c(1.2345678901234567, 0, NA_real_),
         flag = c(TRUE, FALSE, NA),
         day = as.Date(c("2026-01-01", "2026-01-02", NA_character_)),
         instant = as.POSIXct(c("2026-01-01 12:34:56", "2026-01-02 23:59:59", NA_character_), tz = "UTC"),
         large_id = c("9007199254740993", "9223372036854775807", NA_character_)))
}

decode_model_payload <- function(expression, compressed = TRUE) {
  chunk <- strsplit(expression, "Text.Combine({", fixed = TRUE)[[1L]][[2L]]
  chunk <- strsplit(chunk, "}),", fixed = TRUE)[[1L]][[1L]]
  payload <- gsub('["[:space:],]', "", chunk)
  raw <- base64enc::base64decode(payload)
  if (compressed) raw <- memDecompress(raw, type = "gzip")
  jsonlite::fromJSON(rawToChar(raw), simplifyVector = FALSE)
}

test_that("embedded gzip payloads retain values, nulls, dates, UTC and large integer text", {
  tab <- model_fixture()
  expression <- pbiweave:::embedded_m(tab)
  rows <- decode_model_payload(expression)
  expect_length(rows, 3L)
  expect_identical(rows[[1L]][[1L]], tab$data$text[[1L]])
  expect_equal(rows[[1L]][[2L]], tab$data$value[[1L]], tolerance = 1e-15)
  expect_identical(rows[[1L]][[3L]], TRUE)
  expect_identical(rows[[1L]][[4L]], "2026-01-01")
  expect_match(rows[[1L]][[5L]], "^2026-01-01T12:34:56")
  expect_identical(rows[[1L]][[6L]], "9007199254740993")
  expect_identical(rows[[2L]][[6L]], "9223372036854775807")
  expect_true(all(vapply(rows[[3L]], is.null, logical(1L))))
  expect_match(expression, "Compression.GZip", fixed = TRUE)
  expect_match(expression, '{"large_id", Int64.Type}', fixed = TRUE)
  expect_false(grepl("File.Contents|Web.Contents|R.Execute", expression))
  expect_identical(expression, pbiweave:::embedded_m(tab))
})

test_that("raw and compressed modes carry equivalent typed JSON", {
  tab <- model_fixture()
  expect_identical(decode_model_payload(pbiweave:::embedded_m(tab, FALSE), FALSE),
                   decode_model_payload(pbiweave:::embedded_m(tab, TRUE), TRUE))
  empty <- tab
  empty$data <- empty$data[0L]
  expect_identical(decode_model_payload(pbiweave:::embedded_m(empty)), list())
})

test_that("payloads are split into manageable M string literals", {
  tab <- model_fixture()
  tab$data$text[[1L]] <- paste(rep("long embedded snapshot ", 3000L), collapse = "")
  expression <- pbiweave:::embedded_m(tab, compression = FALSE)
  payload <- strsplit(expression, "Text.Combine({", fixed = TRUE)[[1L]][[2L]]
  payload <- strsplit(payload, "}),", fixed = TRUE)[[1L]][[1L]]
  chunks <- regmatches(payload, gregexpr('[A-Za-z0-9+/=]+', payload))[[1L]]
  expect_gt(length(chunks), 1L)
  expect_true(all(nchar(chunks) <= 24000L))
  expect_identical(decode_model_payload(expression, FALSE)[[1L]][[1L]], tab$data$text[[1L]])
})

test_that("M strings quote user text without interpreting escape sequences", {
  expect_identical(pbiweave:::model_m_string('a"b#(lf)\n\t'),
                   '"a""b#(#)(lf)#(lf)#(tab)"')
})

test_that("compiled semantic models define real Import partitions and relationships", {
  tab <- model_fixture()
  tab$columns$text$sort_by <- "value"
  model <- list(title = "Study", locale = "en-US", tables = list(Observations = tab),
                measures = list(list(name = "Total", table = "Observations",
                                     expression = "SUM('Observations'[value])", format = "#,0.00")),
                relationships = list(list(name = "r1", from_table = "Observations",
                                          from_column = "large_id", to_table = "Dim",
                                          to_column = "id", active = TRUE,
                                          cross_filter = "oneDirection")))
  out <- tempfile("pbiweave-model-")
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  pbiweave:::compile_model(model, out)
  definition <- jsonlite::read_json(file.path(out, "definition.pbism"))
  bim <- jsonlite::read_json(file.path(out, "model.bim"))
  expect_identical(definition$version, "5.0")
  expect_identical(bim$compatibilityLevel, 1702L)
  expect_identical(bim$model$defaultPowerBIDataSourceVersion, "powerBI_V3")
  expect_identical(bim$model$tables[[1L]]$partitions[[1L]]$mode, "import")
  expect_identical(bim$model$tables[[1L]]$partitions[[1L]]$source$type, "m")
  expect_identical(bim$model$tables[[1L]]$columns[[1L]]$sortByColumn, "value")
  expect_identical(bim$model$tables[[1L]]$columns[[4L]]$dataType, "dateTime")
  expect_identical(bim$model$tables[[1L]]$measures[[1L]]$expression,
                   "SUM('Observations'[value])")
  expect_identical(bim$model$relationships[[1L]]$fromCardinality, "many")
  expect_identical(bim$model$relationships[[1L]]$toCardinality, "one")
})

test_that("date tables mark one date key and preserve column format and visibility", {
  tab <- model_fixture()
  tab$date_table <- TRUE
  tab$columns$day$format <- "dd mmm yyyy"
  result <- pbiweave:::model_table(tab, list(), TRUE)
  expect_identical(result$dataCategory, "Time")
  expect_true(result$columns[[4L]]$isKey)
  expect_identical(result$columns[[4L]]$formatString, "dd mmm yyyy")
  expect_true(result$columns[[6L]]$isHidden)
  expect_true(all(vapply(result$columns, function(x) identical(x$summarizeBy, "none"), logical(1L))))
})
