\name{pbi_span}
\alias{pbi_span}
\title{Give a visual more grid cells}
\description{Sets the integer column and row span of a visual in a grid-based layout.}
\usage{
pbi_span(x, columns = 1L, rows = 1L)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{columns}{Positive integer grid-column span.}
  \item{rows}{Positive integer grid-row span.}
}
\details{
Spans change geometry, not the data query. A column span cannot exceed the number of grid columns. The layout solver allocates enough rows and shares the available page height between them. Large spans on a crowded page can still produce unreadable visuals; use pbi_validate() warnings and review the rendered page. Use pbi_place() rather than spans for a free layout.
}
\value{The modified pbi_visual object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Spans", pbi_demo_data()) \%>\%
  pbi_page("Overview", pbi_span(pbi_line("date", "revenue"), columns = 2),
           pbi_card("revenue"), pbi_card("cost"),
           layout = pbi_layout(columns = 2))
pbi_validate(d)$valid
}
