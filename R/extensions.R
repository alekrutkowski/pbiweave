# Additive R-first helpers and interaction specifications. These share the
# original model/report implementation rather than a second compiler pipeline.

canonical_aggregate <- function(x, allow_none = FALSE) {
  scalar_string(x, "aggregate")
  if (x %in% c("distinctcount", "distinctCount")) x <- "distinct_count"
  match.arg(x, c("sum", "average", "min", "max", "count", "distinct_count",
                 if (allow_none) "none"))
}

first_table <- function(x, table = NULL) {
  table <- table %||% names(x$tables)[1L]
  if (length(table) != 1L || is.na(table) || !table %in% names(x$tables))
    abort("Unknown table. Add data first and specify an existing table name.")
  table
}

set_visual_id <- function(visual, id) {
  if (!is.null(id)) object_name(id, "Visual ID")
  visual$id <- id
  visual
}

native_visual_id <- function(visual, page_index, visual_index) {
  # Preserve all original generated identifiers for automatically assigned IDs.
  if (is.null(visual$id) || identical(visual$id, paste0("v", visual_index)))
    return(visual_id(page_index, visual_index))
  paste0("v", stable_id(paste(page_index, visual$id, sep = "\034")))
}

# @export
pbi_prepare <- function(data, transform = identity, ...) {
  if (!is.data.frame(data)) abort("data must be a data frame or data.table.")
  if (!is.function(transform)) abort("transform must be an ordinary R function.")
  result <- transform(data.table::copy(data.table::as.data.table(data)), ...)
  if (!is.data.frame(result)) abort("transform must return a data frame or data.table.")
  data.table::copy(data.table::as.data.table(result))
}

# @export
pbi_column <- function(x, column, table = NULL, type = NULL, format = NULL,
                       hidden = NULL, description = NULL, sort_by = NULL,
                       summarize = NULL, data_category = NULL) {
  assert_dashboard(x); table <- first_table(x, table); object_name(column, "column")
  if (!column %in% names(x$tables[[table]]$columns)) abort("Unknown column: ", column)
  # Copy data before conversion, so previous specifications remain snapshots.
  tab <- x$tables[[table]]
  col <- tab$columns[[column]]
  if (!is.null(type)) {
    col$type <- canonical_type(type)
    tab$data <- data.table::copy(tab$data)
    data.table::set(tab$data, j = column,
      value = normalize_column(tab$data[[column]], col$type, column))
  }
  if (!is.null(format)) { scalar_string(format, "format", empty = TRUE); col$format <- format }
  if (!is.null(hidden)) { scalar_flag(hidden, "hidden"); col$hidden <- hidden }
  if (!is.null(description)) {
    scalar_string(description, "description", empty = TRUE); col$description <- description
  }
  if (!is.null(sort_by)) {
    object_name(sort_by, "sort_by")
    if (!sort_by %in% names(tab$columns)) abort("Unknown sort_by column: ", sort_by)
    col$sort_by <- sort_by
  }
  if (!is.null(summarize)) {
    summarize <- canonical_aggregate(summarize, allow_none = TRUE)
    if (summarize %in% c("sum", "average") && !col$type %in% c("int64", "double", "decimal"))
      abort("Cannot ", summarize, " a non-numeric column.")
    col$summarize <- if (summarize == "distinct_count") "distinctCount" else summarize
  }
  if (!is.null(data_category)) { object_name(data_category, "data_category"); col$data_category <- data_category }
  tab$columns[[column]] <- col
  mapping <- unlist(lapply(tab$columns, function(z) z$sort_by), use.names = TRUE)
  validate_sort_columns(tab$data, tab$columns, if (length(mapping)) mapping else NULL)
  x$tables[[table]] <- tab
  invisible(lapply(x$relationships, function(r) validate_relationship_keys(x, r)))
  x
}

# @export
pbi_aggregate <- function(column, fun = c("sum", "average", "min", "max", "count", "distinct_count"),
                          table = NULL, label = NULL, format = NULL) {
  if (missing(fun)) fun <- "sum"
  pbi_field(column, table, canonical_aggregate(fun), label, format)
}

# @export
pbi_ratio <- function(x, name, numerator, denominator, table = NULL,
                      format = "0.0%", description = NULL) {
  assert_dashboard(x); table <- first_table(x, table)
  invisible(lapply(list(numerator, denominator), function(n)
    resolve_field(x, pbi_field(n, table, aggregate = "sum"))))
  pbi_measure(x, name, paste0("DIVIDE(SUM(", dax_column(table, numerator),
    "), SUM(", dax_column(table, denominator), "))"), table = table,
    format = format, description = description)
}

# @export
pbi_calendar <- function(x, column, table = NULL, name = "Calendar", from = NULL, to = NULL) {
  assert_dashboard(x); table <- first_table(x, table)
  f <- resolve_field(x, pbi_field(column, table))
  if (f$type != "date") abort("Calendar relationships require a Date column; convert timestamps to Date in R first.")
  z <- x$tables[[table]]$data[[column]]
  if (all(is.na(z))) abort("Calendar requires at least one non-missing date.")
  from <- from %||% min(z, na.rm = TRUE); to <- to %||% max(z, na.rm = TRUE)
  x <- pbi_date_table(x, from, to, name)
  pbi_relationship(x, table, column, name, "Date", unmatched = "warn")
}

validate_relationship_keys <- function(x, r) {
  f <- resolve_field(x, pbi_field(r$from_column, r$from_table))
  t <- resolve_field(x, pbi_field(r$to_column, r$to_table))
  if (!identical(f$type, t$type)) abort("Relationship key types must match.")
  fk <- model_key(x$tables[[f$table]]$data[[f$name]], f$type)
  pk <- model_key(x$tables[[t$table]]$data[[t$name]], t$type)
  if (anyNA(pk) || anyDuplicated(pk))
    abort("Dimension key ", t$table, "[", t$name, "] must be unique and non-missing.")
  missed <- is.na(fk) | !fk %in% pk
  if (any(missed) && identical(r$unmatched, "error"))
    abort(sum(missed), " missing/unmatched fact keys for ", t$table,
          ". Prepare an explicit Unknown dimension member or set unmatched = 'allow'.")
  invisible(missed)
}

# @export
pbi_filter <- function(..., field = NULL, values = NULL, table = NULL,
                       exclude = FALSE, x = NULL, page = NULL) {
  args <- list(...)
  if (length(args) && !is.null(names(args)) && any(nzchar(names(args))))
    abort("Unknown named argument to pbi_filter().")
  # Constructor: pbi_filter(field, values, table, exclude).
  # Modifier: board/visual %>% pbi_filter(field, values, table, exclude).
  if (length(args) && (inherits(args[[1L]], "pbi_dashboard") || inherits(args[[1L]], "pbi_visual"))) {
    if (!is.null(x)) abort("Specify the filtered object once.")
    x <- args[[1L]]; args <- args[-1L]
  }
  supplied <- c(!missing(field), !missing(values), !missing(table), !missing(exclude))
  vals <- list(field = field, values = values, table = table, exclude = exclude)
  slots <- which(!supplied)
  if (length(args) > length(slots)) abort("Too many positional arguments to pbi_filter().")
  if (length(args)) vals[slots[seq_along(args)]] <- args
  filter <- new_filter(vals$field, vals$values, vals$table, vals$exclude)
  if (is.null(x)) {
    if (!is.null(page)) abort("A page filter needs a dashboard as x or as the first piped argument.")
    return(filter)
  }
  if (inherits(x, "pbi_visual")) {
    if (!is.null(page)) abort("page does not apply to a visual filter.")
    return(pbi_where(x, filter))
  }
  assert_dashboard(x)
  if (is.null(page)) return(pbi_filters(x, filter))
  i <- page_index(x, page)
  x$pages[[i]]$filters <- c(x$pages[[i]]$filters, list(filter))
  x
}

page_index <- function(x, page = NULL) {
  if (!length(x$pages)) abort("Add a page first.")
  if (is.null(page)) return(length(x$pages))
  if (is.numeric(page)) { number(page, "page", 1, length(x$pages), TRUE); return(as.integer(page)) }
  scalar_string(page, "page")
  i <- match(page, vapply(x$pages, `[[`, character(1), "name"))
  if (is.na(i)) abort("Unknown page: ", page)
  i
}

# @export
pbi_input <- function(id, field, table = NULL, label = NULL,
                      style = c("dropdown", "list", "between"), single = FALSE,
                      sync = NULL, alt = NULL) {
  v <- pbi_slicer(field, table = table, title = label, alt = alt,
    style = match.arg(style), single_select = single, sync = sync, id = id)
  v$input <- TRUE
  v
}

# @export
pbi_output <- function(id, visual) {
  assert_visual(visual)
  set_visual_id(visual, id)
}

# @export
pbi_screen <- function(x, name, ..., layout = pbi_layout("sidebar", sidebar_mode = "slicers"),
                       size = "wide", width = NULL, height = NULL, interactions = "none") {
  pbi_page(x, name, ..., layout = layout, size = size, width = width,
           height = height, interactions = interactions)
}

# @export
pbi_bind <- function(x, input, outputs, page = NULL, mode = c("filter", "none", "native")) {
  assert_dashboard(x); object_name(input, "input"); mode <- match.arg(mode)
  if (!is.character(outputs) || !length(outputs) || anyNA(outputs)) abort("outputs must name visual IDs.")
  i <- page_index(x, page)
  visuals <- x$pages[[i]]$visuals
  ids <- vapply(visuals, `[[`, character(1), "id")
  if (!input %in% ids || any(!outputs %in% ids)) abort("Binding refers to a missing visual ID on this page.")
  if (input %in% outputs) abort("A visual cannot bind to itself.")
  if (visuals[[match(input, ids)]]$type %in% c("text", "card", "gauge"))
    abort("A binding source must be a slicer or a selectable data visual.")
  if (any(vapply(visuals[match(outputs, ids)], function(v) v$type == "text", logical(1))))
    abort("pbi_text() is static text, not a reactive output.")
  bindings <- lapply(unique(outputs), function(out) list(source = input, target = out, mode = mode))
  key <- function(b) paste(b$source, b$target, sep = "\035")
  keys <- vapply(bindings, key, character(1))
  old <- Filter(function(b) !key(b) %in% keys, x$pages[[i]]$bindings)
  x$pages[[i]]$bindings <- c(old, bindings)
  x
}

interaction_edges <- function(page) {
  visuals <- page$visuals
  ids <- vapply(visuals, `[[`, character(1), "id")
  source <- ids[!vapply(visuals, function(v) v$type %in% c("text", "card", "gauge"), logical(1))]
  target <- ids[!vapply(visuals, function(v) v$type == "text", logical(1))]
  edges <- unlist(lapply(source, function(src) lapply(setdiff(target, src), function(dst)
    list(source = src, target = dst, mode = if (page$interactions == "default") "native" else page$interactions,
         explicit = FALSE))), recursive = FALSE)
  lapply(edges, function(e) {
    b <- Filter(function(b) identical(b$source, e$source) && identical(b$target, e$target), page$bindings)
    if (length(b)) { e$mode <- b[[1L]]$mode; e$explicit <- TRUE }
    e
  })
}

compile_interactions <- function(page, native_ids) {
  ids <- vapply(page$visuals, `[[`, character(1), "id")
  edges <- Filter(function(e) e$explicit || e$mode != "native", interaction_edges(page))
  lapply(edges, function(e) list(source = native_ids[[match(e$source, ids)]],
    target = native_ids[[match(e$target, ids)]],
    type = switch(e$mode, filter = "DataFilter", none = "NoFilter", native = "Default")))
}

# @export
pbi_flow <- function(x, page = NULL, include_disabled = FALSE) {
  assert_dashboard(x); scalar_flag(include_disabled, "include_disabled")
  pages <- if (is.null(page)) x$pages else x$pages[page_index(x, page)]
  rows <- unlist(lapply(pages, function(p) lapply(interaction_edges(p), function(e)
    c(list(page = p$name), e))), recursive = FALSE)
  if (!length(rows)) return(data.table::data.table(page = character(), source = character(),
    target = character(), mode = character(), explicit = logical()))
  result <- data.table::rbindlist(rows)
  if (!include_disabled) result <- result[result[["mode"]] != "none"]
  result
}

visual_field_formats <- function(dashboard, visual) {
  if (visual$type == "text") return(list())
  raw <- unlist(lapply(visual$fields, field_list), recursive = FALSE)
  refs <- Filter(function(f) inherits(f, "pbi_field") && !is.null(f$format), raw)
  if (!length(refs)) return(list())
  # Attach only explicit visual-level overrides, identified by actual queryRefs.
  query <- visual_query(dashboard, visual)
  projected <- unlist(lapply(query$queryState, `[[`, "projections"), recursive = FALSE)
  out <- unlist(lapply(refs, function(r) {
    f <- resolve_field(dashboard, r, visual$table)
    matches <- Filter(function(p) {
      if (!is.null(f$aggregate) || f$kind == "measure") return(identical(p$field, field_expression(f)))
      e <- p$field
      if (!is.null(e$Aggregation)) e <- e$Aggregation$Expression
      e <- e$Column %||% e$Measure
      !is.null(e) && identical(e$Expression$SourceRef$Entity, f$table) && identical(e$Property, f$name)
    }, projected)
    lapply(matches, function(p) list(properties = list(formatString = format_literal(r$format)),
      selector = list(metadata = p$queryRef)))
  }), recursive = FALSE)
  if (!length(out)) return(out)
  out[!duplicated(vapply(out, function(z) z$selector$metadata, character(1)))]
}

refresh_notice <- function() {
  text <- paste(
  "FIRST OPEN: in Power BI Desktop select Home -> Refresh.",
  "Embedded source data are present, but the processed data cache is initially absent.",
  "Empty visuals / 'incomplete or no data' before this refresh are expected.",
  "After refresh, review the report and use File -> Save As -> .pbix.", sep = "\n")
  message(text)
  invisible(text)
}
