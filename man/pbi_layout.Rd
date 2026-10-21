\name{pbi_layout}
\alias{pbi_layout}
\title{Declare how visuals occupy a fixed report canvas}
\description{Constructs a grid, sidebar, focus, or free-position layout.}
\usage{
pbi_layout(type = c("grid", "sidebar", "focus", "free"), columns = 2L,
                       gap = 20, padding = 24, header = 56,
                       sidebar_width = 0.23, focus_ratio = 0.6, margin = NULL, sidebar_mode = c("first", "slicers"))
}
\arguments{
  \item{type}{Layout type: grid, sidebar, focus or free.}
  \item{columns}{Grid column count, matrix column-group fields, or table fields, depending on the function.}
  \item{gap}{Nonnegative space between visual cells.}
  \item{padding}{Outer page margin in canvas pixels. margin is an alias.}
  \item{header}{Height reserved for the generated heading band; zero omits the heading.}
  \item{sidebar_width}{A width fraction in [0.1, 0.8], or at least 100 canvas pixels.}
  \item{focus_ratio}{Fraction of the usable focus-layout height devoted to the first visual.}
  \item{margin}{Nonnegative outer page margin.}
  \item{sidebar_mode}{"first" preserves the original first-visual rail; "slicers" places all slicers there.}
}
\details{
grid places visuals in declaration order and honors pbi_span(). sidebar preserves the original first-visual-on-the-left behavior by default; sidebar_mode = "slicers" instead places every slicer in the left rail. pbi_screen() uses that second mode. sidebar_width is a fraction from 0.1 to 0.8, or at least 100 canvas pixels. focus enlarges the first visual above the rest, using focus_ratio. free uses pbi_place() coordinates. padding is the page margin; margin is a named alias. header reserves heading space, and header = 0 removes that generated heading. These are fixed canvas layouts, not CSS breakpoints.
}
\value{A pbi_layout object accepted by pbi_page() or pbi_screen().}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Grid", pbi_demo_data()) \%>\%
  pbi_page("Overview", pbi_card("revenue"), pbi_card("cost"),
           pbi_span(pbi_line("date", "revenue"), columns = 2),
           layout = pbi_layout("grid", columns = 2, gap = 20))
pbi_validate(d)$valid
}
