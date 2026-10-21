\name{pbi_donut}
\alias{pbi_donut}
\title{Show a compact part-to-whole composition}
\description{Creates a native donut chart from a category and value.}
\usage{
pbi_donut(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{y}{The value field or list of value fields. Use pbi_aggregate() or pbi_ref() when the default summary is not appropriate.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{labels}{Whether native data labels are displayed.}
  \item{tooltip}{Optional field references for the native tooltip role.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{category}{The categorical grouping field.}
  \item{value}{The value field, aggregate reference, or measure reference to display.}
}
\details{
As with a pie, use only a few nonnegative additive groups. The hole is a visual style, not another data field or a separate KPI. Put an explicit pbi_card() alongside the chart for a total.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_donut("region", "revenue", title = "Regional composition")
d <- pbi_dashboard("Visual example", pbi_demo_data()) \%>\%
  pbi_page("Example", v)
pbi_validate(d)$valid
}
