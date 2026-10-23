# Regenerate the standalone theme from the current repository source.
# This uses the same constructor and serializer as pbi_compile().
# Run from the repository root after installing its Imports.
if (!file.exists("DESCRIPTION") || !dir.exists("R"))
  stop("Run from the pbiweave repository root.")
theme_source <- new.env(parent = globalenv())
invisible(lapply(c("helpers.R", "spec.R", "report.R"), function(file)
  sys.source(file.path("R", file), envir = theme_source)))
theme_source$write_json(
  theme_source$compile_theme(theme_source$pbi_theme("european_commission")),
  file.path("inst", "themes", "european-commission.json")
)
message("Updated inst/themes/european-commission.json from pbi_theme().")
