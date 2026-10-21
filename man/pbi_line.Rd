\name{pbi_line}
\alias{pbi_line}
\title{Show a trend or ordered comparison}
\description{Plots one or more value series against an ordered category, commonly a date.}
\usage{
pbi_line(x, y, legend = NULL, table = NULL, title = NULL, alt = NULL,
                     aggregate = "sum", labels = FALSE, tooltip = NULL,
                     id = NULL, series = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{y}{The value field or list of value fields. Use pbi_aggregate() or pbi_ref() when the default summary is not appropriate.}
  \item{legend}{Optional unaggregated categorical series field; series is its named alias.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{labels}{Whether native data labels are displayed.}
  \item{tooltip}{Optional field references for the native tooltip role.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{series}{Optional grouping field used as a legend/series split.}
}
\details{
Prepare dates and any rolling averages in R. A date column is a real Date value, not a formatted string. Precomputed rolling averages do not recalculate when a viewer filters the report. A basic sum or mean still aggregates within the selected native filter context. Multiple values can be supplied as a list of field references.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_line("date", "revenue", series = "region", title = "Monthly revenue")
d <- pbi_dashboard("Visual example", pbi_demo_data()) \%>\%
  pbi_page("Example", v)
pbi_validate(d)$valid
}
