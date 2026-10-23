# European Commission theme

`european_commission` is the seventh pbiweave preset, added in version 0.4.0.
It combines the supplied Commission PowerPoint template's colors and typography
with the surfaces, text colors and highlights of the current European Commission
website. This is an independent visual adaptation with no official affiliation
or endorsement.

## Use the preset

The name works wherever pbiweave accepts a theme. This complete example uses the
package's deterministic fictional demonstration data:

```r
library(pbiweave)

project <- pbi_example("showcase", theme = "european_commission") %>%
  pbi_compile("commission-showcase-v040", bundle = TRUE)

stopifnot(pbi_check(project, verify_hashes = TRUE)$valid)
```

You can pass a theme object to your own report and adjust its text sizes:

```r
report <- pbi_dashboard(
  "Programme overview", pbi_demo_data(),
  theme = pbi_theme("european_commission", font_size = 12, title_size = 17)
) %>%
  pbi_page(
    "Overview",
    pbi_slicer("region", title = "Region"),
    pbi_card("revenue", title = "Revenue"),
    pbi_bar("product", "revenue", title = "Revenue by product"),
    pbi_line("date", "revenue", legend = "region", title = "Monthly revenue"),
    layout = pbi_layout("sidebar", columns = 2)
  )

project <- report %>% pbi_compile("commission-programme-v040", bundle = TRUE)
```

A complete example is installed at
`system.file("examples", "03-european-commission.R", package = "pbiweave")`.
After compilation, open the `.pbip` in Power BI Desktop and select
**Home ➜ Refresh**. Inspect the report before saving it as `.pbix`.
`pbi_check()` checks project structure and hashes; it does not confirm native
refresh or rendering.

## What comes from the supplied PowerPoint

The reference is `Presentation template.pptx`. Its main theme,
`ppt/theme/theme1.xml`, names its color scheme **EC Colour Palette 2024**.
`ppt/slideMasters/_rels/slideMaster1.xml.rels` links the slide master to this
file. The preset takes all six accent values from that scheme, with template
blue added first and the accents reordered to separate the two dark blues:

| Series order | Color | Template element | Role in this preset |
|---|---|---|---|
| 1 | `#003399` | `a:clrScheme/a:dk2` | Leading series and title blue |
| 2 | `#44BA7E` | `a:clrScheme/a:accent1` | Green |
| 3 | `#FF712C` | `a:clrScheme/a:accent4` | Orange |
| 4 | `#48038C` | `a:clrScheme/a:accent3` | Purple |
| 5 | `#FFD34E` | `a:clrScheme/a:accent5` | Yellow |
| 6 | `#DD0C86` | `a:clrScheme/a:accent6` | Magenta |
| 7 | `#000083` | `a:clrScheme/a:accent2` | Deep blue |

In `ppt/slideMasters/slideMaster1.xml`, the title text style uses `tx2`, and
`p:clrMap` maps `tx2` to `dk2`. This is the source of the blue title treatment.
Both the major and minor Latin font entries in `theme1.xml` are **Arial**.
The template's hyperlink and followed-hyperlink entries are both `#003399`;
the exported Power BI theme uses that value for `hyperlink` and
`visitedHyperlink`.

The template also defines pale mint `#C6E5DF` in `a:clrScheme/a:lt2`. It is
available as a background override rather than the default report canvas:

```r
mint_report <- pbi_example("themes", theme =
  pbi_theme("european_commission", background = "#C6E5DF"))
```

The other theme files inside the supplied presentation contain Office palette
values. They are not the source of the new categorical palette.

## What comes from the Commission website

The [EC color guidance](https://ec.europa.eu/component-library/ec/guidelines/colours/)
and the public [Commission homepage](https://commission.europa.eu/index_en)
were checked on **23 October 2026**. The live site uses the ECL v5 color system.
The following values provide the web part of the adaptation:

| pbiweave or Power BI field | Value | EC token or source |
|---|---|---|
| `background` in `pbi_theme()` | `#F2F6FF` | Primary-50 / surface-primary-lowest |
| `surface` | `#FFFFFF` | White / inverted surface |
| `foreground` | `#00002E` | Grey-950 |
| `muted` | `#505070` | Grey-700 |
| `accent` / exported `tableAccent` | `#0046FF` | Primary-600 |
| Exported `good` | `#049E62` | Success-700 |
| Exported `bad` | `#CB2029` | Error-600 |
| Exported `neutral` | `#FF8A20` | Warning-500 |

The template blue `#003399` deliberately remains the title and leading-series
color, while current web blue `#0046FF` supplies the highlight/accent. This
preserves the supplied presentation's identity without presenting older EC
web palettes as current standards. Semantic colors define defaults for visuals
that use them; they do not automatically create conditional-formatting rules.

The [current EC typography guidance](https://ec.europa.eu/component-library/ec/guidelines/typography/)
specifies `Inter, Arial, sans-serif`. This preset uses **Arial** to match the
supplied presentation and the web stack's named fallback. It does not claim
that Arial is the current website's primary font. To request Inter or another
installed font explicitly:

```r
web_type <- pbi_theme("european_commission", font = "Inter")
```

Font names refer to fonts available in the viewing environment. No font file
is embedded or installed by pbiweave.

## Customize titles and surfaces

`title_color` is an optional final argument of `pbi_theme()`. It controls the
theme's title color independently of the body foreground. Existing positional
arguments retain their order.

```r
custom <- pbi_theme(
  "european_commission",
  background = "#FFFFFF", title_color = "#000083",
  font_size = 12, title_size = 17
)

project <- pbi_example("showcase", theme = custom) %>%
  pbi_compile("commission-custom-v040", bundle = TRUE)
```

For `european_commission`, omitting `font` selects Arial. An explicit font value
is honored, including `font = "Segoe UI"`. The six older presets keep their
existing palette and font defaults. Their titles continue to follow the body
foreground unless `title_color` is supplied.

The R `background` setting is the report canvas and alternating table surface.
The exported JSON `background` is the visual surface, here white;
`secondaryBackground` carries the light canvas color. Compiled R reports also
set page and visual formatting explicitly.

## Import the standalone JSON theme

The repository includes `inst/themes/european-commission.json`. After installing
the package, locate it with:

```r
system.file("themes", "european-commission.json", package = "pbiweave")
```

This JSON supplies palette, typography and semantic defaults for an existing
Power BI report. Import it using Power BI's custom-theme command; current
Desktop versions use **Design ➜ Import theme**. See Microsoft's
[report-theme instructions](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-report-themes).
Manual visual formatting can take precedence over imported theme defaults
until the relevant formatting is reset. Importing the JSON alone does not
recreate the explicit page layouts and visual settings emitted by
`pbi_compile()`.

For package development, run `Rscript tools/export-themes.R` from the repository
root to regenerate the bundled JSON from the package's theme compiler.

## Design and attribution notes

Keep yellow as a fill or accent with readable dark labels. Where neighboring
series are hard to distinguish, use labels, markers or a smaller subset of the
palette. Colors alone do not establish accessibility; inspect the final report
at its intended size and in its viewing environment.

The package bundles no Commission logo, emblem, reference presentation, ECL
implementation code or font files. The new theme adds no runtime dependencies.
Identity references and existing dependency notices are recorded in
[ACKNOWLEDGEMENTS.md](../ACKNOWLEDGEMENTS.md).
