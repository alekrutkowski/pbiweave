new_visual <- function(type, fields = list(), table = NULL, title = NULL, alt = NULL,
                       aggregate = "sum", options = list()) {
  if (!is.null(table)) object_name(table, "table")
  if (!is.null(title)) scalar_string(title, "title", empty = TRUE)
  if (!is.null(alt)) scalar_string(alt, "alt", empty = TRUE)
  aggregate <- canonical_aggregate(aggregate)
  structure(list(type = type, fields = compact(fields), table = table, title = title, alt = alt,
    aggregate = aggregate, options = options, filters = list(), sort = NULL,
    span = c(columns = 1, rows = 1), position = NULL), class = "pbi_visual")
}

# Native interactive Power BI visuals
#
# Supply column names as strings. Explicit pbi_field references select another
# table or aggregation; pbi_ref selects a DAX measure. Numeric values default
# to sum, while axes and legends remain unaggregated. All charts use Power BI
# native queries and participate in native slicer and selection interactions.
# @param x,y Category/numeric fields; scatter uses numeric x and y.
# @param legend Optional series field.
# @param table Optional default table.
# @param title,alt Optional title and accessibility description.
# @param aggregate Default aggregation for numeric bindings.
# @param horizontal Draw horizontal bars.
# @param stacked Stack bars/areas instead of clustering.
# @param percent Use 100 percent stacking, implying stacked=TRUE.
# @param labels Show data labels.
# @param tooltip Optional additional fields in tooltips.
# @param size Optional numeric scatter size field.
# @param details Optional scatter observation identifier.
# @param value Numeric field or measure for a card or gauge.
# @param target,min,max Optional gauge bindings.
# @param columns Table fields, or matrix column categories.
# @param rows,values Matrix row categories and numeric values.
# @param field Slicer column.
# @param style Slicer dropdown, list, or between.
# @param single_select Restrict slicer to one selection.
# @param sync Optional named slicer synchronization group across pages.
# @param text Text box content, with newlines supported.
# @param font_size,color Optional text appearance.
# @return A pbi_visual specification.
# @export
pbi_bar <- function(x, y, legend = NULL, table = NULL, title = NULL, alt = NULL,
                    aggregate = "sum", horizontal = FALSE, stacked = FALSE,
                    percent = FALSE, labels = FALSE, tooltip = NULL,
                     id = NULL, series = NULL) {
  if (!is.null(series)) {
    if (!is.null(legend)) abort("Use legend or series, not both.")
    legend <- series
  }
  out <- {
  invisible(lapply(list(horizontal = horizontal, stacked = stacked, percent = percent, labels = labels), scalar_flag, label = "Chart flags"))
  new_visual("bar", list(x = x, y = y, legend = legend, tooltip = tooltip), table, title, alt, aggregate,
             list(horizontal = horizontal, stacked = stacked || percent, percent = percent, labels = labels))
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_line <- function(x, y, legend = NULL, table = NULL, title = NULL, alt = NULL,
                     aggregate = "sum", labels = FALSE, tooltip = NULL,
                     id = NULL, series = NULL) {
  if (!is.null(series)) {
    if (!is.null(legend)) abort("Use legend or series, not both.")
    legend <- series
  }
  out <- {
  scalar_flag(labels, "labels")
  new_visual("line", list(x = x, y = y, legend = legend, tooltip = tooltip), table, title, alt, aggregate, list(labels = labels))
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_area <- function(x, y, legend = NULL, table = NULL, title = NULL, alt = NULL,
                     aggregate = "sum", stacked = FALSE, labels = FALSE, tooltip = NULL,
                     id = NULL, series = NULL) {
  if (!is.null(series)) {
    if (!is.null(legend)) abort("Use legend or series, not both.")
    legend <- series
  }
  out <- {
  scalar_flag(stacked, "stacked"); scalar_flag(labels, "labels")
  new_visual("area", list(x = x, y = y, legend = legend, tooltip = tooltip), table, title, alt, aggregate, list(stacked = stacked, labels = labels))
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_scatter <- function(x, y, size = NULL, details = NULL, legend = NULL,
                        table = NULL, title = NULL, alt = NULL, aggregate = "sum", tooltip = NULL,
                     id = NULL, series = NULL) {
  if (!is.null(series)) {
    if (!is.null(legend)) abort("Use legend or series, not both.")
    legend <- series
  }
  out <- {
  new_visual("scatter", list(x = x, y = y, size = size, details = details, legend = legend, tooltip = tooltip), table, title, alt, aggregate)
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_pie <- function(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL) {
  if (!is.null(category)) {
    if (!is.null(x)) abort("Use x or category, not both.")
    x <- category
  }
  if (!is.null(value)) {
    if (!is.null(y)) abort("Use y or value, not both.")
    y <- value
  }
  if (is.null(x) || is.null(y)) abort("Supply a category and a numeric value field.")
  out <- {
  scalar_flag(labels, "labels")
  new_visual("pie", list(x = x, y = y, tooltip = tooltip), table, title, alt, aggregate, list(labels = labels))
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_donut <- function(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL) {
  if (!is.null(category)) {
    if (!is.null(x)) abort("Use x or category, not both.")
    x <- category
  }
  if (!is.null(value)) {
    if (!is.null(y)) abort("Use y or value, not both.")
    y <- value
  }
  if (is.null(x) || is.null(y)) abort("Supply a category and a numeric value field.")
  out <- {
  out <- pbi_pie(x, y, table, title, alt, aggregate, labels, tooltip); out$type <- "donut"; out
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_treemap <- function(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL, group = NULL) {
  if (!is.null(category)) {
    if (!is.null(x)) abort("Use x or category, not both.")
    x <- category
  }
  if (!is.null(value)) {
    if (!is.null(y)) abort("Use y or value, not both.")
    y <- value
  }
  if (is.null(x) || is.null(y)) abort("Supply a category and a numeric value field.")
  out <- {
  out <- pbi_pie(x, y, table, title, alt, aggregate, labels, tooltip); out$type <- "treemap"; out
  }
  out$fields$legend <- group
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_funnel <- function(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL) {
  if (!is.null(category)) {
    if (!is.null(x)) abort("Use x or category, not both.")
    x <- category
  }
  if (!is.null(value)) {
    if (!is.null(y)) abort("Use y or value, not both.")
    y <- value
  }
  if (is.null(x) || is.null(y)) abort("Supply a category and a numeric value field.")
  out <- {
  out <- pbi_pie(x, y, table, title, alt, aggregate, labels, tooltip); out$type <- "funnel"; out
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_waterfall <- function(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL, breakdown = NULL) {
  if (!is.null(category)) {
    if (!is.null(x)) abort("Use x or category, not both.")
    x <- category
  }
  if (!is.null(value)) {
    if (!is.null(y)) abort("Use y or value, not both.")
    y <- value
  }
  if (is.null(x) || is.null(y)) abort("Supply a category and a numeric value field.")
  out <- {
  out <- pbi_pie(x, y, table, title, alt, aggregate, labels, tooltip); out$type <- "waterfall"; out
  }
  out$fields$legend <- breakdown
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_card <- function(value, table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL) {

  out <- {
  new_visual("card", list(value = value), table, title, alt, aggregate)
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_gauge <- function(value, target = NULL, min = NULL, max = NULL,
                      table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL, minimum = NULL, maximum = NULL) {
  if (!is.null(minimum)) {
    if (!is.null(min)) abort("Use min or minimum, not both.")
    min <- minimum
  }
  if (!is.null(maximum)) {
    if (!is.null(max)) abort("Use max or maximum, not both.")
    max <- maximum
  }
  constants <- list(target = target, min = min, max = max)
  constants <- Filter(is.numeric, constants)
  invisible(lapply(constants, number, label = "Gauge constant"))
  if (all(c("min", "max") %in% names(constants)) && constants$min >= constants$max)
    abort("A fixed gauge min must be less than max.")
  if (is.numeric(target)) target <- NULL
  if (is.numeric(min)) min <- NULL
  if (is.numeric(max)) max <- NULL
  out <- {
  new_visual("gauge", list(value = value, target = target, min = min, max = max), table, title, alt, aggregate)
  }
  out$options$constants <- constants
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_table <- function(columns = NULL, table = NULL, title = NULL, alt = NULL,
                     id = NULL) {

  out <- {
  new_visual("table", list(columns = columns), table, title, alt)
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_matrix <- function(rows, values, columns = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL) {

  out <- {
  new_visual("matrix", list(rows = rows, values = values, columns = columns), table, title, alt, aggregate)
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_slicer <- function(field, table = NULL, title = NULL, alt = NULL,
                       style = c("dropdown", "list", "between"), single_select = FALSE, sync = NULL,
                     id = NULL, single = NULL) {
  if (!is.null(single)) {
    if (!missing(single_select)) abort("Use single_select or single, not both.")
    single_select <- single
  }
  out <- {
  style <- match.arg(style); scalar_flag(single_select, "single_select")
  if (!is.null(sync)) object_name(sync, "sync group")
  if (length(field_list(field)) != 1L) abort("A slicer takes exactly one column.")
  new_visual("slicer", list(value = field), table, title, alt,
             options = list(style = style, single_select = single_select, sync = sync))
  }
  set_visual_id(out, id)
}
# @rdname pbi_bar
# @export
pbi_text <- function(text, font_size = 18, color = NULL, title = NULL, alt = NULL,
                     id = NULL, size = NULL, bold = FALSE) {
  if (!is.null(size)) {
    if (!missing(font_size)) abort("Use font_size or size, not both.")
    font_size <- size
  }
  scalar_flag(bold, "bold")
  out <- {
  scalar_string(text, "text", empty = TRUE); number(font_size, "font_size", 6, 144)
  if (!is.null(color)) { color_check(color); scalar_string(color, "color") }
  new_visual("text", title = title, alt = alt, options = list(text = text, font_size = font_size, color = color))
  }
  out$options$bold <- bold
  set_visual_id(out, id)
}

# Set a visual's grid span, exact position, or sort order
# @param x A visual.
# @param columns,rows Grid span.
# @param left,top,width,height Position in canvas pixels for free layout.
# @param field A field by which to sort. For an aggregated sort use pbi_field
#   with aggregate, or a pbi_ref. The field must already be projected.
# @param descending Sort descending rather than ascending.
# @return The modified visual.
# @export
pbi_span <- function(x, columns = 1L, rows = 1L) {
  assert_visual(x); number(columns, "columns", 1, 24, TRUE); number(rows, "rows", 1, 24, TRUE)
  x$span <- c(columns = columns, rows = rows); x
}
# @rdname pbi_span
# @export
pbi_place <- function(x, left, top, width, height) {
  assert_visual(x)
  invisible(lapply(list(left = left, top = top), number, label = "Position", lower = 0))
  invisible(lapply(list(width = width, height = height), number, label = "Size", lower = 1))
  x$position <- list(x = left, y = top, width = width, height = height); x
}
# @rdname pbi_span
# @export
pbi_sort <- function(x, field, descending = FALSE, direction = NULL, table = NULL) {
  if (!is.null(direction)) {
    if (!missing(descending)) abort("Use descending or direction, not both.")
    descending <- match.arg(direction, c("ascending", "descending")) == "descending"
  }
  if (!is.null(table)) {
    if (inherits(field, "pbi_field")) {
      if (!is.null(field$table)) abort("Specify table on the field or on pbi_sort(), not both.")
      field$table <- table
    } else field <- pbi_field(field, table)
  }
  assert_visual(x); scalar_flag(descending, "descending")
  if (length(field_list(field)) != 1L) abort("Sort by one projected field.")
  x$sort <- list(field = field, direction = if (descending) "Descending" else "Ascending"); x
}
