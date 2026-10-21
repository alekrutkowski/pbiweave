\name{pbi_theme}
\alias{pbi_theme}
\title{Choose coordinated colors and typography}
\description{Constructs a theme specification used by the report and visual containers.}
\usage{
pbi_theme(preset = c("linen", "midnight", "ocean", "forest", "ink", "accessible"),
                      colors = NULL, background = NULL, surface = NULL,
                      foreground = NULL, muted = NULL, accent = NULL,
                      font = "Segoe UI", font_size = 11, title_size = 15, text_size = NULL, palette = NULL)
}
\arguments{
  \item{preset}{One of the coordinated built-in theme names.}
  \item{colors}{Optional vector of at least three categorical #RRGGBB colors.}
  \item{background}{Optional scalar #RRGGBB page background; on pbi_page(), overrides the report theme.}
  \item{surface}{Optional #RRGGBB visual-panel background.}
  \item{foreground}{Optional scalar #RRGGBB text color.}
  \item{muted}{Optional scalar #RRGGBB muted-text color.}
  \item{accent}{Optional scalar #RRGGBB highlight color.}
  \item{font}{Font-family name referenced by the report.}
  \item{font_size}{Base font size in points, or the static text size for pbi_text().}
  \item{title_size}{Title font size in points.}
  \item{text_size}{Named alias for theme font_size; title_size remains separate.}
  \item{palette}{Named alias for colors; supply at least three #RRGGBB values.}
}
\details{
Six coordinated presets are available: linen, midnight, ocean, forest, ink and accessible. The complete original theme controls are preserved, including muted/accent colors and separate base/title text sizes. colors needs at least three #RRGGBB values; all individual colors must be scalar. palette aliases colors and text_size aliases font_size, with conflicts rejected. Font families are references, not embedded font files. Verify font availability, contrast, label fit and alternative text in the intended viewing environment; a palette alone does not certify accessibility.
}
\value{A pbi_theme object accepted by pbi_dashboard().}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
theme <- pbi_theme("midnight", text_size = 13)
d <- pbi_dashboard("Dark report", pbi_demo_data(), theme = theme) \%>\%
  pbi_page("Overview", pbi_bar("region", "revenue"))
pbi_validate(d)$valid
}
