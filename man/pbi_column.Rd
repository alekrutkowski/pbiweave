\name{pbi_column}
\alias{pbi_column}
\title{Describe a column for the semantic model}
\description{Sets presentation metadata, semantic types, visibility, and sort-by behavior for an existing column.}
\usage{
pbi_column(x, column, table = NULL, type = NULL, format = NULL,
                       hidden = NULL, description = NULL, sort_by = NULL,
                       summarize = NULL, data_category = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{column}{An existing column name, supplied as a string. A calendar column must contain R Date values.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{type}{Semantic type: string, int64, double, decimal, boolean, date or dateTime. A supplied type normalizes the copied values and revalidates relationships.}
  \item{format}{A Power BI format string, such as "#,0", "$#,0.00", or "0.0\%". It is not an R sprintf() pattern.}
  \item{hidden}{Column names to hide in pbi_data(); a scalar logical for column/page visibility elsewhere. Hiding is never security.}
  \item{description}{Optional explanatory metadata stored with the model object.}
  \item{sort_by}{Another column in the same table that provides a unique ordering for each displayed value.}
  \item{summarize}{The model-column default summarization. Use "none" for identifiers.}
  \item{data_category}{Optional Power BI category metadata, for example "Latitude" or "Longitude".}
}
\details{
This modifies column metadata and, when type is supplied, converts a private copy of the stored values using the same strict normalizers as pbi_data(). Invalid integers, currency scales and date strings fail before compilation. Existing relationships and sort mappings are revalidated after the change. Prepare more complex transformations with ordinary R or pbi_prepare(). A display value must map to exactly one sort key; circular sort mappings are rejected. NULL leaves an existing setting unchanged; format = "" explicitly clears a display format. Identifiers normally use summarize = "none". Hidden data remain recoverable from the project.
}
\value{The modified pbi_dashboard object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Typed model", pbi_demo_data()) \%>\%
  pbi_column("revenue", type = "decimal", format = "$#,0.00") \%>\%
  pbi_column("product", summarize = "none")
d$tables$data$columns$revenue$format
}
