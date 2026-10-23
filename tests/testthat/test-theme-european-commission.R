test_that("European Commission preset works through public constructors", {
  theme <- pbi_theme("european_commission")
  expect_s3_class(theme, "pbi_theme")
  expect_identical(theme$name, "pbiweave-european_commission")
  expect_identical(theme$font, "Arial")
  expect_identical(theme$colors,
    c("#003399", "#44BA7E", "#FF712C", "#48038C", "#FFD34E", "#DD0C86", "#000083"))
  expect_identical(theme$background, "#F2F6FF")
  expect_identical(theme$surface, "#FFFFFF")
  expect_identical(theme$foreground, "#00002E")
  expect_identical(theme$muted, "#505070")
  expect_identical(theme$accent, "#0046FF")
  expect_identical(theme$title_color, "#003399")
  expect_identical(pbi_dashboard("Commission", theme = "european_commission")$theme, theme)
  expect_identical(pbi_example("themes", theme = "european_commission")$theme, theme)
  expect_identical(pbi_theme("european_commission", font = "Arial"), theme)
})

test_that("the original six preset defaults and default choice are preserved", {
  # Regression snapshots from 0.3.1, including field order and absent new fields.
  original <- list(
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
  invisible(lapply(names(original), function(preset) {
    expected <- c(list(name = paste0("pbiweave-", preset)), original[[preset]],
                  list(font = "Segoe UI", font_size = 11, title_size = 15))
    expect_identical(unclass(pbi_theme(preset)), expected, info = preset)
  }))
  expect_identical(pbi_theme(), pbi_theme("linen"))
  expect_identical(pbi_dashboard("Default")$theme, pbi_theme("linen"))
})

test_that("Commission theme overrides are independent and aliases still agree", {
  palette <- c("#112233", "#445566", "#778899")
  theme <- pbi_theme("european_commission", colors = palette,
    background = "#EFF0F1", surface = "#FAFAFA", foreground = "#111111",
    muted = "#555555", accent = "#224466", font = "Segoe UI",
    font_size = 12, title_size = 19, title_color = "#663399")
  expect_identical(theme$colors, palette)
  expect_identical(theme[c("background", "surface", "foreground", "muted", "accent")],
    list(background = "#EFF0F1", surface = "#FAFAFA", foreground = "#111111",
         muted = "#555555", accent = "#224466"))
  expect_identical(theme$font, "Segoe UI")
  expect_identical(theme$title_color, "#663399")
  expect_identical(theme$font_size, 12)
  expect_identical(theme$title_size, 19)
  expect_identical(pbi_theme("european_commission", palette = palette, text_size = 12),
                   pbi_theme("european_commission", colors = palette, font_size = 12))
  expect_error(pbi_theme("european_commission", palette = palette, colors = palette), "not both")
  expect_error(pbi_theme("european_commission", font_size = 12, text_size = 12), "not both")
  expect_error(pbi_theme("european_commission", title_color = "blue"), "RRGGBB")
  expect_error(pbi_theme("european_commission", title_color = c("#003399", "#0046FF")), "single")
  expect_error(pbi_theme("european_commission", font = NULL), "font")
})

test_that("Commission theme JSON and the importable resource remain synchronized", {
  theme <- compile_theme(pbi_theme("european_commission"))
  expect_identical(unlist(theme$dataColors, use.names = FALSE),
                   pbi_theme("european_commission")$colors)
  expect_identical(theme$background, "#FFFFFF")
  expect_identical(theme$secondaryBackground, "#F2F6FF")
  expect_identical(theme$tableAccent, "#0046FF")
  expect_identical(theme$textClasses$title$color, "#003399")
  expect_identical(theme$textClasses$header$color, "#003399")
  expect_identical(theme$textClasses$callout$color, "#00002E")
  expect_identical(theme$textClasses$label$color, "#505070")
  expect_true(all(vapply(theme$textClasses, function(x) identical(x$fontFace, "Arial"), logical(1))))
  expect_identical(theme[c("good", "bad", "neutral", "hyperlink", "visitedHyperlink")],
    list(good = "#049E62", bad = "#CB2029", neutral = "#FF8A20",
         hyperlink = "#003399", visitedHyperlink = "#003399"))
  resource <- system.file("themes", "european-commission.json", package = "pbiweave")
  if (!nzchar(resource)) resource <- test_path("..", "..", "inst", "themes", "european-commission.json")
  expect_true(file.exists(resource))
  expect_equal(jsonlite::fromJSON(resource, simplifyVector = FALSE), theme)
})

test_that("legacy themes and heading overrides preserve independent body text", {
  legacy <- pbi_theme("ink", foreground = "#123456")
  expect_null(legacy$title_color)
  compiled <- compile_theme(legacy)
  expect_identical(compiled$textClasses$title$color, "#123456")
  expect_identical(compiled$textClasses$header$color, "#123456")
  expect_identical(compiled$textClasses$callout$color, "#123456")
  expect_null(compiled$good)
  expect_null(compiled$hyperlink)
  color <- function(x) x$solid$color$expr$Literal$Value
  pos <- list(x = 24, y = 24, z = 1000, width = 400, height = 240, tabOrder = 1000)
  invisible(lapply(list(legacy, pbi_theme("ink", foreground = "#123456", title_color = "#654321")),
    function(theme) {
      heading <- if (is.null(theme$title_color)) "'#123456'" else "'#654321'"
      container <- visual_container_style(pbi_bar("group", "amount"), theme, "Title")
      expect_identical(color(container$title[[1]]$properties$fontColor), heading)
      slicer <- visual_specific_style(pbi_slicer("group"), theme, pos)
      expect_identical(color(slicer$header[[1]]$properties$fontColor), heading)
      expect_identical(color(slicer$items[[1]]$properties$fontColor), "'#123456'")
      invisible(lapply(list(pbi_table(c("group", "amount")),
                            pbi_matrix("group", values = "amount")), function(visual) {
        style <- visual_specific_style(visual, theme, pos)
        expect_identical(color(style$columnHeaders[[1]]$properties$fontColor), heading)
        expect_identical(color(style$values[[1]]$properties$fontColorPrimary), "'#123456'")
      }))
    }))
})

test_that("Commission theme is applied to complete TMDL and TMSL projects", {
  root <- tempfile("pbiweave-ec-test-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dashboard <- pbi_dashboard("Commission theme", data.table::data.table(
    group = c("A", "B", "A", "B"), period = c("First", "First", "Second", "Second"),
    amount = c(10, 20, 15, 25)), theme = "european_commission") %>%
    pbi_page("Overview",
      pbi_bar("group", "amount", title = "Amounts"),
      pbi_slicer("group", title = "Group"),
      pbi_table(c("group", "amount")),
      pbi_text("Illustrative data"),
      pbi_matrix("group", columns = "period", values = "amount"),
      pbi_text("Explicit color", color = "#663399"),
      layout = pbi_layout(columns = 3, header = 56))
  color <- function(x) x$solid$color$expr$Literal$Value
  invisible(lapply(c("tmdl", "tmsl"), function(format) {
    project <- pbi_compile(dashboard, file.path(root, format), model_format = format)
    expect_true(pbi_check(project, verify_hashes = TRUE)$valid)
    read <- function(...) jsonlite::fromJSON(file.path(project$report, ...), simplifyVector = FALSE)
    report <- read("definition", "report.json")
    resource <- report$themeCollection$customTheme$name
    expect_equal(report$resourcePackages[[1]]$items[[1]]$path, resource)
    expect_equal(read("StaticResources", "RegisteredResources", resource),
                 compile_theme(dashboard$theme))
    page <- read("definition", "pages", "ReportSection001", "page.json")
    expect_identical(color(page$objects$background[[1]]$properties$color), "'#F2F6FF'")
    visual <- function(id) read("definition", "pages", "ReportSection001", "visuals", id, "visual.json")$visual
    chart <- visual("v001_001")
    expect_identical(color(chart$visualContainerObjects$title[[1]]$properties$fontColor), "'#003399'")
    expect_identical(chart$visualContainerObjects$title[[1]]$properties$fontFamily$expr$Literal$Value, "'Arial'")
    expect_identical(color(chart$visualContainerObjects$background[[1]]$properties$color), "'#FFFFFF'")
    expect_identical(color(chart$objects$categoryAxis[[1]]$properties$labelColor), "'#505070'")
    slicer <- visual("v001_002")
    expect_identical(color(slicer$objects$header[[1]]$properties$fontColor), "'#003399'")
    expect_identical(color(slicer$objects$items[[1]]$properties$fontColor), "'#00002E'")
    invisible(lapply(c("v001_003", "v001_005"), function(id) {
      table <- visual(id)
      expect_identical(color(table$objects$columnHeaders[[1]]$properties$fontColor), "'#003399'")
      expect_identical(color(table$objects$values[[1]]$properties$fontColorPrimary), "'#00002E'")
    }))
    text_style <- function(id) visual(id)$objects$general[[1]]$properties$paragraphs[[1]]$textRuns[[1]]$textStyle
    expect_identical(text_style("v001_004")$color, "#00002E")
    expect_identical(text_style("v001_004")$fontFamily, "Arial")
    expect_identical(text_style("v001_006")$color, "#663399")
    expect_identical(text_style("header_001")$color, "#003399")
    expect_identical(text_style("header_001")$fontFamily, "Arial")
  }))
})
