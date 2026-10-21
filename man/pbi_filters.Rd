\name{pbi_filters}
\alias{pbi_filters}
\title{Attach reusable filters to the entire report}
\description{Adds one or more pbi_filter() specifications to report-level filter context.}
\usage{
pbi_filters(x, ...)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{...}{One or more reusable pbi_filter() objects, or lists of those objects.}
}
\details{
Each argument can be a filter or a list of filters. Added constraints combine with existing report, page, visual and slicer filters. A filter is validated against the referenced column type, including blank handling. Qualify dimension columns with table. Report-level constraints are not row-level security: all embedded source values remain accessible to a recipient. Use pbi_page(filters = ...) for page scope and pbi_where() for a visual.
}
\value{The modified pbi_dashboard specification.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
regions <- pbi_filter("region", c("East", "West"))
d <- pbi_dashboard("Subset", pbi_demo_data()) \%>\%
  pbi_filters(regions) \%>\%
  pbi_page("Comparison", pbi_bar("region", "revenue"))
pbi_validate(d)$valid
}
