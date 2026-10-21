\name{pbi_matrix}
\alias{pbi_matrix}
\title{Cross-tabulate values by row and column groups}
\description{Creates a native matrix with row groups, optional column groups, and one or more values.}
\usage{
pbi_matrix(rows, values, columns = NULL, table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL)
}
\arguments{
  \item{rows}{Grid row span or matrix row-group fields.}
  \item{values}{The value fields for a matrix; for pbi_filter(), the allowed or excluded values of a single column.}
  \item{columns}{Grid column count, matrix column-group fields, or table fields, depending on the function.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
}
\details{
The matrix evaluates values under each row/column filter context. A ratio-of-sums measure correctly recomputes totals; a precomputed percentage averaged across unequal groups does not. Supply several fields as a list to combine measures and columns. Prepare bespoke statistics in R at a grain that preserves the intended filters.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_matrix("region", "revenue", columns = "product", title = "Revenue cross-tabulation")
d <- pbi_dashboard("Visual example", pbi_demo_data()) \%>\%
  pbi_page("Example", v)
pbi_validate(d)$valid
}
