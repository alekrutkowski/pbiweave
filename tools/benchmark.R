# Compiler benchmark only. This does not measure Power BI refresh or rendering.
library(pbiweave)
library(data.table)

rows <- as.integer(Sys.getenv("PBIWEAVE_BENCHMARK_ROWS", "100000"))
out <- Sys.getenv("PBIWEAVE_BENCHMARK_DIR", file.path(tempdir(), "pbiweave-benchmark"))
index <- seq_len(rows)
input <- data.table(
  id = index,
  date = as.Date("2025-01-01") + (index %% 365L),
  region = c("North", "Central", "South")[index %% 3L + 1L],
  value = (index %% 9877L) / 100,
  active = index %% 7L != 0L
)
report <- pbi_dashboard("Compiler benchmark", input) %>%
  pbi_page("Overview", pbi_card("value"), pbi_bar("region", "value"),
           pbi_line("date", "value"), pbi_slicer("region"))
timing <- system.time(project <- pbi_compile(report, out, overwrite = TRUE, bundle = TRUE))
files <- list.files(project$path, recursive = TRUE, full.names = TRUE, all.files = TRUE)
result <- list(rows = rows, columns = ncol(input), elapsed_seconds = unname(timing[["elapsed"]]),
  project_bytes = sum(file.info(files)$size), zip_bytes = unname(file.info(project$bundle)$size),
  R = R.version.string, platform = R.version$platform,
  scope = "One local R compilation and ZIP; excludes Power BI engine, refresh and rendering")
cat(jsonlite::toJSON(result, pretty = TRUE, auto_unbox = TRUE), "\n")
