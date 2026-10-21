# Run from an extracted SOURCE REPOSITORY after installing pbiweave.
# This script performs R gates when actually executed. No result is prefilled.
args <- commandArgs(trailingOnly = TRUE)
if (any(!args %in% "--flights")) stop("Supported option: --flights")
library(pbiweave)
library(data.table)
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
if (!file.exists("DESCRIPTION") || !dir.exists("R") || !file.exists("tools/verify-readme-coverage.R"))
  stop("Run from the extracted repository root.")
if (as.character(packageVersion("pbiweave")) != "0.3.1") stop("Install and load 0.3.1 before this gate.")
if (dir.exists("build/examples") || dir.exists("build/tutorials"))
  stop("Choose a fresh checkout or move old build/examples and build/tutorials aside; results must be fresh.")
dir.create("build", showWarnings = FALSE)
# Use R itself, rather than a lexical approximation, to parse the source and help-example code.
invisible(lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), parse))
source("tools/verify-readme-coverage.R", local = new.env(parent = globalenv()))
testthat::test_local(root, reporter = "summary", stop_on_failure = TRUE)
# Run all installed help examples. Constructors clean their temporary projects.
invisible(lapply(getNamespaceExports("pbiweave"), function(name)
  utils::example(name, package = "pbiweave", ask = FALSE, echo = FALSE, run.dontrun = FALSE)))
Sys.setenv(PBIWEAVE_EXAMPLE_DIR = file.path(root, "build", "examples"))
source("inst/examples/run-all.R", local = new.env(parent = globalenv()))
if ("--flights" %in% args) {
  if (!requireNamespace("nycflights13", quietly = TRUE)) stop("Install nycflights13 for --flights.")
  dir.create("build/tutorials", recursive = TRUE)
  run_tutorial <- function(name) {
    old <- setwd(file.path(root, "build/tutorials")); on.exit(setwd(old), add = TRUE)
    source(file.path(root, "inst", "examples", name), local = new.env(parent = globalenv()))
  }
  invisible(lapply(c("01-flights-beginner.R", "02-flights-three-frames.R"), run_tutorial))
}
result <- list(package = "pbiweave", version = as.character(packageVersion("pbiweave")),
  R = R.version.string, platform = R.version$platform,
  R_tests_and_help_examples_completed = TRUE, built_in_projects = 34L,
  flight_tutorials_completed = "--flights" %in% args,
  native_TMDL_parser_executed = FALSE, M_DAX_executed = FALSE, Desktop_rendered = FALSE)
writeLines(jsonlite::toJSON(result, pretty = TRUE, auto_unbox = TRUE), "build/R-acceptance.json")
message("R gates completed. Run the offline schema validator, native TOM gate and Desktop checklist separately.")
