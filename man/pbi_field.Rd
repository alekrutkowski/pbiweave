\name{pbi_field}
\alias{pbi_field}
\title{Refer to a model column without writing DAX}
\description{Constructs a column reference, optionally qualified by table and given an aggregation, display label, or visual-level format.}
\usage{
pbi_field(name = NULL, table = NULL, aggregate = NULL, label = NULL,
                      format = NULL, column = NULL)
}
\arguments{
  \item{name}{A unique model, measure, page, or example name, as described above.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{label}{Optional user-facing field or input label. It does not change the underlying column name.}
  \item{format}{A Power BI format string, such as "#,0", "$#,0.00", or "0.0\%". It is not an R sprintf() pattern.}
  \item{column}{An existing column name, supplied as a string. A calendar column must contain R Date values.}
}
\details{
A string field name normally resolves in the report's first table. Qualify fields from dimensions, or ambiguous names, with table. Value roles default to sums for numeric columns, while category, slicer, and detail-table roles stay unaggregated. Setting aggregate explicitly overrides that rule. This function does not extract an R vector: it describes a field that Power BI will query later. aggregate = "none" is an explicit unaggregated request for grouping, detail or tooltip roles, not a valid numeric chart-value aggregation. column is an alias for name; use one, not both.
}
\value{A pbi_field reference consumed by visual constructors.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
f <- pbi_field("revenue", table = "Sales", aggregate = "average",
               label = "Mean revenue", format = "$#,0.00")
v <- pbi_bar("region", f, table = "Sales")
print(v)
}
