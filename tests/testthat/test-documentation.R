test_that("every public function has a call in README R examples", {
  readme <- system.file("doc", "README.md", package = "pbiweave")
  if (!nzchar(readme)) readme <- test_path("..", "..", "README.md")
  text <- paste(readLines(readme, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  blocks <- regmatches(text, gregexpr("(?s)```r\n.*?```", text, perl = TRUE))[[1L]]
  code <- lapply(blocks, function(b) sub("```$", "", sub("^```r\n", "", b)))
  parsed <- lapply(code, function(s) parse(text = s))
  calls <- unique(unlist(lapply(parsed, all.names, functions = TRUE)))
  expect_setequal(intersect(getNamespaceExports("pbiweave"), calls), getNamespaceExports("pbiweave"))
  expect_match(toupper(substr(text, 1, 1500)), "HOME", fixed = TRUE)
  expect_match(substr(text, 1, 1500), "Refresh", fixed = TRUE)
})
