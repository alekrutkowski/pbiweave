# Power BI enhanced-metadata import models with portable, inline source data.
# TMSL structure follows Microsoft's semantic-model-definition documentation.

model_m_string <- function(x) {
  x <- enc2utf8(x)
  x <- gsub("#", "#(#)", x, fixed = TRUE)
  x <- gsub('"', '""', x, fixed = TRUE)
  x <- gsub("\r", "#(cr)", x, fixed = TRUE)
  x <- gsub("\n", "#(lf)", x, fixed = TRUE)
  x <- gsub("\t", "#(tab)", x, fixed = TRUE)
  paste0('"', x, '"')
}

model_lineage <- function(...) {
  h <- digest::digest(paste(..., collapse = "\037"),
                      algo = "md5", serialize = FALSE)
  paste(substr(h, 1L, 8L), substr(h, 9L, 12L), substr(h, 13L, 16L),
        substr(h, 17L, 20L), substr(h, 21L, 32L), sep = "-")
}

# R's memCompress(type = "gzip") produces zlib framing. A gzfile connection
# writes an actual RFC 1952 gzip stream accepted by Compression.GZip in M.
model_gzip <- function(bytes) {
  path <- tempfile("pbiweave-data-", fileext = ".gz")
  on.exit(unlink(path), add = TRUE)
  con <- gzfile(path, open = "wb", compression = 9L)
  tryCatch(writeBin(bytes, con), finally = close(con))
  readBin(path, what = "raw", n = file.info(path)$size)
}

model_json_data <- function(table) {
  values <- lapply(names(table$columns), function(name) {
    x <- table$data[[name]]
    type <- table$columns[[name]]$type
    if (identical(type, "date")) {
      return(format(x, "%Y-%m-%d"))
    }
    if (identical(type, "dateTime")) {
      # The API normalizes POSIXct inputs to UTC. Power BI datetime stores
      # timezone-free instants, so write the UTC wall-clock representation.
      return(format(x, "%Y-%m-%dT%H:%M:%OS6", tz = "UTC", usetz = FALSE))
    }
    x
  })
  names(values) <- names(table$columns)
  values <- data.table::as.data.table(values)
  as.character(jsonlite::toJSON(values, dataframe = "values", na = "null",
                               null = "null", digits = 17L, auto_unbox = TRUE))
}

embedded_m <- function(table, compression = TRUE) {
  bytes <- charToRaw(enc2utf8(model_json_data(table)))
  if (isTRUE(compression)) bytes <- model_gzip(bytes)
  payload <- base64enc::base64encode(bytes)
  starts <- seq.int(1L, max(1L, nchar(payload)), by = 24000L)
  chunks <- substring(payload, starts, starts + 23999L)
  encoded <- paste(model_m_string(chunks), collapse = ",\n        ")
  type_map <- c(string = "type text", int64 = "Int64.Type",
                double = "type number", boolean = "type logical",
                date = "type date", dateTime = "type datetime",
                decimal = "Currency.Type")
  conversions <- vapply(table$columns, function(column) {
    paste0("{", model_m_string(column$name), ", ",
           type_map[[column$type]], "}")
  }, character(1L))
  binary <- if (isTRUE(compression)) {
    "Binary.Decompress(Binary.FromText(Payload, BinaryEncoding.Base64), Compression.GZip)"
  } else {
    "Binary.FromText(Payload, BinaryEncoding.Base64)"
  }
  paste(c("let",
          "    // Portable data snapshot; no file, network or R runtime dependency.",
          paste0("    Payload = Text.Combine({", encoded, "}),"),
          paste0("    Rows = Json.Document(", binary, ", TextEncoding.Utf8),"),
          paste0("    Source = Table.FromRows(Rows, {",
                 paste(model_m_string(names(table$columns)), collapse = ", "), "}),"),
          paste0("    Typed = Table.TransformColumnTypes(Source, {",
                 paste(conversions, collapse = ", "), "}, \"en-US\")"),
          "in", "    Typed"), collapse = "\n")
}

model_column <- function(column, table_name, key = FALSE, date_table = FALSE) {
  type <- column$type
  out <- list(name = column$name,
              dataType = if (identical(type, "date")) "dateTime" else type,
              sourceColumn = column$name,
              summarizeBy = column$summarize %||% if (!date_table && type %in% c("int64", "double", "decimal")) "sum" else "none",
              lineageTag = model_lineage("column", table_name, column$name))
  if (!is.null(column$data_category)) out$dataCategory <- column$data_category
  if (isTRUE(column$hidden)) out$isHidden <- TRUE
  if (isTRUE(key)) out$isKey <- TRUE
  if (!is.null(column$description)) out$description <- column$description
  if (!is.null(column$sort_by)) out$sortByColumn <- column$sort_by
  default_format <- switch(type, int64 = "#,0", decimal = "#,0.0000",
                           date = "yyyy-mm-dd", dateTime = "yyyy-mm-dd hh:nn:ss",
                           NULL)
  format <- if (is.null(column$format)) default_format else column$format
  if (!is.null(format)) out$formatString <- format
  out$annotations <- list(list(name = "SummarizationSetBy", value = "User"))
  if (identical(type, "date")) {
    out$annotations <- c(out$annotations,
                         list(list(name = "UnderlyingDateTimeDataType", value = "Date")))
  }
  out
}

model_measure <- function(measure) {
  out <- list(name = measure$name, expression = measure$expression,
              lineageTag = model_lineage("measure", measure$table, measure$name))
  if (!is.null(measure$format)) out$formatString <- measure$format
  if (!is.null(measure$description)) out$description <- measure$description
  out
}

model_table <- function(table, measures, compression) {
  date_names <- names(Filter(function(x) identical(x$type, "date"), table$columns))
  date_key <- if (isTRUE(table$date_table) && length(date_names)) date_names[[1L]] else ""
  out <- list(name = table$name,
              lineageTag = model_lineage("table", table$name),
              columns = unname(lapply(table$columns, function(column) {
                model_column(column, table$name,
                             key = identical(column$name, date_key),
                             date_table = isTRUE(table$date_table))
              })),
              partitions = list(list(name = table$name, mode = "import",
                                     source = list(type = "m", expression =
                                                     as.list(strsplit(embedded_m(table, compression), "\n", fixed = TRUE)[[1L]])))),
              annotations = list(list(name = "PBI_ResultType", value = "Table"),
                                 list(name = "PBI_NavigationStepName", value = "Typed")))
  if (!is.null(table$description)) out$description <- table$description
  if (isTRUE(table$hidden)) out$isHidden <- TRUE
  if (isTRUE(table$date_table)) out$dataCategory <- "Time"
  home <- Filter(function(x) identical(x$table, table$name), measures)
  if (length(home)) out$measures <- unname(lapply(home, model_measure))
  out
}

model_relationship <- function(relationship) {
  list(name = relationship$name,
       fromTable = relationship$from_table,
       fromColumn = relationship$from_column,
       fromCardinality = "many",
       toTable = relationship$to_table,
       toColumn = relationship$to_column,
       toCardinality = "one",
       isActive = isTRUE(relationship$active),
       crossFilteringBehavior = relationship$cross_filter)
}

model_definition <- function(dashboard, compression = TRUE) {
  model <- list(culture = dashboard$locale,
                sourceQueryCulture = "en-US",
                defaultPowerBIDataSourceVersion = "powerBI_V3",
                dataAccessOptions = list(legacyRedirects = TRUE,
                                         returnErrorValuesAsNull = TRUE),
                tables = unname(lapply(dashboard$tables, model_table,
                                      measures = dashboard$measures,
                                      compression = compression)),
                relationships = unname(lapply(dashboard$relationships, model_relationship)),
                annotations = list(list(name = "__PBI_TimeIntelligenceEnabled", value = "0"),
                                   list(name = "pbiweave_DataMode", value = "Embedded snapshot")))
  list(name = dashboard$title, compatibilityLevel = 1702L, model = model)
}

# Keep the internal legacy helper default for old unit tests; pbi_compile()
# explicitly passes its new TMDL default.
compile_model <- function(dashboard, model_dir, compression = TRUE, model_format = "tmsl") {
  model_format <- match.arg(model_format, c("tmdl", "tmsl"))
  definition <- model_definition(dashboard, compression)
  dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)
  if (model_format == "tmdl") {
    if (file.exists(file.path(model_dir, "model.bim"))) abort("Do not mix TMDL and TMSL in one model folder.")
    write_tmdl(definition, file.path(model_dir, "definition"))
  } else {
    if (dir.exists(file.path(model_dir, "definition"))) abort("Do not mix TMDL and TMSL in one model folder.")
    write_json(definition, file.path(model_dir, "model.bim"))
  }
  write_json(list(`$schema` = paste0("https://developer.microsoft.com/json-schemas/",
                                    "fabric/item/semanticModel/definitionProperties/1.0.0/schema.json"),
                  version = "5.0", settings = list(qnaEnabled = FALSE)),
             file.path(model_dir, "definition.pbism"))
  invisible(list(format = toupper(model_format), compatibility_level = 1702L,
                 source = "inline-json", compression = if (compression) "gzip" else "none",
                 table_count = length(definition$model$tables)))
}
