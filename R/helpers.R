# Pipe a value into the next operation
#
# Re-exported from magrittr for fluent report declarations.
# @name %>%
# @rdname pipe
# @importFrom magrittr %>%
# @export
NULL

# data.table is called with :: rather than imported wholesale. Declare that
# package-internal bracket expressions intentionally use data.table semantics.
.datatable.aware <- TRUE

abort <- function(..., call. = FALSE) stop(..., call. = call.)
`%||%` <- function(x, y) if (is.null(x)) y else x
compact <- function(x) x[!vapply(x, is.null, logical(1))]
json_object <- function() structure(list(), names = character())
stable_id <- function(text) digest::digest(enc2utf8(text), algo = "xxhash64", serialize = FALSE)
visual_id <- function(page_index, visual_index) sprintf("v%03d_%03d", page_index, visual_index)

scalar_string <- function(x, label, empty = FALSE) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || (!empty && !nzchar(x)))
    abort(label, " must be a single non-missing string.")
  invisible(x)
}
object_name <- function(x, label) {
  scalar_string(x, label)
  if (grepl("[[:cntrl:]]", x) || trimws(x) != x)
    abort(label, " cannot contain control characters or surrounding whitespace.")
  invisible(x)
}
scalar_flag <- function(x, label) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) abort(label, " must be TRUE or FALSE.")
  invisible(x)
}
number <- function(x, label, lower = -Inf, upper = Inf, whole = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < lower || x > upper ||
      (whole && x != floor(x))) abort(label, " must be a finite ",
      if (whole) "integer" else "number", " in [", lower, ", ", upper, "].")
  invisible(x)
}
color_check <- function(x, label = "color") {
  if (!is.character(x) || !length(x) || anyNA(x) || any(!grepl("^#[0-9A-Fa-f]{6}$", x)))
    abort(label, " must contain #RRGGBB hexadecimal colors.")
  invisible(x)
}
assert_dashboard <- function(x) {
  if (!inherits(x, "pbi_dashboard")) abort("Expected a pbi_dashboard object.")
  invisible(x)
}
assert_visual <- function(x) {
  if (!inherits(x, "pbi_visual")) abort("Expected a pbi_visual object.")
  invisible(x)
}
unique_names <- function(x, label) {
  invisible(lapply(x, object_name, label = label))
  if (anyDuplicated(tolower(x))) abort(label, " must be unique, ignoring case.")
}
named_options <- function(x, cols, label) {
  if (is.null(x)) return(invisible(NULL))
  if (is.null(names(x)) || any(!nzchar(names(x))) || anyDuplicated(tolower(names(x))) ||
      any(!names(x) %in% cols)) abort(label, " must be named using existing column names.")
  invisible(x)
}
write_json <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  txt <- jsonlite::toJSON(object, auto_unbox = TRUE, pretty = TRUE, null = "null",
                          na = "null", digits = 17L, force = TRUE)
  con <- file(path, "wb")
  on.exit(close(con))
  writeBin(charToRaw(paste0(enc2utf8(txt), "\n")), con)
  invisible(path)
}
write_utf8 <- function(text, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "wb")
  on.exit(close(con))
  writeBin(charToRaw(paste0(paste(enc2utf8(text), collapse = "\n"), "\n")), con)
  invisible(path)
}
field_list <- function(x) {
  if (is.null(x)) return(list())
  if (inherits(x, "pbi_field")) return(list(x))
  if (is.character(x)) return(as.list(x))
  if (is.list(x)) return(x)
  abort("Fields must be strings, pbi_field()/pbi_ref() objects, or a list of these.")
}
dax_table <- function(x) paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
dax_column <- function(table, column) paste0(dax_table(table), "[", gsub("]", "]]", column, fixed = TRUE), "]")

resolve_field <- function(dashboard, field, table = NULL, aggregate = NULL) {
  if (is.character(field)) {
    scalar_string(field, "field")
    field <- list(name = field, table = NULL, kind = "auto", aggregate = NULL)
  }
  if (!is.list(field) || is.null(field$name)) abort("Invalid field reference.")
  table <- field$table %||% table %||% names(dashboard$tables)[1L]
  if (!length(table) || is.na(table) || !table %in% names(dashboard$tables))
    abort("Unknown table: ", table %||% "<none>", ". Add data with pbi_data().")
  name <- field$name
  kind <- field$kind %||% "column"
  column <- dashboard$tables[[table]]$columns[[name]]
  if (kind != "measure" && !is.null(column)) {
    agg <- field$aggregate %||% aggregate
    if (identical(agg, "none")) agg <- NULL
    if (!is.null(agg) && !agg %in% c("sum", "average", "min", "max", "count", "distinct_count"))
      abort("Unknown aggregation: ", agg)
    if (!is.null(agg) && agg %in% c("sum", "average") && !column$type %in% c("int64", "double", "decimal"))
      abort("Cannot ", agg, " non-numeric column ", table, "[", name, "]. Use count or distinct_count.")
    return(list(name = name, table = table, kind = "column", aggregate = agg, type = column$type,
      label = field$label, format = field$format %||% column$format))
  }
  candidates <- Filter(function(m) identical(m$name, name) &&
    (is.null(field$table) || identical(m$table, field$table)), dashboard$measures)
  if (kind != "column" && length(candidates) == 1L)
    return(list(name = name, table = candidates[[1L]]$table, kind = "measure", aggregate = NULL, type = "double",
      label = field$label, format = field$format %||% candidates[[1L]]$format))
  abort("Unknown ", if (kind == "measure") "measure" else "field", ": ", table, "[", name, "].")
}
