fixture_dashboard <- function() pbi_dashboard("Portable report", data.frame(
  category = c("North", "South"), amount = c(10, 20))) %>%
  pbi_page("Overview", pbi_bar("category", "amount"), pbi_card("amount"))

test_that("a portable project compiles and bundles with valid links", {
  root <- tempfile("pbiweave-test-"); dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  result <- pbi_compile(fixture_dashboard(), file.path(root, "portable"), bundle = TRUE)
  expect_s3_class(result, "pbi_project")
  expect_true(file.exists(result$pbip))
  expect_true(pbi_check(result)$valid)
  members <- zip::zip_list(result$bundle)$filename
  expect_true("portable.pbip" %in% members)
  expect_true(any(grepl("model.bim$", members)))
  expect_false(any(grepl("^/|^\\.\\./", members)))
  extracted <- file.path(root, "extracted")
  zip::unzip(result$bundle, exdir = extracted)
  expect_true(pbi_check(extracted)$valid)
  manifest <- jsonlite::fromJSON(file.path(result$path, "pbiweave.json"))
  expect_true(manifest$requiresDesktopRefresh)
  expect_true(manifest$requiresDesktopSaveForPBIX)
  expect_identical(manifest$tables$rows, c(2L))
})

test_that("transactional overwrite protects unrelated files and invalid specifications", {
  root <- tempfile("pbiweave-test-"); dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dest <- file.path(root, "existing"); dir.create(dest)
  writeLines("keep", file.path(dest, "mine.txt"))
  expect_error(pbi_compile(fixture_dashboard(), dest, overwrite = TRUE), "non-pbiweave")
  expect_identical(readLines(file.path(dest, "mine.txt")), "keep")
  dest <- file.path(root, "report")
  out <- pbi_compile(fixture_dashboard(), dest)
  before <- tools::md5sum(out$pbip)
  bad <- fixture_dashboard(); bad$pages[[1]]$visuals[[1]]$fields$x <- "missing"
  expect_error(pbi_compile(bad, dest, overwrite = TRUE), "Unknown")
  expect_identical(tools::md5sum(out$pbip), before)
  expect_error(pbi_compile(fixture_dashboard(), dest), "exists")
  expect_s3_class(pbi_compile(fixture_dashboard(), dest, overwrite = TRUE), "pbi_project")
  expect_error(pbi_compile(fixture_dashboard(), file.path(root, "fake.pbix")), "Desktop")
})

test_that("identical builds produce identical project bytes", {
  root <- tempfile("pbiweave-test-"); dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  out <- pbi_compile(fixture_dashboard(), file.path(root, "stable"))
  files <- list.files(out$path, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  before <- tools::md5sum(files)
  pbi_compile(fixture_dashboard(), out$path, overwrite = TRUE)
  expect_identical(tools::md5sum(files), before)
  writeLines("bad json", file.path(out$report, "definition", "report.json"))
  expect_false(pbi_check(out, stop_on_error = FALSE)$valid)
})
