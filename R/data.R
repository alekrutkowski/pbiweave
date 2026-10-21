# Add an embedded data snapshot
#
# Input data are copied, not modified by reference. Dates remain dates;
# timestamps are normalized to UTC. Integer64 values are encoded as decimal
# strings until Power Query converts them to Int64.Type, avoiding JSON precision
# loss. Unsupported list, complex, raw, and duration columns must be transformed
# explicitly. Non-finite values other than NA/NaN are rejected. Fixed decimal
# columns require at most four decimal places; use character values for exact
# amounts near the signed 64-bit currency limits.
# @param x A dashboard.
# @param name Table name.
# @param data A data frame or data.table.
# @param types Named column-type overrides: string, int64, double, boolean,
#   date, dateTime, or decimal. Common aliases text, integer, number, logical,
#   and datetime are accepted.
# @param formats Named DAX format strings.
# @param hidden Character vector of hidden columns.
# @param descriptions Named column descriptions.
# @param sort_by Named mapping from display columns to ordering columns.
# @return The modified dashboard.
# @export
pbi_data <- function(x, name, data, types = NULL, formats = NULL, hidden = character(),
                     descriptions = NULL, sort_by = NULL, description = NULL, table_hidden = FALSE) {
  # Two positional orders are distinguishable by their types, unlike chart roles.
  if (is.data.frame(name) && is.character(data) && length(data) == 1L) {
    tmp <- name; name <- data; data <- tmp
  }
  if (is.logical(hidden) && length(hidden) == 1L) {
    if (!missing(table_hidden)) abort("Use table_hidden or a logical hidden value, not both.")
    table_hidden <- hidden; hidden <- character()
  }
  scalar_flag(table_hidden, "table_hidden")
  if (!is.null(description)) scalar_string(description, "description", empty = TRUE)
  assert_dashboard(x); object_name(name, "Table name")
  if (tolower(name) %in% tolower(names(x$tables))) abort("Table already exists: ", name)
  if (!is.data.frame(data) || !ncol(data)) abort("data must be a data frame with at least one column.")
  unique_names(names(data), "Column names")
  cols <- names(data)
  invisible(lapply(list(types = types, formats = formats, descriptions = descriptions, sort_by = sort_by),
                   function(v) named_options(v, cols, "Column options")))
  if (!is.character(hidden) || anyNA(hidden) || any(!hidden %in% cols)) abort("hidden must name existing columns.")
  if (!is.null(sort_by) && (!is.character(sort_by) || anyNA(sort_by) || any(!sort_by %in% cols)))
    abort("sort_by targets must be existing column names.")
  dt <- data.table::copy(data.table::as.data.table(data))
  specs <- stats::setNames(lapply(cols, function(nm) {
    raw <- dt[[nm]]
    inferred <- infer_type(raw, nm)
    type <- if (nm %in% names(types)) canonical_type(types[[nm]]) else inferred
    value <- normalize_column(raw, type, nm)
    data.table::set(dt, j = nm, value = value)
    fmt <- if (nm %in% names(formats)) formats[[nm]] else switch(type,
      int64 = "0", date = "yyyy-MM-dd", dateTime = "yyyy-MM-dd HH:mm:ss", decimal = "#,0.00", NULL)
    if (!is.null(fmt)) scalar_string(fmt, paste0("Format for ", nm))
    desc <- if (nm %in% names(descriptions)) descriptions[[nm]] else NULL
    if (!is.null(desc)) scalar_string(desc, paste0("Description for ", nm))
    list(name = nm, type = type, format = fmt, hidden = nm %in% hidden,
         description = desc, sort_by = if (nm %in% names(sort_by)) unname(sort_by[[nm]]) else NULL)
  }), cols)
  validate_sort_columns(dt, specs, sort_by)
  x$tables[[name]] <- list(name = name, data = dt, columns = specs, date_table = FALSE,
    description = description, hidden = table_hidden)
  x$default_table <- x$default_table %||% name
  x
}

infer_type <- function(x, nm) {
  if (inherits(x, "integer64")) return("int64")
  if (inherits(x, "Date")) return("date")
  if (inherits(x, "POSIXt")) return("dateTime")
  if (is.factor(x) || is.character(x)) return("string")
  if (is.integer(x)) return("int64")
  if (is.logical(x)) return("boolean")
  if (is.double(x) && !inherits(x, c("difftime", "AsIs"))) return("double")
  abort("Unsupported column type for ", nm, ": ", paste(class(x), collapse = "/"),
        ". Convert lists, durations, and complex values explicitly.")
}
canonical_type <- function(type) {
  scalar_string(type, "type")
  aliases <- c(text = "string", integer = "int64", number = "double", numeric = "double",
               logical = "boolean", datetime = "dateTime", currency = "decimal")
  if (type %in% names(aliases)) type <- unname(aliases[[type]])
  if (!type %in% c("string", "int64", "double", "boolean", "date", "dateTime", "decimal"))
    abort("Unsupported type: ", type)
  type
}
normalize_column <- function(x, type, nm) {
  original_na <- is.na(x)
  if (is.factor(x)) x <- as.character(x)
  if (inherits(x, "integer64")) x <- as.character(x)
  if (type == "string") return(enc2utf8(as.character(x)))
  if (type == "int64") {
    if (is.numeric(x)) {
      if (any(!is.finite(x) & !is.na(x)) || any(abs(x[!is.na(x)]) > 2^53) ||
          any(x[!is.na(x)] != trunc(x[!is.na(x)])))
        abort("Column ", nm, " requires exact integers. Supply large int64 values as character or bit64::integer64.")
      if (is.integer(x)) return(x)
      x <- vapply(x, function(v) if (is.na(v)) NA_character_ else sprintf("%.0f", v), character(1))
    }
    if (!is.character(x)) abort("Column ", nm, " cannot be converted to int64.")
    valid <- x[!is.na(x)]
    if (any(!grepl("^[+-]?[0-9]+$", valid))) abort("Invalid int64 values in ", nm)
    neg <- startsWith(valid, "-")
    abs <- sub("^0+", "", sub("^[+-]", "", valid))
    abs[!nzchar(abs)] <- "0"
    bound <- ifelse(neg, "9223372036854775808", "9223372036854775807")
    if (any(nchar(abs) > 19L | (nchar(abs) == 19L & abs > bound))) abort("int64 overflow in ", nm)
    x[!is.na(x)] <- paste0(ifelse(neg & abs != "0", "-", ""), abs)
    return(x)
  }
  if (type == "decimal") return(normalize_decimal(x, nm))
  if (type == "double") {
    out <- suppressWarnings(as.numeric(x))
    if (any(is.na(out) & !original_na) || any(!is.finite(out) & !is.na(out)))
      abort("Column ", nm, " contains invalid or infinite numeric values.")
    return(out)
  }
  if (type == "boolean") {
    if (is.logical(x)) return(x)
    if (is.numeric(x) && all(is.na(x) | x %in% 0:1)) return(as.logical(x))
    if (is.character(x) && all(is.na(x) | tolower(x) %in% c("true", "false"))) return(as.logical(x))
    abort("Column ", nm, " requires logical, TRUE/FALSE, or 0/1 values.")
  }
  if (type == "date") {
    if (inherits(x, "Date")) {
      if (any(!is.finite(as.numeric(x)) & !is.na(x))) abort("Infinite dates in ", nm)
      return(x)
    }
    if (inherits(x, "POSIXt")) return(as.Date(x, tz = "UTC"))
    if (!is.character(x) || any(!is.na(x) & !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)))
      abort("Column ", nm, " requires Date values or ISO YYYY-MM-DD strings.")
    out <- as.Date(x, format = "%Y-%m-%d")
    if (any(is.na(out) & !original_na) || any(format(out[!is.na(out)], "%Y-%m-%d") != x[!is.na(out)]))
      abort("Invalid dates in ", nm)
    return(out)
  }
  if (type == "dateTime") {
    if (inherits(x, "Date")) x <- as.POSIXct(x, tz = "UTC")
    if (!inherits(x, "POSIXt")) abort("Column ", nm, " requires POSIXct/POSIXlt; parse timestamps explicitly before adding data.")
    out <- as.POSIXct(x)
    attr(out, "tzone") <- "UTC"
    if (any(!is.finite(as.numeric(out)) & !is.na(out))) abort("Infinite timestamps in ", nm)
    return(out)
  }
  abort("Unsupported type: ", type)
}

# Currency.Type is a signed 64-bit integer scaled by 10,000. Perform the
# boundary check as decimal text, avoiding rounded double comparisons.
normalize_decimal <- function(x, nm) {
  if (is.logical(x)) x <- as.numeric(x)
  if (is.numeric(x)) {
    if (any(!is.finite(x) & !is.na(x))) abort("Invalid or infinite fixed-decimal values in ", nm)
    rounded <- round(x, 4L)
    tolerance <- pmax(abs(x), abs(rounded)) * .Machine$double.eps * 4
    if (any(abs(x - rounded) > tolerance, na.rm = TRUE))
      abort("Fixed-decimal values in ", nm, " must have at most four decimal places; round explicitly.")
    x <- vapply(x, function(value) if (is.na(value)) NA_character_ else
      sprintf("%.4f", value), character(1L))
  }
  if (!is.character(x)) abort("Column ", nm, " requires numeric or plain decimal text values.")
  values <- x[!is.na(x)]
  if (any(!grepl("^[+-]?([0-9]+(\\.[0-9]{0,4})?|\\.[0-9]{1,4})$", values)))
    abort("Fixed-decimal values in ", nm, " require plain decimal text with at most four decimal places.")
  negative <- startsWith(values, "-")
  magnitude <- sub("^[+-]", "", values)
  integer <- sub("^0+", "", sub("\\..*$", "", magnitude))
  integer[!nzchar(integer)] <- "0"
  fraction <- ifelse(grepl(".", magnitude, fixed = TRUE), sub("^[^.]*\\.", "", magnitude), "")
  fraction <- paste0(fraction, strrep("0", 4L - nchar(fraction)))
  scaled <- sub("^0+", "", paste0(integer, fraction))
  scaled[!nzchar(scaled)] <- "0"
  bound <- ifelse(negative, "9223372036854775808", "9223372036854775807")
  if (any(nchar(scaled) > 19L | (nchar(scaled) == 19L & scaled > bound)))
    abort("Fixed-decimal overflow in ", nm, ". Use character values for exact large amounts.")
  x[!is.na(x)] <- paste0(ifelse(negative & scaled != "0", "-", ""), integer, ".", fraction)
  x
}

# Power BI compares imported text case-insensitively and removes trailing
# spaces. This catches common key collisions without changing display values.
# Other locale-specific collation equivalences still require Desktop review.
model_key <- function(x, type) {
  if (identical(type, "string")) return(tolower(sub(" +$", "", x)))
  x
}

validate_sort_columns <- function(data, columns, sort_by) {
  if (is.null(sort_by)) return(invisible(NULL))
  invisible(lapply(names(sort_by), function(name) {
    order <- sort_by[[name]]
    if (identical(name, order)) abort("A column cannot sort by itself: ", name)
    pairs <- unique(data.table::data.table(
      display = model_key(data[[name]], columns[[name]]$type),
      order = model_key(data[[order]], columns[[order]]$type)))
    if (anyDuplicated(pairs$display))
      abort("sort_by requires each ", name, " value to map to exactly one ", order, " value.")
    visited <- character()
    current <- name
    while (current %in% names(sort_by)) {
      if (current %in% visited) abort("sort_by contains a circular dependency involving ", current, ".")
      visited <- c(visited, current)
      current <- sort_by[[current]]
    }
    NULL
  }))
}

normalize_filter_values <- function(values, field_type) {
  type <- canonical_type(field_type)
  if (is.logical(values) && all(is.na(values))) {
    values <- switch(type, date = as.Date(rep(NA_character_, length(values))),
      dateTime = as.POSIXct(rep(NA_character_, length(values)), tz = "UTC"),
      int64 = rep(NA_character_, length(values)), values)
  }
  normalize_column(values, type, "filter values")
}

# Add a DAX measure
# @param x A dashboard.
# @param name Measure name, unique across the model.
# @param expression DAX expression. Use either expression or column.
# @param table Home table, defaulting to the first table.
# @param column Column to aggregate when expression is omitted.
# @param aggregate sum, average, min, max, count, or distinct_count.
# @param format Optional DAX format string.
# @param description Optional measure description.
# @return The modified dashboard.
# @export
pbi_measure <- function(x, name, expression = NULL, table = NULL, column = NULL,
                        aggregate = "sum", format = NULL, description = NULL) {
  assert_dashboard(x); object_name(name, "Measure name")
  table <- table %||% names(x$tables)[1L]
  if (!length(table) || !table %in% names(x$tables)) abort("Add a home table before adding measures.")
  if (any(vapply(x$measures, function(m) tolower(m$name) == tolower(name), logical(1))) ||
      tolower(name) %in% tolower(names(x$tables[[table]]$columns))) abort("Duplicate measure or column name: ", name)
  if (!is.null(expression) && !is.null(column)) abort("Supply expression or column, not both.")
  if (is.null(expression)) {
    if (is.null(column)) abort("Supply a DAX expression or a column to aggregate.")
    aggregate <- canonical_aggregate(aggregate)
    ref <- resolve_field(x, pbi_field(column, table), aggregate = aggregate)
    fn <- c(sum = "SUM", average = "AVERAGE", min = "MIN", max = "MAX", count = "COUNTA", distinct_count = "DISTINCTCOUNT")[[aggregate]]
    expression <- paste0(fn, "(", dax_column(table, ref$name), ")")
  }
  scalar_string(expression, "expression")
  if (!is.null(format)) scalar_string(format, "format")
  if (!is.null(description)) scalar_string(description, "description")
  x$measures <- c(x$measures, list(list(name = name, table = table, expression = expression, format = format, description = description)))
  x
}

# Relate a fact table to a dimension
#
# Relationships are many-to-one, with a single filter direction by default.
# Dimension keys must be unique and non-missing. Orphan fact keys are reported
# by pbi_validate. Bidirectional filtering is opt-in.
# @param x A dashboard.
# @param from,from_column Fact table and foreign key.
# @param to,to_column Dimension table and unique key.
# @param active Whether the relationship is active.
# @param bidirectional Permit filters to travel in both directions.
# @return The modified dashboard.
# @export
pbi_relationship <- function(x, from = NULL, from_column, to = NULL, to_column,
                             active = TRUE, bidirectional = FALSE,
                             from_table = NULL, to_table = NULL, direction = NULL,
                             unmatched = c("warn", "error", "allow")) {
  if (!is.null(from_table)) {
    if (!is.null(from)) abort("Use from or from_table, not both.")
    from <- from_table
  }
  if (!is.null(to_table)) {
    if (!is.null(to)) abort("Use to or to_table, not both.")
    to <- to_table
  }
  if (!is.null(direction)) {
    if (!missing(bidirectional)) abort("Use bidirectional or direction, not both.")
    bidirectional <- match.arg(direction, c("single", "both")) == "both"
  }
  unmatched <- match.arg(unmatched)
  object_name(from, "from"); object_name(to, "to")
  assert_dashboard(x); scalar_flag(active, "active"); scalar_flag(bidirectional, "bidirectional")
  f <- resolve_field(x, pbi_field(from_column, from)); t <- resolve_field(x, pbi_field(to_column, to))
  if (from == to) abort("Self relationships are not supported.")
  if (f$type != t$type) abort("Relationship key types must match.")
  key <- model_key(x$tables[[to]]$data[[to_column]], t$type)
  if (anyNA(key) || anyDuplicated(key)) abort("Dimension key ", to, "[", to_column, "] must be unique and non-missing.")
  id <- stable_id(paste(from, from_column, to, to_column, sep = "\034"))
  if (any(vapply(x$relationships, function(r) r$name == id, logical(1)))) abort("Relationship already exists.")
  x$relationships <- c(x$relationships, list(list(name = id, from_table = from, from_column = from_column,
    to_table = to, to_column = to_column, active = active,
    cross_filter = if (bidirectional) "bothDirections" else "oneDirection",
    unmatched = unmatched)))
  # Check immediately for an error policy, and recheck after metadata edits.
  if (unmatched == "error") validate_relationship_keys(x, utils::tail(x$relationships, 1L)[[1L]])
  x
}

# Add an explicit calendar dimension
# @param x A dashboard.
# @param start,end Inclusive dates, or ISO date strings.
# @param name Calendar table name.
# @return A dashboard with a date table and useful calendar attributes.
# @export
pbi_date_table <- function(x, start, end, name = "Calendar") {
  start <- as.Date(start); end <- as.Date(end)
  if (length(start) != 1L || length(end) != 1L || is.na(start) || is.na(end) || end < start)
    abort("start and end must be valid ordered dates.")
  if (as.numeric(end - start) > 365250) abort("Calendar range exceeds 1,000 years.")
  dates <- seq.Date(start, end, by = "day")
  month <- as.integer(format(dates, "%m"))
  weekday <- as.integer(format(dates, "%u"))
  calendar <- data.table::data.table(Date = dates, Year = as.integer(format(dates, "%Y")),
    Quarter = paste0("Q", (month - 1L) %/% 3L + 1L), Month = month, MonthName = month.abb[month],
    YearMonth = format(dates, "%Y-%m"), Day = as.integer(format(dates, "%d")), Weekday = weekday,
    WeekdayName = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")[weekday])
  x <- pbi_data(x, name, calendar, sort_by = c(MonthName = "Month", WeekdayName = "Weekday"))
  x$tables[[name]]$date_table <- TRUE
  x
}
