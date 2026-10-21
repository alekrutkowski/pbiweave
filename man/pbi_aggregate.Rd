\name{pbi_aggregate}
\alias{pbi_aggregate}
\title{Choose the selection-time summary for a column}
\description{Builds a column reference with an explicit native aggregation.}
\usage{
pbi_aggregate(column, fun = c("sum", "average", "min", "max", "count", "distinct_count"),
                          table = NULL, label = NULL, format = NULL)
}
\arguments{
  \item{column}{An existing column name, supplied as a string. A calendar column must contain R Date values.}
  \item{fun}{Native summary: sum, average, min, max, count of nonblank values, or distinct_count. distinctcount is an alias.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{label}{Optional user-facing field or input label. It does not change the underlying column name.}
  \item{format}{A Power BI format string, such as "#,0", "$#,0.00", or "0.0\%". It is not an R sprintf() pattern.}
}
\details{
No rows are aggregated in R by this helper. It tells Power BI to sum, average, count, find a minimum or maximum, or count distinct values after applying the viewer's filters. count counts nonblank values; it is not a row count when the column has missing values. For record counts, prepare a column of ones in R and sum it. The average of a 0/1 indicator with NA for unknown outcomes is a valid observed-outcome proportion. Do not average preaggregated group means: use sufficient statistics and pbi_ratio().
}
\value{A pbi_field reference with an explicit aggregation.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Mean transaction", pbi_demo_data()) \%>\%
  pbi_page("Explore", pbi_bar("region",
    pbi_aggregate("revenue", "average", format = "$#,0.00")))
pbi_validate(d)$valid
}
