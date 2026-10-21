\name{pbi_waterfall}
\alias{pbi_waterfall}
\title{Explain additive contributions to a total}
\description{Creates a native waterfall from categories and signed contributions.}
\usage{
pbi_waterfall(x = NULL, y = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum", labels = TRUE, tooltip = NULL,
                     id = NULL, category = NULL, value = NULL, breakdown = NULL)
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
  \item{breakdown}{Optional secondary grouping for a waterfall.}
}
\details{
Positive and negative contributions should be calculated in R from the analytical question. Passing already cumulative totals would count them again. breakdown adds a secondary categorical split. Native total/breakdown presentation still needs a Desktop review.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
changes <- data.frame(step = c("Opening", "Growth", "Churn"),
                      amount = c(100, 25, -10), order = 1:3)
d <- pbi_dashboard("Bridge") \%>\%
  pbi_data("Changes", changes, sort_by = c(step = "order")) \%>\%
  pbi_page("Bridge", pbi_waterfall("step", "amount") \%>\% pbi_sort("step"))
pbi_validate(d)$valid
}
