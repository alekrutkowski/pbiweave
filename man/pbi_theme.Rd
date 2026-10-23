\name{pbi_theme}
\alias{pbi_theme}
\title{Choose coordinated colors and typography}
\description{Constructs a theme specification used by the report and visual containers.}
\usage{
pbi_theme(preset = c("linen", "midnight", "ocean", "forest", "ink", "accessible",
                                 "european_commission"),
                      colors = NULL, background = NULL, surface = NULL,
                      foreground = NULL, muted = NULL, accent = NULL,
                      font = "Segoe UI", font_size = 11, title_size = 15, text_size = NULL, palette = NULL,
                      title_color = NULL)
}
\arguments{
  \item{preset}{One of the coordinated built-in theme names.}
  \item{colors}{Optional vector of at least three categorical #RRGGBB colors.}
  \item{background}{Optional scalar #RRGGBB page background; on pbi_page(), overrides the report theme.}
  \item{surface}{Optional #RRGGBB visual-panel background.}
  \item{foreground}{Optional scalar #RRGGBB text color.}
  \item{muted}{Optional scalar #RRGGBB muted-text color.}
  \item{accent}{Optional scalar #RRGGBB highlight color.}
  \item{font}{Font-family name referenced by the report. When omitted, european_commission uses Arial and existing presets use Segoe UI. An explicit font always takes precedence.}
  \item{font_size}{Base font size in points, or the static text size for pbi_text().}
  \item{title_size}{Title font size in points.}
  \item{text_size}{Named alias for theme font_size; title_size remains separate.}
  \item{palette}{Named alias for colors; supply at least three #RRGGBB values.}
  \item{title_color}{Optional scalar #RRGGBB heading color, independent of foreground. NULL uses #003399 for european_commission and the effective foreground for existing presets.}
}
\details{
Seven coordinated presets are available: linen, midnight, ocean, forest, ink, accessible and european_commission. The European Commission preset is an original EC-inspired adaptation combining the supplied EC Colour Palette 2024 presentation template with current Europa Component Library surfaces; it is not an official or certified Commission theme. Its categorical colors are #003399, #44BA7E, #FF712C, #48038C, #FFD34E, #DD0C86 and #000083. It uses blue headings (#003399), dark body text (#00002E), a pale page background (#F2F6FF), white visual surfaces (#FFFFFF), muted text (#505070) and a web-blue accent (#0046FF). When font is omitted, this preset selects Arial; the six existing presets retain Segoe UI. An explicitly supplied font always wins. title_color controls headings independently from body text. NULL selects the EC blue for european_commission and otherwise follows the effective foreground, including a foreground override. The complete original theme controls are preserved, including muted/accent colors and separate base/title text sizes. colors needs at least three #RRGGBB values; all individual colors must be scalar. palette aliases colors and text_size aliases font_size, with conflicts rejected. Font families are references, not embedded font files. Verify font availability, contrast, label fit and alternative text in the intended viewing environment. A palette alone does not certify accessibility, and light chart colors need suitable labels and other visual distinctions.
}
\value{A pbi_theme object accepted by pbi_dashboard().}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
theme <- pbi_theme("european_commission")
d <- pbi_dashboard("European Commission style", pbi_demo_data(), theme = theme) \%>\%
  pbi_page("Overview", pbi_bar("region", "revenue"))
pbi_validate(d)$valid
# Override heading color independently on an existing preset.
pbi_theme("linen", foreground = "#222222", title_color = "#003399")
# Explicit fonts take precedence over preset defaults.
pbi_theme("european_commission", font = "Segoe UI")
}
