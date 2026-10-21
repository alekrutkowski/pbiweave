\name{pbi_place}
\alias{pbi_place}
\title{Place a visual precisely on a free-layout page}
\description{Assigns a visual's left/top position and width/height in report-canvas units.}
\usage{
pbi_place(x, left, top, width, height)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{left}{Distance from the page's left edge.}
  \item{top}{Distance from the page's top edge.}
  \item{width}{Optional page width or required visual width in report-canvas units.}
  \item{height}{Optional page height or required visual height in report-canvas units.}
}
\details{
Coordinates are measured from the top-left of the page. Use layout = pbi_layout("free"). Place data visuals below the reserved heading region; its height depends on the layout padding, header and gap settings. Bounds are checked, while overlaps are reported for review rather than rejected because intentional layering is possible. Geometry is fixed at compilation time.
}
\value{The modified pbi_visual object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Custom composition", pbi_demo_data()) \%>\%
  pbi_page("Overview", pbi_place(pbi_card("revenue"), 24, 90, 280, 160),
           pbi_place(pbi_bar("product", "cost"), 328, 90, 900, 560),
           layout = pbi_layout("free"))
pbi_validate(d)$valid
}
