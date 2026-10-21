# Native PBIR report compiler. Format contracts are pinned in inst/schemas.
# These are original implementations of Microsoft's public JSON contracts.

report_schema <- function(family) {
  versions <- c(report = "3.3.0", page = "2.1.0", pagesMetadata = "1.1.0",
                versionMetadata = "1.0.0", visualContainer = "2.13.0")
  paste0("https://developer.microsoft.com/json-schemas/fabric/item/report/definition/",
         family, "/", versions[[family]], "/schema.json")
}

query_literal <- function(value, type = NULL) {
  if (length(value) != 1L) stop("A query literal must be scalar.", call. = FALSE)
  if (is.na(value)) return("null")
  if (inherits(value, "Date") || identical(type, "date"))
    return(paste0("datetime'", format(as.Date(value), "%Y-%m-%d"), "T00:00:00'"))
  if (inherits(value, "POSIXt") || identical(type, "dateTime"))
    return(paste0("datetime'", format(as.POSIXct(value, tz = "UTC"),
                                    "%Y-%m-%dT%H:%M:%OS6", tz = "UTC"), "'"))
  if (is.logical(value) || identical(type, "boolean")) {
    if (!is.logical(value)) stop("Boolean query literals require logical values.", call. = FALSE)
    return(if (isTRUE(value)) "true" else "false")
  }
  if (identical(type, "int64") || is.integer(value)) {
    value <- if (is.numeric(value) && !inherits(value, "integer64"))
      format(value, scientific = FALSE, trim = TRUE, digits = 17L, decimal.mark = ".") else as.character(value)
    if (!grepl("^-?[0-9]+$", value)) stop("Integer query literals require whole numbers.", call. = FALSE)
    return(paste0(value, "L"))
  }
  if (identical(type, "decimal")) {
    # Fixed-decimal filter values arrive as canonical strings. Converting them
    # to R double would lose significant digits near the currency bounds.
    value <- as.character(value)
    if (!grepl("^-?[0-9]+(\\.[0-9]+)?$", value))
      stop("Decimal query literals require canonical decimal text.", call. = FALSE)
    return(paste0(value, "M"))
  }
  if (is.numeric(value) || identical(type, "double"))
    return(paste0(format(as.numeric(value), digits = 17L, scientific = FALSE,
                         trim = TRUE, decimal.mark = "."), "D"))
  paste0("'", gsub("'", "''", enc2utf8(as.character(value)), fixed = TRUE), "'")
}

format_literal <- function(value) list(expr = list(Literal = list(Value = query_literal(value))))
format_color <- function(color) list(solid = list(color = format_literal(color)))
format_object <- function(properties, selector = NULL) {
  entry <- list(properties = properties)
  if (!is.null(selector)) entry$selector <- selector
  list(entry)
}

field_expression <- function(field, source = NULL) {
  ref <- if (is.null(source)) list(Entity = field$table) else list(Source = source)
  content <- list(Expression = list(SourceRef = ref), Property = field$name)
  if (identical(field$kind, "measure")) return(list(Measure = content))
  expression <- list(Column = content)
  if (!is.null(field$aggregate)) {
    functions <- c(sum = 0L, average = 1L, distinct_count = 2L,
                   min = 3L, max = 4L, count = 5L)
    expression <- list(Aggregation = list(Expression = expression,
                                         Function = unname(functions[[field$aggregate]])))
  }
  expression
}

field_query_ref <- function(field) {
  ref <- paste(field$table, field$name, sep = ".")
  # Query references are opaque identifiers. Dotted table/column names need a
  # suffix so (A.B, C) and (A, B.C) cannot both become A.B.C in one visual.
  if (any(grepl("[^A-Za-z0-9_ ]", c(field$table, field$name))))
    ref <- paste0(ref, "_", stable_id(paste(field$table, field$name, sep = "\034")))
  if (identical(field$kind, "measure") || is.null(field$aggregate)) return(ref)
  functions <- c(sum = "Sum", average = "Avg", distinct_count = "Count",
                 min = "Min", max = "Max", count = "CountNonNull")
  paste0(functions[[field$aggregate]], "(", ref, ")")
}

role_projections <- function(dashboard, fields, table = NULL, aggregate = NULL,
                             grouping = FALSE, column_only = FALSE) {
  fields <- field_list(fields)
  projections <- lapply(seq_along(fields), function(i) {
    field <- resolve_field(dashboard, fields[[i]], table = table, aggregate = aggregate)
    if (!is.null(aggregate) && field$kind == "column" && is.null(field$aggregate))
      abort("Value roles require an aggregation; aggregate = 'none' is for grouping/detail fields.")
    if ((grouping || column_only) && (field$kind != "column" || !is.null(field$aggregate)))
      stop("Grouping roles require unaggregated columns; use a measure or aggregation in a value role.", call. = FALSE)
    result <- list(field = field_expression(field), queryRef = field_query_ref(field),
                   nativeQueryRef = field$label %||% field$name)
    if (grouping) result$active <- identical(i, 1L)
    result
  })
  list(projections = projections)
}

compile_filters <- function(dashboard, filters, context, table = NULL) {
  if (!length(filters)) return(NULL)
  list(filters = lapply(seq_along(filters), function(i) {
    f <- filters[[i]]
    field <- resolve_field(dashboard, f$field,
                           table = if (is.null(f$table)) table else f$table)
    if (field$kind != "column" || !is.null(field$aggregate))
      stop("Categorical filters require an unaggregated column.", call. = FALSE)
    values <- normalize_filter_values(f$values, field$type)
    condition <- list(In = list(
      Expressions = list(field_expression(field, source = "s")),
      Values = lapply(seq_along(values), function(j)
        list(list(Literal = list(Value = query_literal(values[j], field$type)))))))
    if (isTRUE(f$exclude)) condition <- list(Not = list(Expression = condition))
    result <- list(
      name = paste0("Filter", stable_id(paste(context, i, sep = ":"))),
      field = field_expression(field), type = "Categorical",
      filter = list(Version = 2L,
                    From = list(list(Name = "s", Entity = field$table, Type = 0L)),
                    Where = list(list(Condition = condition))),
      howCreated = "User")
    if (isTRUE(f$exclude)) result$objects <- list(general = format_object(
      list(isInvertedSelectionMode = format_literal(TRUE))))
    result
  }))
}

native_visual_type <- function(visual) {
  o <- visual$options
  switch(visual$type,
    bar = if (isTRUE(o$percent)) {
      if (isTRUE(o$horizontal)) "hundredPercentStackedBarChart" else "hundredPercentStackedColumnChart"
    } else if (isTRUE(o$stacked)) {
      if (isTRUE(o$horizontal)) "barChart" else "columnChart"
    } else if (isTRUE(o$horizontal)) "clusteredBarChart" else "clusteredColumnChart",
    line = "lineChart",
    area = if (isTRUE(o$percent)) "hundredPercentStackedAreaChart" else
      if (isTRUE(o$stacked)) "stackedAreaChart" else "areaChart",
    scatter = "scatterChart", pie = "pieChart", donut = "donutChart",
    treemap = "treemap", funnel = "funnel", waterfall = "waterfallChart",
    card = "cardVisual", gauge = "gauge", table = "tableEx", matrix = "pivotTable",
    slicer = "slicer", text = "textbox",
    stop("Unknown visual type: ", visual$type, call. = FALSE))
}

visual_query <- function(dashboard, visual) {
  f <- visual$fields
  aggregate <- visual$aggregate
  if (is.null(aggregate)) aggregate <- "sum"
  make <- function(fields, value = FALSE, grouping = FALSE, column_only = FALSE)
    role_projections(dashboard, fields, visual$table,
                     if (value) aggregate else NULL, grouping, column_only)
  roles <- list()
  add <- function(role, fields, value = FALSE, grouping = FALSE) {
    column_only <- role %in% c("Category", "Series", "Group", "Details", "Breakdown", "Rows", "Columns") ||
      (visual$type == "slicer" && role == "Values")
    if (length(field_list(fields))) roles[[role]] <<- make(fields, value, grouping, column_only)
  }
  if (visual$type %in% c("bar", "line", "area", "pie", "donut", "funnel", "waterfall")) {
    add("Category", f$x, grouping = TRUE)
    add("Y", f$y, value = TRUE)
    if (visual$type == "waterfall") add("Breakdown", f$legend) else add("Series", f$legend)
  } else if (visual$type == "scatter") {
    add("X", f$x, value = TRUE)
    add("Y", f$y, value = TRUE)
    add("Size", f$size, value = TRUE)
    add("Category", f$details, grouping = TRUE)
    add("Series", f$legend)
  } else if (visual$type == "treemap") {
    add("Group", f$x, grouping = TRUE)
    add("Values", f$y, value = TRUE)
    add("Details", f$legend)
  } else if (visual$type == "card") {
    add("Data", f$value, value = TRUE)
  } else if (visual$type == "gauge") {
    add("Y", f$value, value = TRUE)
    add("TargetValue", f$target, value = TRUE)
    add("MinValue", f$min, value = TRUE)
    add("MaxValue", f$max, value = TRUE)
  } else if (visual$type == "table") {
    columns <- f$columns
    if (is.null(columns)) {
      table <- if (is.null(visual$table)) names(dashboard$tables)[1L] else visual$table
      columns <- names(Filter(function(x) !isTRUE(x$hidden), dashboard$tables[[table]]$columns))
    }
    if (!length(field_list(columns)))
      stop("A table visual requires at least one visible or explicitly selected column.", call. = FALSE)
    add("Values", columns)
  } else if (visual$type == "matrix") {
    add("Rows", f$rows, grouping = TRUE)
    add("Columns", f$columns, grouping = TRUE)
    add("Values", f$values, value = TRUE)
  } else if (visual$type == "slicer") {
    add("Values", f$value, grouping = TRUE)
  }
  if (!visual$type %in% c("card", "table", "matrix", "slicer", "text") &&
      length(field_list(f$tooltip)))
    roles$Tooltips <- list(projections = lapply(field_list(f$tooltip), function(value) {
      field <- resolve_field(dashboard, value, table = visual$table)
      if (field$kind == "column" && is.null(field$aggregate) &&
          field$type %in% c("double", "decimal", "int64") &&
          !(inherits(value, "pbi_field") && identical(value$aggregate, "none"))) field$aggregate <- aggregate
      list(field = field_expression(field), queryRef = field_query_ref(field), nativeQueryRef = field$label %||% field$name)
    }))
  result <- list(queryState = roles)
  if (!is.null(visual$sort)) {
    field <- resolve_field(dashboard, visual$sort$field, table = visual$table)
    # A raw numeric value sorts by the same aggregation used in the query.
    matches <- unlist(lapply(roles, function(role)
      lapply(role$projections, function(projection) projection$field)), recursive = FALSE)
    candidates <- Filter(function(expr) {
      ag <- expr$Aggregation
      !is.null(ag) && identical(ag$Expression$Column$Property, field$name) &&
        identical(ag$Expression$Column$Expression$SourceRef$Entity, field$table)
    }, matches)
    expression <- if (length(candidates) && is.null(field$aggregate)) candidates[[1L]] else field_expression(field)
    result$sortDefinition <- list(sort = list(list(field = expression,
      direction = visual$sort$direction)), isDefaultSort = FALSE)
  } else if (visual$type %in% c("line", "area")) {
    result$sortDefinition <- list(sort = list(list(
      field = roles$Category$projections[[1L]]$field, direction = "Ascending")), isDefaultSort = FALSE)
  }
  result
}

default_visual_title <- function(visual) {
  if (!is.null(visual$title)) return(visual$title)
  field_name <- function(x) {
    x <- field_list(x)
    if (!length(x)) return("")
    paste(vapply(x, function(z) if (is.character(z)) z else z$name, ""), collapse = ", ")
  }
  f <- visual$fields
  switch(visual$type,
    card = field_name(f$value), gauge = field_name(f$value), slicer = field_name(f$value),
    table = "Details", matrix = "Summary", text = "",
    scatter = paste(field_name(f$y), "by", field_name(f$x)),
    paste(field_name(f$y), "by", field_name(f$x)))
}

visual_container_style <- function(visual, theme, title) {
  title_show <- nzchar(title) && !visual$type %in% c("text", "slicer")
  alt <- if (!is.null(visual$alt)) visual$alt else if (nzchar(title)) title else
    if (visual$type == "text") visual$options$text else paste(visual$type, "visual")
  list(
    title = format_object(list(show = format_literal(title_show),
      text = format_literal(title), fontColor = format_color(theme$foreground),
      fontSize = format_literal(theme$title_size), fontFamily = format_literal(theme$font),
      alignment = format_literal("left"), titleWrap = format_literal(TRUE))),
    background = format_object(list(show = format_literal(visual$type != "text"),
      color = format_color(theme$surface), transparency = format_literal(0))),
    border = format_object(list(show = format_literal(FALSE), radius = format_literal(8))),
    padding = format_object(list(top = format_literal(12), bottom = format_literal(12),
      left = format_literal(16), right = format_literal(16))),
    general = format_object(list(altText = format_literal(alt))),
    visualTooltip = format_object(list(show = format_literal(TRUE))))
}

visual_specific_style <- function(visual, theme, position) {
  type <- visual$type
  o <- visual$options
  if (type == "text") return(list(general = format_object(list(paragraphs =
    lapply(strsplit(o$text, "\n", fixed = TRUE)[[1L]], function(paragraph)
      list(textRuns = list(list(value = paragraph, textStyle = list(
        fontFamily = theme$font,
        fontSize = paste0(if (is.null(o$font_size)) 18 else o$font_size, "pt"),
        color = if (is.null(o$color)) theme$foreground else o$color,
        fontWeight = if (isTRUE(o$bold)) "bold" else "normal"))),
        horizontalTextAlignment = "left"))))))
  if (type == "gauge" && length(o$constants)) return(list(axis = format_object(
    lapply(o$constants, format_literal))))
  if (type == "slicer") {
    modes <- c(dropdown = "Dropdown", list = "Basic", between = "Between",
               before = "Before", after = "After")
    mode <- if (is.null(o$style)) "Dropdown" else unname(modes[[o$style]])
    return(list(
      data = format_object(list(mode = format_literal(mode))),
      selection = format_object(list(singleSelect = format_literal(isTRUE(o$single_select)),
        selectAllCheckboxEnabled = format_literal(!isTRUE(o$single_select)))),
      header = format_object(list(show = format_literal(TRUE),
        text = format_literal(default_visual_title(visual)),
        fontColor = format_color(theme$foreground), textSize = format_literal(theme$font_size))),
      items = format_object(list(fontColor = format_color(theme$foreground),
        background = format_color(theme$surface), textSize = format_literal(theme$font_size)))))
  }
  if (type == "card") return(list(
    value = format_object(list(fontSize = format_literal(min(36, max(18, position$height * 0.23)))), list(id = "default")),
    label = format_object(list(show = format_literal(length(field_list(visual$fields$value)) > 1L),
      fontSize = format_literal(theme$font_size)), list(id = "default")),
    padding = format_object(list(paddingUniform = format_literal(0)), list(id = "default")),
    layout = format_object(list(paddingUniform = format_literal(0)), list(id = "default"))))
  if (type %in% c("table", "matrix")) return(list(
    columnHeaders = format_object(list(autoSizeColumnWidth = format_literal(TRUE),
      columnAdjustment = format_literal("growToFit"), fontColor = format_color(theme$foreground),
      backColor = format_color(theme$surface), fontSize = format_literal(theme$font_size))),
    values = format_object(list(fontColorPrimary = format_color(theme$foreground),
      fontColorSecondary = format_color(theme$foreground), backColorPrimary = format_color(theme$surface),
      backColorSecondary = format_color(theme$background), fontSize = format_literal(theme$font_size))),
    grid = format_object(list(gridVertical = format_literal(FALSE), gridHorizontal = format_literal(FALSE)))))
  objects <- list()
  if (type %in% c("bar", "line", "area", "pie", "donut", "scatter")) {
    show <- length(field_list(visual$fields$legend)) > 0L ||
      length(field_list(visual$fields$y)) > 1L || type %in% c("pie", "donut")
    objects$legend <- format_object(list(show = format_literal(show),
      position = format_literal("Top"), showTitle = format_literal(FALSE)))
  }
  if (type %in% c("bar", "line", "area", "pie", "donut", "treemap", "waterfall", "funnel"))
    objects$labels <- format_object(list(show = format_literal(isTRUE(o$labels))))
  if (type %in% c("bar", "line", "area", "waterfall", "scatter")) {
    objects$categoryAxis <- format_object(list(showAxisTitle = format_literal(FALSE),
      labelColor = format_color(theme$muted)))
    objects$valueAxis <- format_object(list(showAxisTitle = format_literal(FALSE),
      labelColor = format_color(theme$muted)))
  }
  if (type %in% c("line", "area")) objects$lineStyles <-
    format_object(list(strokeWidth = format_literal(2.5)))
  if (length(objects)) objects else NULL
}

compile_visual <- function(dashboard, visual, position, id, context) {
  native <- list(visualType = native_visual_type(visual))
  if (visual$type != "text") native$query <- visual_query(dashboard, visual)
  objects <- visual_specific_style(visual, dashboard$theme, position)
  formats <- visual_field_formats(dashboard, visual)
  if (length(formats)) objects$general <- c(objects$general, formats)
  if (!is.null(objects)) native$objects <- objects
  native$visualContainerObjects <- visual_container_style(visual, dashboard$theme,
                                                         default_visual_title(visual))
  native$drillFilterOtherVisuals <- TRUE
  if (visual$type == "slicer" && !is.null(visual$options$sync))
    native$syncGroup <- list(groupName = visual$options$sync, fieldChanges = TRUE, filterChanges = TRUE)
  result <- list(`$schema` = report_schema("visualContainer"), name = id,
                 position = position, visual = native)
  filters <- compile_filters(dashboard, visual$filters, context, visual$table)
  if (!is.null(filters)) result$filterConfig <- filters
  result
}

compile_theme <- function(theme) {
  list(`$schema` = "https://raw.githubusercontent.com/microsoft/powerbi-desktop-samples/main/Report%20Theme%20JSON%20Schema/reportThemeSchema-2.159.json",
       name = theme$name, dataColors = as.list(theme$colors),
       background = theme$surface, foreground = theme$foreground, tableAccent = theme$accent,
       firstLevelElements = theme$foreground, secondLevelElements = theme$muted,
       thirdLevelElements = theme$muted, fourthLevelElements = theme$muted,
       secondaryBackground = theme$background,
       textClasses = list(
         callout = list(fontFace = theme$font, fontSize = 32, color = theme$foreground),
         title = list(fontFace = theme$font, fontSize = theme$title_size, color = theme$foreground),
         header = list(fontFace = theme$font, fontSize = theme$font_size, color = theme$foreground),
         label = list(fontFace = theme$font, fontSize = theme$font_size, color = theme$muted)))
}

compile_report <- function(dashboard, report_dir, model_folder) {
  definition <- file.path(report_dir, "definition")
  dir.create(file.path(definition, "pages"), recursive = TRUE, showWarnings = FALSE)
  theme <- compile_theme(dashboard$theme)
  theme_name <- paste0("pbiweave-", stable_id(as.character(jsonlite::toJSON(theme, auto_unbox = TRUE))), ".json")
  theme_path <- file.path(report_dir, "StaticResources", "RegisteredResources", theme_name)
  dir.create(dirname(theme_path), recursive = TRUE, showWarnings = FALSE)
  write_json(theme, theme_path)
  version_at_import <- list(visual = "2.13.0", report = "3.3.0", page = "2.1.0")
  report <- list(`$schema` = report_schema("report"),
    themeCollection = list(customTheme = list(name = theme_name,
      reportVersionAtImport = version_at_import, type = "RegisteredResources")),
    resourcePackages = list(list(name = "RegisteredResources", type = "RegisteredResources",
      items = list(list(name = theme_name, path = theme_name, type = "CustomTheme")))),
    settings = list(useStylableVisualContainerHeader = TRUE,
      exportDataMode = "AllowSummarized", defaultDrillFilterOtherVisuals = TRUE,
      useEnhancedTooltips = TRUE, useDefaultAggregateDisplayName = TRUE),
    annotations = list(list(name = "pbiweave", value = "Generated from declarative R specifications.")))
  filters <- compile_filters(dashboard, dashboard$filters, "report")
  if (!is.null(filters)) report$filterConfig <- filters
  write_json(report, file.path(definition, "report.json"))
  write_json(list(`$schema` = report_schema("versionMetadata"), version = "2.0.0"),
             file.path(definition, "version.json"))
  write_json(list(`$schema` = "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json",
    version = "4.0", datasetReference = list(byPath = list(path = paste0("../", model_folder)))),
    file.path(report_dir, "definition.pbir"))
  page_ids <- sprintf("ReportSection%03d", seq_along(dashboard$pages))
  active <- which(!vapply(dashboard$pages, function(p) isTRUE(p$hidden), logical(1)))[1L]
  if (is.na(active)) active <- 1L
  write_json(list(`$schema` = report_schema("pagesMetadata"),
                  pageOrder = as.list(page_ids), activePageName = page_ids[[active]]),
             file.path(definition, "pages", "pages.json"))
  invisible(lapply(seq_along(dashboard$pages), function(i) {
    page <- dashboard$pages[[i]]
    page_dir <- file.path(definition, "pages", page_ids[[i]])
    dir.create(file.path(page_dir, "visuals"), recursive = TRUE, showWarnings = FALSE)
    background <- if (is.null(page$background)) dashboard$theme$background else page$background
    page_json <- list(`$schema` = report_schema("page"), name = page_ids[[i]],
      displayName = page$name, displayOption = "FitToPage", width = page$width, height = page$height,
      objects = list(background = format_object(list(color = format_color(background),
        transparency = format_literal(0)))))
    if (isTRUE(page$hidden)) page_json$visibility <- "HiddenInViewMode"
    filters <- compile_filters(dashboard, page$filters, paste0("page", i))
    if (!is.null(filters)) page_json$filterConfig <- filters
    positions <- layout_page(page)
    ids <- vapply(seq_along(page$visuals), function(j) native_visual_id(page$visuals[[j]], i, j), "")
    interactions <- compile_interactions(page, ids)
    if (length(interactions)) page_json$visualInteractions <- interactions
    write_json(page_json, file.path(page_dir, "page.json"))
    if (page$layout$header > 0) {
      header_id <- sprintf("header_%03d", i)
      header_dir <- file.path(page_dir, "visuals", header_id)
      dir.create(header_dir, showWarnings = FALSE)
      title <- if (identical(dashboard$title, page$name)) page$name else
        paste(dashboard$title, page$name, sep = " | ")
      header <- list(type = "text", title = "", alt = title, filters = list(),
        options = list(text = title, font_size = 24, color = dashboard$theme$foreground))
      position <- list(x = page$layout$padding, y = page$layout$padding, z = 0,
        width = page$width - 2 * page$layout$padding,
        height = page$layout$header, tabOrder = 0)
      header_json <- compile_visual(dashboard, header, position, header_id, header_id)
      header_json$visual$visualContainerObjects$padding <- format_object(list(
        top = format_literal(0), bottom = format_literal(0),
        left = format_literal(0), right = format_literal(0)))
      write_json(header_json, file.path(header_dir, "visual.json"))
    }
    invisible(lapply(seq_along(page$visuals), function(j) {
      visual_dir <- file.path(page_dir, "visuals", ids[[j]])
      dir.create(visual_dir, showWarnings = FALSE)
      position <- positions[[j]]
      position$z <- j * 1000L
      position$tabOrder <- j * 1000L
      write_json(compile_visual(dashboard, page$visuals[[j]], position, ids[[j]],
        paste0("page", i, "visual", j)), file.path(visual_dir, "visual.json"))
    }))
  }))
}
