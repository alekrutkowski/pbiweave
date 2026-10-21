\name{pbi_scatter}
\alias{pbi_scatter}
\title{Compare observations or aggregates in two dimensions}
\description{Creates a scatter chart, optionally encoding group with color and magnitude with bubble size.}
\usage{
pbi_scatter(x, y, size = NULL, details = NULL, legend = NULL,
                        table = NULL, title = NULL, alt = NULL, aggregate = "sum", tooltip = NULL,
                     id = NULL, series = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{y}{The value field or list of value fields. Use pbi_aggregate() or pbi_ref() when the default summary is not appropriate.}
  \item{size}{Page-size preset or numeric c(width, height). For text, an alias for font_size; for scatter, the bubble field.}
  \item{details}{A field identifying scatter points. Use a unique observation ID for one point per row.}
  \item{legend}{Optional unaggregated categorical series field; series is its named alias.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{tooltip}{Optional field references for the native tooltip role.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{series}{Optional grouping field used as a legend/series split.}
}
\details{
Supply details as a unique row identifier to obtain one point per observation. Without details, native aggregations can collapse many rows into one point or one point per series. A hidden identifier is still usable as a details field. For large datasets, prepare a meaningful summary or sample in R and explain the sampling rule. Bubble size must have a meaningful nonnegative magnitude. Preserve the original positional order x, y, size, details, legend. Use named arguments when migrating from 0.2.0, which reordered those meanings.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
sales <- pbi_demo_data() \%>\% pbi_prepare(function(d) d[, row_id := seq_len(.N)])
d <- pbi_dashboard("Scatter", sales) \%>\%
  pbi_page("Compare", pbi_scatter("units", "revenue", size = "cost", details = "row_id",
                                 legend = "region", title = "Monthly observations"))
pbi_validate(d)$valid
}
