\name{pbi_screen}
\alias{pbi_screen}
\title{Add an explicitly wired, Shiny-style screen}
\description{Adds a report page with a sidebar layout and interactions disabled by default.}
\usage{
pbi_screen(x, name, ..., layout = pbi_layout("sidebar", sidebar_mode = "slicers"),
                       size = "wide", width = NULL, height = NULL, interactions = "none")
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{name}{A unique model, measure, page, or example name, as described above.}
  \item{...}{Additional visual specifications, transformation arguments, or print arguments, depending on the function.}
  \item{layout}{A pbi_layout() specification. The default is a two-column grid, except for pbi_screen().}
  \item{size}{Page-size preset or numeric c(width, height). For text, an alias for font_size; for scatter, the bubble field.}
  \item{width}{Optional page width or required visual width in report-canvas units.}
  \item{height}{Optional page height or required visual height in report-canvas units.}
  \item{interactions}{"default" or "native" uses native rules; "filter" forces filtering; "none" disables same-page cross-visual selections.}
}
\details{
This is a page-construction wrapper. It intentionally uses interactions = "none" so omitted pbi_bind() calls are visible as missing behavior rather than hidden default links. Every input-to-output route must then be declared. Static report/page filters and synchronized slicer state are separate from these links. For a page without slicers choose a grid layout explicitly.
}
\value{The modified pbi_dashboard object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Screen", pbi_demo_data()) \%>\%
  pbi_screen("Explore", pbi_input("product", "product"),
    pbi_output("revenue", pbi_card("revenue")),
    pbi_output("trend", pbi_line("date", "revenue"))) \%>\%
  pbi_bind("product", c("revenue", "trend"))
pbi_flow(d)
}
