# Validate a report before compilation
#
# Checks field bindings, relationships, filters, date/sort invariants, layout
# bounds, and common performance problems. DAX and M expressions are evaluated
# by Power BI, not by this function. Warnings do not prohibit compilation.
# @param x A dashboard specification.
# @param strict Treat warnings as errors when stop_on_error is TRUE.
# @param stop_on_error Stop if diagnostics include an error.
# @return A data.table with severity, code, location, and message columns.
# @export
pbi_validate <- function(x, strict = FALSE, stop_on_error = FALSE) {
  assert_dashboard(x); scalar_flag(strict, "strict"); scalar_flag(stop_on_error, "stop_on_error")
  issues <- list()
  add <- function(severity, code, location, message) {
    issues[[length(issues) + 1L]] <<- list(severity = severity, code = code, location = location, message = message)
    invisible(NULL)
  }
  attempt <- function(expr, location, code) tryCatch(expr, error = function(e) {
    add("error", code, location, conditionMessage(e)); NULL
  })
  if (!length(x$tables)) add("error", "no_data", "report", "Add at least one embedded table.")
  if (!length(x$pages)) add("error", "no_pages", "report", "Add at least one page.")
  if (length(x$pages) && all(vapply(x$pages, `[[`, logical(1), "hidden")))
    add("error", "all_pages_hidden", "report", "At least one page must be visible.")
  filter_check <- function(filters, location, table = NULL) invisible(lapply(filters, function(f) {
    attempt({
      ref <- resolve_field(x, f$field, f$table %||% table)
      if (ref$kind != "column" || !is.null(ref$aggregate)) abort("Categorical filters require unaggregated columns.")
      normalize_filter_values(f$values, ref$type)
    }, location, "invalid_filter")
  }))
  filter_check(x$filters, "report")
  invisible(lapply(x$tables, function(tab) {
    attempt({
      mapping <- unlist(lapply(tab$columns, function(c) c$sort_by), use.names = TRUE)
      validate_sort_columns(tab$data, tab$columns, if (length(mapping)) mapping else NULL)
    }, tab$name, "sort_by")
    n <- nrow(tab$data)
    if (!n) add("warning", "empty_table", tab$name, "Empty table; visuals will show no observations.")
    if (n > 1000000L) add("warning", "large_snapshot", tab$name, "More than one million embedded rows; consider pre-aggregation and benchmark refresh memory.")
    if (as.numeric(utils::object.size(tab$data)) > 100 * 1024^2)
      add("warning", "large_memory", tab$name, "Snapshot exceeds 100 MiB in R; JSON encoding temporarily uses extra memory.")
  }))
  invisible(lapply(x$relationships, function(r) {
    missed <- attempt(validate_relationship_keys(x, r), paste0("relationship:", r$name), "relationship_keys")
    if (!is.null(missed) && any(missed) && (r$unmatched %||% "warn") == "warn")
      add("warning", "orphan_keys", r$from_table,
        paste0("Some ", r$from_column, " values are missing or have no match in ", r$to_table,
          ". Power BI can create a blank dimension member. Use unmatched='error' for strict keys."))
  }))
  sync <- list()
  # Multiple active routes are not allowed in the conservative relationship graph.
  edges <- Filter(function(r) isTRUE(r$active), x$relationships)
  if (length(edges)) {
    vertices <- names(x$tables)
    adjacency <- stats::setNames(lapply(vertices, function(v) character()), vertices)
    has_path <- function(start, target, adjacency) {
      visit <- function(todo, seen) {
        if (!length(todo)) return(FALSE)
        v <- todo[[1L]]
        if (v == target) return(TRUE)
        next_nodes <- setdiff(adjacency[[v]], seen)
        visit(unique(c(todo[-1L], next_nodes)), unique(c(seen, next_nodes)))
      }
      visit(start, start)
    }
    invisible(lapply(edges, function(r) {
      if (has_path(r$from_table, r$to_table, adjacency)) add("error", "ambiguous_relationships", "model",
        "Active relationships create multiple undirected paths. Make an alternative relationship inactive.")
      adjacency[[r$from_table]] <<- unique(c(adjacency[[r$from_table]], r$to_table))
      adjacency[[r$to_table]] <<- unique(c(adjacency[[r$to_table]], r$from_table))
    }))
  }
  invisible(lapply(seq_along(x$pages), function(i) {
    page <- x$pages[[i]]; loc <- paste0("page:", page$name)
    attempt({
      ids <- vapply(page$visuals, function(v) v$id %||% "", character(1))
      unique_names(ids, "Visual IDs")
      invisible(lapply(page$bindings, function(b) {
        if (!b$source %in% ids || !b$target %in% ids || identical(b$source, b$target))
          abort("Binding refers to missing or identical visual IDs.")
        if (!b$mode %in% c("filter", "none", "native")) abort("Invalid interaction mode.")
      }))
    }, loc, "interaction_ids")
    positions <- attempt(layout_page(page), loc, "layout")
    if (length(page$visuals) > 20L) add("warning", "many_visuals", loc,
      "More than 20 visuals on a page can increase rendering and interaction cost.")
    if (length(positions)) {
      invisible(lapply(seq_along(positions), function(j) {
        p <- positions[[j]]
        v <- page$visuals[[j]]
        min_height <- if (v$type == "text") 24 + v$options$font_size * 1.4 *
          max(1L, length(strsplit(v$options$text, "\n", fixed = TRUE)[[1L]])) else 90
        if (p$width < 160 || p$height < min_height) add("warning", "small_visual", paste0(loc, "/visual:", j),
          "A visual is small enough to risk truncated labels; review it in Desktop.")
        if (page$layout$type == "free" && page$layout$header > 0 && p$y < page$layout$padding + page$layout$header)
          add("warning", "header_overlap", paste0(loc, "/visual:", j), "Visual overlaps the reserved heading band.")
      }))
      if (length(positions) > 1L) invisible(lapply(seq_len(length(positions) - 1L), function(a) {
        invisible(lapply(seq.int(a + 1L, length(positions)), function(b) {
          p <- positions[[a]]; q <- positions[[b]]
          if (min(p$x + p$width, q$x + q$width) - max(p$x, q$x) > 0.1 &&
              min(p$y + p$height, q$y + q$height) - max(p$y, q$y) > 0.1)
            add("warning", "overlap", loc, paste("Visuals", a, "and", b, "overlap."))
        }))
      }))
    }
    filter_check(page$filters, loc)
    invisible(lapply(seq_along(page$visuals), function(j) {
      visual <- page$visuals[[j]]; vloc <- paste0(loc, "/visual:", j)
      filter_check(visual$filters, vloc, visual$table)
      if (visual$type == "text") return(invisible(NULL))
      sizes <- vapply(visual$fields, function(f) length(field_list(f)), integer(1))
      one <- switch(visual$type,
        bar = "legend", line = "legend", area = "legend",
        scatter = c("x", "y", "size", "details", "legend"),
        pie = "y", donut = "y", treemap = "y", funnel = "y", waterfall = "y",
        gauge = c("value", "target", "min", "max"), slicer = "value", character())
      if (any(sizes[intersect(names(sizes), one)] > 1L))
        add("error", "role_cardinality", vloc, "This visual accepts only one field in the supplied value/series role.")
      if (visual$type %in% c("bar", "line", "area") &&
          length(field_list(visual$fields$y)) > 1L && length(field_list(visual$fields$legend)))
        add("error", "multiple_values_with_legend", vloc, "Use multiple value fields or a categorical legend; Power BI does not support both in this visual.")
      query <- attempt(visual_query(x, visual), vloc, "field_binding")
      if (!is.null(query)) {
        roles <- query$queryState
        projections <- unlist(lapply(roles, `[[`, "projections"), recursive = FALSE)
        refs <- vapply(projections, `[[`, character(1), "queryRef")
        invisible(lapply(unique(refs[duplicated(refs)]), function(ref) {
          expr <- lapply(projections[refs == ref], `[[`, "field")
          if (!all(vapply(expr, identical, logical(1), y = expr[[1L]])))
            add("error", "query_ref_collision", vloc, "Distinct expressions share a native query identifier.")
        }))
        required <- switch(visual$type, bar = c("Category", "Y"), line = c("Category", "Y"),
          area = c("Category", "Y"), scatter = c("X", "Y"), pie = c("Category", "Y"),
          donut = c("Category", "Y"), waterfall = c("Category", "Y"), funnel = c("Category", "Y"),
          treemap = c("Group", "Values"), card = "Data", gauge = "Y", table = "Values",
          matrix = c("Rows", "Values"), slicer = "Values")
        if (!all(required %in% names(roles))) add("error", "missing_binding", vloc, "The visual is missing a required field.")
        if (!is.null(visual$sort)) {
          projected <- unlist(lapply(roles, function(role) lapply(role$projections, `[[`, "field")), recursive = FALSE)
          sort_expr <- query$sortDefinition$sort[[1L]]$field
          if (!any(vapply(projected, identical, logical(1), y = sort_expr)))
            add("error", "sort_not_projected", vloc, "Sort field must already be projected in this visual with the same aggregation.")
        }
      }
      if (visual$type == "slicer") attempt({
        ref <- resolve_field(x, visual$fields$value, visual$table)
        if (ref$kind != "column" || !is.null(ref$aggregate)) abort("Slicers require an unaggregated column.")
        if (!is.null(visual$options$sync)) {
          key <- paste(ref$table, ref$name, sep = "\034")
          old <- sync[[visual$options$sync]]
          if (!is.null(old) && !identical(old, key))
            abort("Synchronized slicers must refer to the same model column.")
          sync[[visual$options$sync]] <<- key
        }
        if (visual$options$style == "between" && !ref$type %in% c("date", "dateTime", "double", "int64", "decimal"))
          abort("Between slicers require numeric or date columns.")
      }, vloc, "invalid_slicer")
      if (visual$type == "scatter" && is.null(visual$fields$details) && is.null(visual$fields$legend))
        add("warning", "scatter_aggregate", vloc, "Without details or legend the scatter plot aggregates to one point.")
      if (visual$type %in% c("pie", "donut")) attempt({
        ref <- resolve_field(x, field_list(visual$fields$x)[[1L]], visual$table)
        if (length(unique(x$tables[[ref$table]]$data[[ref$name]])) > 8L)
          add("warning", "many_slices", vloc, "More than eight categories; a bar chart may be easier to read.")
      }, vloc, "invalid_categories")
    }))
  }))
  out <- if (length(issues)) data.table::rbindlist(issues) else data.table::data.table(
    severity = character(), code = character(), location = character(), message = character())
  if (stop_on_error && any(out$severity == "error" | (strict & out$severity == "warning")))
    abort(paste(paste0(out$severity, " [", out$location, "]: ", out$message), collapse = "\n"))
  class(out) <- c("pbi_diagnostics", class(out))
  out
}

# Inspect data size and report complexity
# @param x A dashboard.
# @return A named list of tables, visual counts, and diagnostics.
# @export
pbi_inspect <- function(x) {
  assert_dashboard(x)
  tables <- if (length(x$tables)) data.table::rbindlist(lapply(x$tables, function(t)
    data.table::data.table(table = t$name, rows = nrow(t$data), columns = ncol(t$data),
      bytes = as.numeric(utils::object.size(t$data))))) else data.table::data.table()
  pages <- if (length(x$pages)) data.table::rbindlist(lapply(x$pages, function(p)
    data.table::data.table(page = p$name, visuals = length(p$visuals), layout = p$layout$type,
      width = p$width, height = p$height))) else data.table::data.table()
  list(tables = tables, pages = pages, measures = length(x$measures),
       relationships = length(x$relationships), diagnostics = pbi_validate(x))
}

# Compatibility accessors for 0.2.0, without turning the original diagnostic
# data.table into a different return type. These are not stored table columns.
`$.pbi_diagnostics` <- function(x, name) {
  if (name == "valid") return(!any(.subset2(x, "severity") == "error"))
  if (name == "errors") return(.subset2(x, "message")[.subset2(x, "severity") == "error"])
  if (name == "warnings") return(.subset2(x, "message")[.subset2(x, "severity") == "warning"])
  .subset2(x, name)
}
