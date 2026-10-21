# TMDL serialization of the SAME validated intermediate model as TMSL.
# Language reference and Microsoft sample are listed in inst/COMPATIBILITY.md.

tmdl_name <- function(x) {
  object_name(x, "TMDL object name")
  paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
}

tmdl_text <- function(x) {
  scalar_string(x, "TMDL property", empty = TRUE)
  if (grepl("[\r\n]", x)) abort("A TMDL text property cannot contain line breaks. Use model_format = 'tmsl' or remove the line break.")
  paste0('"', gsub('"', '""', x, fixed = TRUE), '"')
}

text_lines <- function(x) {
  x <- gsub("\r\n?", "\n", paste(unlist(x, use.names = FALSE), collapse = "\n"))
  result <- strsplit(paste0(x, "\n."), "\n", fixed = TRUE)[[1L]]
  result[-length(result)]
}

tmdl_description <- function(x, indent = "") {
  if (is.null(x) || !nzchar(x)) return(character())
  paste0(indent, "/// ", text_lines(x))
}

tmdl_expression <- function(header, expression, indent) {
  lines <- text_lines(expression)
  if (any(grepl("^[[:space:]]*```[[:space:]]*$", lines)))
    abort("An expression contains a standalone TMDL fence. Use model_format = 'tmsl' for this expression.")
  # Fences preserve expression indentation and whitespace; the closing fence
  # establishes the left boundary. Do not interpret M or DAX inside this block.
  c(paste0(header, " = ```"), paste0(indent, lines), paste0(indent, "```"))
}

tmdl_annotations <- function(annotations, indent = "") {
  unlist(lapply(annotations, function(a) {
    tmdl_expression(paste0(indent, "annotation ", tmdl_name(a$name)), a$value,
                    paste0(indent, "\t\t"))
  }), use.names = FALSE)
}

tmdl_column <- function(col) {
  props <- c(paste0("\t\tdataType: ", col$dataType),
             paste0("\t\tlineageTag: ", col$lineageTag),
             paste0("\t\tsourceColumn: ", tmdl_text(col$sourceColumn)),
             paste0("\t\tsummarizeBy: ", col$summarizeBy))
  if (!is.null(col$formatString)) props <- c(props, paste0("\t\tformatString: ", tmdl_text(col$formatString)))
  if (!is.null(col$sortByColumn)) props <- c(props, paste0("\t\tsortByColumn: ", tmdl_name(col$sortByColumn)))
  if (!is.null(col$dataCategory)) props <- c(props, paste0("\t\tdataCategory: ", tmdl_text(col$dataCategory)))
  if (isTRUE(col$isHidden)) props <- c(props, "\t\tisHidden")
  if (isTRUE(col$isKey)) props <- c(props, "\t\tisKey")
  c(tmdl_description(col$description, "\t"), paste0("\tcolumn ", tmdl_name(col$name)),
    props, tmdl_annotations(col$annotations, "\t\t"), "")
}

tmdl_measure <- function(measure) {
  result <- c(tmdl_description(measure$description, "\t"),
    tmdl_expression(paste0("\tmeasure ", tmdl_name(measure$name)), measure$expression, "\t\t\t"),
    paste0("\t\tlineageTag: ", measure$lineageTag))
  if (!is.null(measure$formatString))
    result <- c(result, paste0("\t\tformatString: ", tmdl_text(measure$formatString)))
  c(result, "")
}

tmdl_table <- function(table) {
  result <- c(tmdl_description(table$description), paste0("table ", tmdl_name(table$name)),
              paste0("\tlineageTag: ", table$lineageTag))
  if (isTRUE(table$isHidden)) result <- c(result, "\tisHidden")
  if (!is.null(table$dataCategory)) result <- c(result, paste0("\tdataCategory: ", tmdl_text(table$dataCategory)))
  c(result, "", unlist(lapply(table$columns, tmdl_column), use.names = FALSE),
    unlist(lapply(table$measures, tmdl_measure), use.names = FALSE),
    unlist(lapply(table$partitions, function(p) c(
      paste0("\tpartition ", tmdl_name(p$name), " = m"),
      paste0("\t\tmode: ", p$mode),
      tmdl_expression("\t\tsource", p$source$expression, "\t\t\t"), "")), use.names = FALSE),
    tmdl_annotations(table$annotations, "\t"))
}

tmdl_table_file <- function(name, i) {
  slug <- substr(gsub("[^A-Za-z0-9_-]", "-", name), 1L, 55L)
  paste0(sprintf("%03d-", i), slug, ".tmdl")
}

write_tmdl <- function(definition, path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  model <- definition$model
  write_utf8(c(paste0("database ", tmdl_name(definition$name)),
    paste0("\tcompatibilityLevel: ", definition$compatibilityLevel)), file.path(path, "database.tmdl"))
  write_utf8(c("model Model", paste0("\tculture: ", tmdl_text(model$culture)),
    paste0("\tsourceQueryCulture: ", tmdl_text(model$sourceQueryCulture)),
    paste0("\tdefaultPowerBIDataSourceVersion: ", model$defaultPowerBIDataSourceVersion),
    "\tdataAccessOptions", "\t\tlegacyRedirects", "\t\treturnErrorValuesAsNull", "",
    tmdl_annotations(model$annotations), "",
    vapply(model$tables, function(t) paste0("ref table ", tmdl_name(t$name)), character(1))),
    file.path(path, "model.tmdl"))
  invisible(lapply(seq_along(model$tables), function(i) {
    t <- model$tables[[i]]
    write_utf8(tmdl_table(t), file.path(path, "tables", tmdl_table_file(t$name, i)))
  }))
  if (length(model$relationships)) {
    lines <- unlist(lapply(model$relationships, function(r) c(
      paste0("relationship ", tmdl_name(r$name)),
      paste0("\tfromColumn: ", tmdl_name(r$fromTable), ".", tmdl_name(r$fromColumn)),
      paste0("\ttoColumn: ", tmdl_name(r$toTable), ".", tmdl_name(r$toColumn)),
      paste0("\tfromCardinality: ", r$fromCardinality),
      paste0("\ttoCardinality: ", r$toCardinality),
      paste0("\tcrossFilteringBehavior: ", r$crossFilteringBehavior),
      paste0("\tisActive: ", tolower(as.character(r$isActive))), "")), use.names = FALSE)
    write_utf8(lines, file.path(path, "relationships.tmdl"))
  }
  invisible(path)
}
