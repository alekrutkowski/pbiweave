# European Commission theme sampler, using fictional built-in sales data.
# These values are illustrative and are not European Commission statistics.
# Run after installing pbiweave. No data or font files are downloaded.
library(pbiweave)

ec_report <- pbi_dashboard(
  "European Commission theme sampler", pbi_demo_data(),
  theme = "european_commission"
) %>%
  pbi_page("Illustrative overview",
    pbi_card("revenue", title = "Illustrative revenue", id = "total"),
    pbi_slicer("product", title = "Product", sync = "Product", id = "product"),
    pbi_bar("product", "revenue", title = "Revenue by product", labels = TRUE,
            alt = "Illustrative revenue for four fictional products", id = "products"),
    pbi_line("date", "revenue", legend = "region", title = "Monthly revenue",
             alt = "Illustrative monthly revenue by fictional region", id = "trend"),
    layout = pbi_layout(columns = 2, header = 56)) %>%
  pbi_page("Illustrative detail",
    pbi_text("Fictional data supplied with pbiweave.\nThis report demonstrates the theme only.",
             font_size = 16, id = "note"),
    pbi_slicer("product", title = "Product", sync = "Product", id = "product"),
    pbi_table(c("date", "region", "product", "revenue", "units"),
              title = "Fictional sales records", id = "records") %>%
      pbi_span(columns = 2),
    layout = pbi_layout(columns = 2, header = 56))

ec_output_dir <- Sys.getenv("PBIWEAVE_EXAMPLE_DIR", unset = tempfile("pbiweave-ec-"))
dir.create(ec_output_dir, recursive = TRUE, showWarnings = FALSE)
ec_projects <- setNames(lapply(c("tmdl", "tmsl"), function(format) {
  result <- pbi_compile(ec_report,
    file.path(ec_output_dir, paste0("european-commission-", format)),
    model_format = format, bundle = TRUE)
  stopifnot(pbi_check(result, verify_hashes = TRUE)$valid)
  result
}), c("tmdl", "tmsl"))
message("Created European Commission theme examples in: ", ec_output_dir)
message("Open a PBIP in Power BI Desktop, select Home > Refresh, then inspect the theme.")
