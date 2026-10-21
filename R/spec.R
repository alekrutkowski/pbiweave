# Begin a declarative Power BI report
#
# Values are snapshotted when data are added. The result is an immutable-style
# specification, suitable for magrittr or base R pipes. Compilation produces a
# portable project; Desktop refresh and Save As create the final PBIX.
# @param title Report title.
# @param data Optional data.frame, data.table, or named list of such tables.
# @param table Default table name when data is a single data frame.
# @param theme A pbi_theme object, or its preset name.
# @param locale Model culture, for example "en-US".
# @return A pbi_dashboard specification.
# @export
# @examples
# pbi_dashboard("Cars", mtcars) %>%
#   pbi_page("Overview", pbi_card("mpg", aggregate = "average"))
pbi_dashboard <- function(title, data = NULL, table = "data", theme = "linen", locale = "en-US") {
  object_name(title, "title")
  scalar_string(locale, "locale")
  if (!grepl("^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$", locale)) abort("locale must be a culture such as en-US.")
  if (is.character(theme)) theme <- pbi_theme(theme)
  if (!inherits(theme, "pbi_theme")) abort("theme must be a pbi_theme or preset name.")
  out <- structure(list(title = title, theme = theme, locale = locale, tables = list(),
    measures = list(), relationships = list(), pages = list(), filters = list(),
    default_table = NULL, spec_version = "0.3.1"), class = "pbi_dashboard")
  if (is.data.frame(data)) out <- pbi_data(out, table, data)
  else if (!is.null(data)) {
    if (!is.list(data) || !length(data) || is.null(names(data))) abort("data must be a data frame or a named list of data frames.")
    unique_names(names(data), "Table names")
    out <- Reduce(function(x, nm) pbi_data(x, nm, data[[nm]]), names(data), init = out)
  }
  out
}

# Tasteful Power BI themes
# @param preset One of linen, midnight, ocean, forest, ink, or accessible.
# @param colors Optional categorical palette, as #RRGGBB colors.
# @param background,surface,foreground,muted,accent Optional color overrides.
# @param font Font family installed on the viewing computer.
# @param font_size,title_size Base and title font sizes.
# @return A pbi_theme object.
# @export
pbi_theme <- function(preset = c("linen", "midnight", "ocean", "forest", "ink", "accessible"),
                      colors = NULL, background = NULL, surface = NULL,
                      foreground = NULL, muted = NULL, accent = NULL,
                      font = "Segoe UI", font_size = 11, title_size = 15, text_size = NULL, palette = NULL) {
  if (!is.null(palette)) {
    if (!is.null(colors)) abort("Use colors or palette, not both.")
    colors <- palette
  }
  if (!is.null(text_size)) {
    if (!missing(font_size)) abort("Use font_size or text_size, not both.")
    font_size <- text_size
  }
  preset <- match.arg(preset)
  presets <- list(
    linen = list(colors = c("#007F7B", "#DF8C4D", "#6B7FA5", "#B46C7F", "#94A765", "#7C6CA1"),
      background = "#F3F4EF", surface = "#FFFFFF", foreground = "#203B43", muted = "#687A80", accent = "#007F7B"),
    midnight = list(colors = c("#60D5C8", "#A9B4FF", "#FDBB74", "#F797B7", "#A9DB7A", "#67BCF5"),
      background = "#121B2B", surface = "#1C2940", foreground = "#F0F5FC", muted = "#B1BFD2", accent = "#60D5C8"),
    ocean = list(colors = c("#126DA0", "#00A3A0", "#DE985B", "#715DB7", "#558C6B", "#D26D7F"),
      background = "#EEF4F8", surface = "#FFFFFF", foreground = "#18374A", muted = "#627C8C", accent = "#126DA0"),
    forest = list(colors = c("#267456", "#B88135", "#6C89A3", "#A26879", "#7A874D", "#7969A5"),
      background = "#F1F5EF", surface = "#FFFFFF", foreground = "#213D30", muted = "#657A6C", accent = "#267456"),
    ink = list(colors = c("#2B4C7E", "#A85F45", "#517E78", "#8C7298", "#9A854B", "#62738C"),
      background = "#FFFFFF", surface = "#FFFFFF", foreground = "#17212C", muted = "#586875", accent = "#2B4C7E"),
    accessible = list(colors = c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#000000"),
      background = "#F5F6F7", surface = "#FFFFFF", foreground = "#17212C", muted = "#54616C", accent = "#0072B2"))
  out <- presets[[preset]]
  overrides <- compact(list(colors = colors, background = background, surface = surface,
                           foreground = foreground, muted = muted, accent = accent))
  invisible(lapply(names(overrides), function(nm) {
    color_check(overrides[[nm]], nm)
    if (nm != "colors") scalar_string(overrides[[nm]], nm)
    NULL
  }))
  if (!is.null(colors) && length(colors) < 3L) abort("Supply at least three palette colors.")
  scalar_string(font, "font"); number(font_size, "font_size", 6, 72); number(title_size, "title_size", 6, 96)
  out[names(overrides)] <- overrides
  structure(c(list(name = paste0("pbiweave-", preset)), out,
              list(font = font, font_size = font_size, title_size = title_size)), class = "pbi_theme")
}

# Explicit field and measure references
# @param name Column or measure name.
# @param table Optional source table.
# @param aggregate Optional sum, average, min, max, count, or distinct_count.
# @return A pbi_field object.
# @export
pbi_field <- function(name = NULL, table = NULL, aggregate = NULL, label = NULL,
                      format = NULL, column = NULL) {
  if (!is.null(column)) {
    if (!is.null(name)) abort("Use name or column, not both.")
    name <- column
  }
  object_name(name, "name")
  if (!is.null(label)) scalar_string(label, "label")
  if (!is.null(format)) scalar_string(format, "format", empty = TRUE)
  if (!is.null(table)) object_name(table, "table")
  if (!is.null(aggregate)) aggregate <- canonical_aggregate(aggregate, allow_none = TRUE)
  structure(list(name = name, table = table, aggregate = aggregate, kind = "column", label = label, format = format), class = "pbi_field")
}
# @rdname pbi_field
# @export
pbi_ref <- function(name, table = NULL, label = NULL, format = NULL) {
  out <- pbi_field(name, table, label = label, format = format)
  out$kind <- "measure"
  out
}

# Typed include or exclude filters
# @param field Field name or explicit reference.
# @param values Atomic vector of values; NA represents Power BI blank.
# @param table Optional source table.
# @param exclude Exclude the supplied values instead of including them.
# @return A pbi_filter specification.
# @export
new_filter <- function(field, values, table = NULL, exclude = FALSE) {
  if (length(field_list(field)) != 1L) abort("A filter takes one field.")
  if (!is.atomic(values) || is.list(values) || is.complex(values) || is.raw(values) || !length(values))
    abort("values must be a non-empty atomic vector.")
  if (is.factor(values)) values <- as.character(values)
  if (is.numeric(values) && any(!is.finite(values) & !is.na(values))) abort("Filter values must be finite or NA.")
  scalar_flag(exclude, "exclude")
  if (!is.null(table)) object_name(table, "table")
  structure(list(field = field, values = unique(values), table = table, exclude = exclude), class = "pbi_filter")
}

# Attach report or visual filters
# @param x Dashboard for pbi_filters; visual for pbi_where.
# @param ... pbi_filter objects, or a list of them.
# @return The modified specification.
# @export
pbi_filters <- function(x, ...) {
  assert_dashboard(x)
  x$filters <- c(x$filters, flatten_specs(list(...), "pbi_filter"))
  x
}
# @rdname pbi_filters
# @export
pbi_where <- function(x, ...) {
  assert_visual(x)
  x$filters <- c(x$filters, flatten_specs(list(...), "pbi_filter"))
  x
}

flatten_specs <- function(x, class) {
  unlist(lapply(x, function(v) {
    if (inherits(v, class)) return(list(v))
    if (is.list(v) && all(vapply(v, inherits, logical(1), what = class))) return(v)
    abort("Expected ", class, " objects.")
  }), recursive = FALSE)
}

# Inspect a report specification
# @param x A dashboard specification.
# @param ... Unused.
# @export
print.pbi_dashboard <- function(x, ...) {
  cat("<pbiweave dashboard> ", x$title, "\n", sep = "")
  cat(length(x$tables), "tables;", length(x$measures), "measures;",
      length(x$relationships), "relationships;", length(x$pages), "pages\n")
  cat("Theme:", x$theme$name, "| Target: PBIR + embedded Import model\n")
  invisible(x)
}
