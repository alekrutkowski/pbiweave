# Run after installing pbiweave. No Desktop process is started.
library(pbiweave)
output_dir <- Sys.getenv("PBIWEAVE_EXAMPLE_DIR", unset = tempfile("pbiweave-examples-"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
example_ids <- c("quickstart", "typed", "themes", "grid", "sidebar", "focus", "free",
                 "measures", "star", "time", "filters", "scatter", "tables", "gallery",
                 "types", "showcase", "shiny")
projects <- setNames(lapply(example_ids, function(id) {
  specification <- pbi_example(id)
  setNames(lapply(c("tmdl", "tmsl"), function(format) {
    result <- pbi_compile(specification, file.path(output_dir, paste0(id, "-", format)),
                          model_format = format, bundle = TRUE)
    stopifnot(pbi_check(result, verify_hashes = TRUE)$valid)
    result
  }), c("tmdl", "tmsl"))
}), example_ids)
message("Created ", length(projects) * 2L, " source projects in: ", output_dir)
message("Native acceptance remains: open, Home -> Refresh, inspect, Save As PBIX.")
