\name{pbi_where}
\alias{pbi_where}
\title{Attach reusable filters to one visual}
\description{Adds typed include/exclude filters to a single visual specification.}
\usage{
pbi_where(x, ...)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{...}{One or more reusable pbi_filter() objects, or lists of those objects.}
}
\details{
A visual filter is an additional static constraint, not an R subset operation and not a selection input. Other visuals can still use rows excluded from this visual. Several arguments or a list are supported. A reusable filter can be shared between pbi_where(), pbi_filters() and pbi_page(filters = ...). The pipe form visual \%>\% pbi_filter(field, values) is an additive convenience alias.
}
\value{The modified pbi_visual specification.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_card("revenue") \%>\% pbi_where(pbi_filter("region", "West"))
d <- pbi_dashboard("Scoped KPI", pbi_demo_data()) \%>\%
  pbi_page("Compare", v, pbi_card("revenue", title = "All regions"))
pbi_validate(d)$valid
}
