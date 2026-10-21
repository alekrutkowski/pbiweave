\name{pbi_sort}
\alias{pbi_sort}
\title{Set a visual query's sort order}
\description{Requests ascending or descending sorting by a model column or measure.}
\usage{
pbi_sort(x, field, descending = FALSE, direction = NULL, table = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{field}{A column name or pbi_field() reference. Slicers and categorical filters require an unaggregated column.}
  \item{descending}{Logical original sort flag; TRUE sorts descending. Do not use together with direction.}
  \item{direction}{For relationships: single (dimension to fact) or both. For visual sorting: ascending or descending.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
}
\details{
The field should be present in the visual. When a bare column name identifies exactly one projected aggregate, the compiler reuses that aggregation for sorting. Supply an explicit pbi_field(), pbi_aggregate(), or pbi_ref() to avoid ambiguity. Sorting a displayed month-name column is usually better handled by pbi_column(sort_by = "Month") than by alphabetic sorting. The third positional argument remains the logical descending flag. Use direction = "descending" for the newer string spelling; do not pass that string positionally. The selected sorting expression must already appear in the visual with the same aggregation.
}
\value{The modified pbi_visual object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_bar("product", "revenue") \%>\%
  pbi_sort("revenue", descending = TRUE)
d <- pbi_dashboard("Ranked products", pbi_demo_data()) \%>\%
  pbi_page("Rank", v)
pbi_validate(d)$valid
}
