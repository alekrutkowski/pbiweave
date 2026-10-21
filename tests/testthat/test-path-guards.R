# Regression for Windows file-path canonicalization. pbi_compile() writes a
# .gitignore file and pbi_check(verify_hashes=TRUE) examines that path before
# any optional ZIP is created. The leaf file need not normalize to the same
# textual spelling as its directory on Windows.

test_that("dotfiles and nested entries pass the project boundary check", {
  root <- tempfile("pbi path with spaces ")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("build cache", file.path(root, ".gitignore"))
  dir.create(file.path(root, "subdir"))
  writeLines("hello", file.path(root, "subdir", "record.json"))
  normal <- normalizePath(root, winslash = "/", mustWork = TRUE)
  expect_identical(project_child(root, ".gitignore"), file.path(normal, ".gitignore"))
  expect_identical(project_child(root, "subdir/record.json"),
                   file.path(normal, "subdir/record.json"))
  expect_error(project_child(root, "missing.file"), "Missing project path")
  for (candidate in c("../secret", ".", "..", "./.gitignore", "subdir/../.gitignore",
                      "/tmp/file", "C:/outside", "subdir\\record.json")) {
    expect_error(project_child(root, candidate), "Unsafe relative project path",
                 info = candidate)
  }
})

test_that("real symlink leaves and directory escapes are rejected", {
  skip_on_os("windows")  # Sys.readlink() does not expose Windows reparse points.
  root <- tempfile("pbi-root-"); dir.create(root)
  other <- tempfile("pbi-outside-"); dir.create(other)
  on.exit({
    unlink(root, recursive = TRUE)
    unlink(other, recursive = TRUE)
  }, add = TRUE)
  writeLines("never bundle this", file.path(other, "private.json"))
  leaf <- file.path(root, "external.json")
  dirlink <- file.path(root, "otherdir")
  skip_if_not(isTRUE(file.symlink(file.path(other, "private.json"), leaf)))
  skip_if_not(isTRUE(file.symlink(other, dirlink)))
  expect_error(project_child(root, "external.json"), "symlinked")
  expect_error(project_child(root, "otherdir/private.json"), "escapes")
})

test_that("new TMDL project ZIP includes .gitignore after hash verification", {
  root <- tempfile("pbiweave-bundle-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dashboard <- pbi_dashboard("Regression", data.frame(group = c("A", "B"), sales = c(10, 20))) %>%
    pbi_page("Overview", pbi_bar("group", "sales"), pbi_card("sales"))
  project <- pbi_compile(dashboard, file.path(root, "Dashboard with spaces"), bundle = TRUE)
  expect_identical(project$model_format, "tmdl")
  expect_true(pbi_check(project, verify_hashes = TRUE)$valid)
  expect_true(".gitignore" %in% zip::zip_list(project$bundle)$filename)
  expect_true("FIRST-OPEN.md" %in% zip::zip_list(project$bundle)$filename)
})
