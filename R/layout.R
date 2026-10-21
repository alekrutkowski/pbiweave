# Reusable automatic page layouts
# @param type Grid, sidebar (first visual left), focus (first visual above),
#   or free (every visual uses pbi_place).
# @param columns Number of grid columns.
# @param gap Space between visuals in pixels.
# @param padding Page margin in pixels.
# @param header Height reserved for the automatic page heading; zero disables it.
# @param sidebar_width Proportion of usable width assigned to the first visual.
# @param focus_ratio Proportion of usable height assigned to the first visual.
# @return A pbi_layout object.
# @export
pbi_layout <- function(type = c("grid", "sidebar", "focus", "free"), columns = 2L,
                       gap = 20, padding = 24, header = 56,
                       sidebar_width = 0.23, focus_ratio = 0.6, margin = NULL, sidebar_mode = c("first", "slicers")) {
  if (!is.null(margin)) {
    if (!missing(padding)) abort("Use padding or margin, not both.")
    padding <- margin
  }
  type <- match.arg(type)
  sidebar_mode <- match.arg(sidebar_mode)
  number(columns, "columns", 1, 24, TRUE)
  number(gap, "gap", 0, 200); number(padding, "padding", 0, 400); number(header, "header", 0, 400)
  number(sidebar_width, "sidebar_width", 0.1, 10000)
  if (sidebar_width > 0.8 && sidebar_width < 100) abort("sidebar_width must be a fraction in [0.1, 0.8] or pixels >= 100.")
  number(focus_ratio, "focus_ratio", 0.1, 0.9)
  structure(list(type = type, columns = as.integer(columns), gap = gap, padding = padding,
    header = header, sidebar_width = sidebar_width, focus_ratio = focus_ratio, sidebar_mode = sidebar_mode), class = "pbi_layout")
}

# Append a report page
# @param x A dashboard.
# @param name Page label.
# @param ... Visuals, or lists of visuals.
# @param layout A pbi_layout object or layout name.
# @param size wide (1280x720), standard (1024x768), portrait (720x1280),
#   a4 (1123x794), or a numeric width/height pair.
# @param filters List of pbi_filter objects.
# @param interactions Native default interactions, filter, or none.
# @param hidden Hide the page in reading mode.
# @param background Optional #RRGGBB page background.
# @return The modified dashboard.
# @export
pbi_page <- function(x, name, ..., layout = pbi_layout(), size = "wide", filters = list(),
                     interactions = c("default", "filter", "none"), hidden = FALSE, background = NULL,
                     width = NULL, height = NULL) {
  assert_dashboard(x); object_name(name, "Page name"); scalar_flag(hidden, "hidden")
  if (any(vapply(x$pages, function(p) tolower(p$name) == tolower(name), logical(1)))) abort("Page name already exists: ", name)
  if (is.character(layout)) layout <- pbi_layout(layout)
  if (!inherits(layout, "pbi_layout")) abort("layout must be a pbi_layout or its type name.")
  if (identical(size, "custom")) size <- "wide"
  dimensions <- page_size(size)
  if (!is.null(width)) dimensions[1L] <- width
  if (!is.null(height)) dimensions[2L] <- height
  dimensions <- page_size(dimensions)
  if (length(interactions) == 1L && identical(interactions, "native")) interactions <- "default"
  if (!is.null(background)) { scalar_string(background, "background"); color_check(background) }
  visuals <- flatten_specs(list(...), "pbi_visual")
  if (!length(visuals)) abort("A page requires at least one visual.")
  visuals <- lapply(seq_along(visuals), function(i) {
    v <- visuals[[i]]; v$id <- v$id %||% paste0("v", i); v
  })
  unique_names(vapply(visuals, `[[`, character(1), "id"), "Visual IDs")
  page <- list(name = name, visuals = visuals, layout = layout, width = dimensions[1L],
    height = dimensions[2L], filters = flatten_specs(list(filters), "pbi_filter"),
    interactions = match.arg(interactions, c("default", "filter", "none")), hidden = hidden, background = background,
    bindings = list())
  layout_page(page)
  x$pages <- c(x$pages, list(page))
  x
}

page_size <- function(size) {
  if (is.character(size)) {
    size <- match.arg(size, c("wide", "standard", "portrait", "a4"))
    return(switch(size, wide = c(1280, 720), standard = c(1024, 768),
                  portrait = c(720, 1280), a4 = c(1123, 794)))
  }
  if (!is.numeric(size) || length(size) != 2L || any(!is.finite(size)) || any(size < 200 | size > 10000))
    abort("size must be a preset or c(width, height), with each dimension in [200, 10000].")
  unname(size)
}

grid_positions <- function(visuals, box, layout) {
  if (!length(visuals)) return(list())
  cols <- layout$columns
  if (any(vapply(visuals, function(v) v$span[["columns"]] > cols, logical(1))))
    abort("A visual's column span exceeds the grid's columns.")
  max_rows <- sum(vapply(visuals, function(v) v$span[["rows"]], numeric(1)))
  state <- Reduce(function(state, visual) {
    cs <- visual$span[["columns"]]; rs <- visual$span[["rows"]]
    eligible <- Filter(function(i) {
      row <- (i - 1L) %/% cols + 1L; col <- (i - 1L) %% cols + 1L
      col + cs - 1L <= cols && row + rs - 1L <= max_rows &&
        !any(state$used[seq.int(row, length.out = rs), seq.int(col, length.out = cs), drop = FALSE])
    }, seq_len(max_rows * cols))
    if (!length(eligible)) abort("Could not place visual in the grid.")
    i <- eligible[[1L]]; row <- (i - 1L) %/% cols + 1L; col <- (i - 1L) %% cols + 1L
    state$used[seq.int(row, length.out = rs), seq.int(col, length.out = cs)] <- TRUE
    state$slots <- c(state$slots, list(c(row = row, col = col, rs = rs, cs = cs)))
    state
  }, visuals, init = list(used = matrix(FALSE, nrow = max_rows, ncol = cols), slots = list()))
  rows <- max(vapply(state$slots, function(s) s[["row"]] + s[["rs"]] - 1L, numeric(1)))
  cell_w <- (box$width - (cols - 1L) * layout$gap) / cols
  cell_h <- (box$height - (rows - 1L) * layout$gap) / rows
  if (cell_w <= 0 || cell_h <= 0) abort("Layout spacing leaves no room for visuals.")
  lapply(state$slots, function(s) list(
    x = box$x + (s[["col"]] - 1L) * (cell_w + layout$gap),
    y = box$y + (s[["row"]] - 1L) * (cell_h + layout$gap),
    width = s[["cs"]] * cell_w + (s[["cs"]] - 1L) * layout$gap,
    height = s[["rs"]] * cell_h + (s[["rs"]] - 1L) * layout$gap))
}

layout_page <- function(page) {
  l <- page$layout
  if (l$type == "free") {
    if (any(vapply(page$visuals, function(v) is.null(v$position), logical(1))))
      abort("Free layout requires pbi_place() for every visual.")
    positions <- lapply(page$visuals, `[[`, "position")
  } else {
    if (any(vapply(page$visuals, function(v) !is.null(v$position), logical(1))))
      abort("pbi_place() requires a free layout.")
    top <- l$padding + l$header + if (l$header > 0) l$gap else 0
    box <- list(x = l$padding, y = top, width = page$width - 2 * l$padding,
                height = page$height - l$padding - top)
    if (box$width <= 0 || box$height <= 0) abort("Margins and header leave no room for visuals.")
    if (l$type == "grid") positions <- grid_positions(page$visuals, box, l)
    else if (length(page$visuals) == 1L) positions <- list(box)
    else if (l$type == "sidebar") {
      left <- box; left$width <- if (l$sidebar_width < 1) (box$width - l$gap) * l$sidebar_width else l$sidebar_width
      right <- box; right$x <- left$x + left$width + l$gap; right$width <- box$width - left$width - l$gap
      side <- if (identical(l$sidebar_mode, "slicers"))
        which(vapply(page$visuals, function(v) v$type == "slicer", logical(1))) else 1L
      if (!length(side)) side <- 1L
      main <- setdiff(seq_along(page$visuals), side)
      positions <- vector("list", length(page$visuals))
      if (!length(main)) positions <- grid_positions(page$visuals, box, l) else {
        side_layout <- l; side_layout$columns <- 1L
        positions[side] <- grid_positions(page$visuals[side], left, side_layout)
        positions[main] <- grid_positions(page$visuals[main], right, l)
      }
    } else {
      first <- box; first$height <- (box$height - l$gap) * l$focus_ratio
      rest <- box; rest$y <- first$y + first$height + l$gap; rest$height <- box$height - first$height - l$gap
      positions <- c(list(first), grid_positions(page$visuals[-1L], rest, l))
    }
  }
  if (any(vapply(positions, function(p) p$x < 0 || p$y < 0 || p$width <= 0 || p$height <= 0 ||
      p$x + p$width > page$width + 1e-6 || p$y + p$height > page$height + 1e-6, logical(1))))
    abort("One or more visuals extend beyond the page canvas.")
  positions
}
